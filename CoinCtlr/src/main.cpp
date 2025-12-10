#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include "config.h"
#include "printer_lib.h"
#include "printer_type.h"

// 打印机库需要的宏定义
#define ENABLE  1
#define DISABLE 0

// === UUID 定义 ===
static BLEUUID SERVICE_UUID(UUID_SERVICE);
static BLEUUID CHAR_COIN_UUID(UUID_CHAR_COIN);
static BLEUUID CHAR_CMD_UUID(UUID_CHAR_CMD);
static BLEUUID CHAR_STATUS_UUID(UUID_CHAR_STATUS);

// === BLE 对象 ===
BLEServer* server                   = nullptr;
BLECharacteristic* coinChar         = nullptr;  // Notify 总投币数
BLECharacteristic* cmdChar          = nullptr;  // Write 指令
BLECharacteristic* statusChar       = nullptr;  // Notify 事件

// === 打印机 ===
static printer_t* printer           = nullptr;
static uint8_t print_buffer[2048];

// === 调试/状态 ===
static volatile bool bleConnected   = false;
static uint32_t lastDebugMs         = 0;

// UART 发送/延时桥接
int printer_uart_send(const uint8_t *data, uint16_t size, uint32_t timeout) {
  (void)timeout;
  Serial.print("[UART] Sending "); Serial.print(size); Serial.println(" bytes to printer");
  
  // 打印十六进制数据用于调试
  Serial.print("[UART] HEX: ");
  for (int i = 0; i < size && i < 32; i++) { // 只打印前32字节
    if (data[i] < 0x10) Serial.print("0");
    Serial.print(data[i], HEX);
    Serial.print(" ");
  }
  if (size > 32) Serial.print("...");
  Serial.println();
  
  int written = Serial2.write(data, size);
  Serial2.flush(); // 确保数据发送完毕
  Serial.print("[UART] Sent "); Serial.print(written); Serial.println(" bytes");
  
  // 返回与 printerTest 一致的值：0=成功，非0=失败
  return (written == size) ? 0 : 1;
}
static void printer_delay_ms(uint32_t ms) {
  delay(ms);
}

// === 投币会话累计（来自投币器脉冲） ===
volatile uint16_t coinTotal         = 0;
volatile uint32_t lastAcceptorUs    = 0;


// 继电器控制
static inline void relayOn()  { digitalWrite(PIN_DISPENSE_RELAY, HIGH); }
static inline void relayOff() { digitalWrite(PIN_DISPENSE_RELAY, LOW);  }
static void notifyCoinTotal();
static void handlePayout(uint16_t count);
// 传感器读取
// 取消传感器逻辑

// ==== BLE 回调 ====
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    bleConnected = true;
    Serial.println("[BLE] Connected");
  }
  void onDisconnect(BLEServer* pServer) override {
    bleConnected = false;
    pServer->getAdvertising()->start();
    Serial.println("[BLE] Disconnected -> Advertising restarted");
  }
};

class CmdCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* ch) override {
    std::string v = ch->getValue();
    if (v.size() < 1) return;
    const uint8_t cmd = v[0];
    Serial.print("[BLE] CMD recv: 0x"); Serial.println(cmd, HEX);

    if (cmd == CMD_START_SESSION) {
      coinTotal = 0;
      lastAcceptorUs = 0;
      notifyCoinTotal();
      Serial.println("[CMD] START_SESSION -> counters reset");
    } else if (cmd == CMD_PAYOUT) {
      if (v.size() < 3) return;
      const uint16_t target = (uint16_t)((uint8_t)v[1] | ((uint16_t)(uint8_t)v[2] << 8));
      Serial.print("[CMD] PAYOUT -> target: "); Serial.println(target);
      handlePayout(target);
    } else if (cmd == CMD_PRINT_RECEIPT) {
      // 解析 iPad 发来的打印数据，仅打印文本
      Serial.print("[CMD] PRINT_RECEIPT received, payload size="); Serial.println(v.size());
      
      if (v.size() <= 1) {
        Serial.println("[CMD] PRINT_RECEIPT: No payload data");
        return;
      }
      
      const uint8_t* text = reinterpret_cast<const uint8_t*>(&v[1]);
      const size_t len = v.size() - 1;
      // 保证以\0 结尾
      static char line[512];
      size_t copyLen = len < sizeof(line) - 1 ? len : sizeof(line) - 1;
      memcpy(line, text, copyLen);
      line[copyLen] = '\0';
      Serial.print("[CMD] PRINT_RECEIPT len="); Serial.println((int)copyLen);
      Serial.print("[CMD] PRINT_RECEIPT text: "); Serial.println(line);

      // 先直接通过串口发送测试
      Serial.println("[PRN] Sending direct to UART...");
      Serial2.print("=== 交易小票 ===\n");
      Serial2.print(line);
      Serial2.print("\n\n\n");
      Serial2.flush();
      Serial.println("[PRN] Direct UART print completed");
      
      // 使用正确的链式调用方法
      if (printer != nullptr && printer->text() != nullptr) {
        Serial.println("[PRN] Starting library print job...");
        
        // 分别调用每个部分，确保每次都调用print()
        int result1 = printer->text()
          ->align(ALIGN_CENTER)
          ->bold(ENABLE)
          ->utf8_text((uint8_t*)"交易小票")
          ->newline()
          ->print();
        Serial.print("[PRN] Header result: "); Serial.println(result1);
        
        int result2 = printer->text()
          ->bold(DISABLE)
          ->align(ALIGN_LEFT)
          ->utf8_text((uint8_t*)line)
          ->newline()
          ->print();
        Serial.print("[PRN] Content result: "); Serial.println(result2);
        
        int result3 = printer->text()
          ->feed_lines(3)
          ->print();
        Serial.print("[PRN] Footer result: "); Serial.println(result3);
        
      } else {
        Serial.println("[PRN] WARNING: Printer library not available, used direct UART only");
      }
      
      Serial.println("[PRN] receipt printed");
    } else if (cmd == CMD_DEBUG_PRINTER) {
      Serial.println("[DEBUG] Printer debug command received");
      
      // 测试1: 原始文本
      Serial.println("[DEBUG] Test 1: Raw text");
      Serial2.print("RAW TEXT TEST\r\n");
      Serial2.flush();
      delay(500);
      
      // 测试2: 不同波特率测试（重新初始化串口）
      Serial.println("[DEBUG] Test 2: Different baud rates");
      int baud_rates[] = {9600, 19200, 38400, 57600, 115200};
      for (int i = 0; i < 5; i++) {
        Serial.print("[DEBUG] Testing baud rate: "); Serial.println(baud_rates[i]);
        Serial2.end();
        Serial2.begin(baud_rates[i], SERIAL_8N1, PRINTER_UART_RX_PIN, PRINTER_UART_TX_PIN);
        delay(100);
        Serial2.print("BAUD TEST ");
        Serial2.print(baud_rates[i]);
        Serial2.print("\r\n");
        Serial2.flush();
        delay(1000);
      }
      
      // 恢复默认波特率
      Serial2.end();
      Serial2.begin(PRINTER_UART_BAUD, SERIAL_8N1, PRINTER_UART_RX_PIN, PRINTER_UART_TX_PIN);
      delay(100);
      
      // 测试3: ESC/POS命令
      Serial.println("[DEBUG] Test 3: ESC/POS commands");
      uint8_t esc_pos_test[] = {
        0x1B, 0x40,        // ESC @ (初始化打印机)
        'T', 'E', 'S', 'T', '\n',
        0x1B, 0x45, 0x01,  // ESC E (加粗开)
        'B', 'O', 'L', 'D', '\n',
        0x1B, 0x45, 0x00,  // ESC E (加粗关)
        0x1B, 0x64, 0x03   // ESC d (走纸3行)
      };
      Serial2.write(esc_pos_test, sizeof(esc_pos_test));
      Serial2.flush();
      
      Serial.println("[DEBUG] All printer tests completed");
    }
  }
};

// ==== 中断（投币器） ====
void IRAM_ATTR isrAcceptor() {
  const uint32_t now = micros();
  if (now - lastAcceptorUs < COIN_ACCEPTOR_DEBOUNCE_US) return;
  lastAcceptorUs = now;
  coinTotal++;
  // 立即上报总币数
  if (coinChar) {
    uint8_t buf[2] = { (uint8_t)(coinTotal & 0xFF), (uint8_t)((coinTotal >> 8) & 0xFF) };
    coinChar->setValue(buf, 2);
    coinChar->notify();
  }
}

// 无传感器中断

// ==== 辅助通知 ====
static void notifyCoinTotal() {
  if (!coinChar) return;
  uint8_t buf[2] = { (uint8_t)(coinTotal & 0xFF), (uint8_t)((coinTotal >> 8) & 0xFF) };
  coinChar->setValue(buf, 2);
  coinChar->notify();
}

static void notifyPayoutDone(uint16_t dispensed) {
  if (!statusChar) return;
  uint8_t payload[3] = {
    EVT_PAYOUT_DONE,
    (uint8_t)(dispensed & 0xFF),
    (uint8_t)((dispensed >> 8) & 0xFF)
  };
  statusChar->setValue(payload, 3);
  statusChar->notify();
}

// ==== 吐币核心逻辑（继电器启停 + 传感器确认） ====
// 基本策略：一枚一控
// - 记录基线dispensedBaseline
// - 启动继电器，等待 coinDispensed == baseline+1（有超时保护）
// - 成功则停止继电器，间隔后继续；超时则停止继电器并中止
static void handlePayout(uint16_t targetCount) {
  // 改为按时间控制吐币（不使用出币传感器）
  // 速率：DISPENSE_COINS_PER_SEC 枚/秒
  if (targetCount == 0) {
    notifyPayoutDone(0);
    return;
  }

  const float secondsNeeded = ((float)targetCount) / DISPENSE_COINS_PER_SEC;
  const uint32_t durationMs = (uint32_t)(secondsNeeded * 1000.0f);

  Serial.print("[PAYOUT] time-based start, target="); Serial.print(targetCount);
  Serial.print(", durationMs="); Serial.println(durationMs);

  // 启动继电器，持续给定时长
  relayOn();
  const uint32_t startMs = millis();
  while ((millis() - startMs) < durationMs) {
    delay(1);
  }
  relayOff();

  // 直接按目标值上报
  notifyPayoutDone(targetCount);
  Serial.println("[PAYOUT] time-based done");
}

// ==== 初始化与主循环 ====
void setup() {
  Serial.begin(115200);
  delay(50);

  // 硬件引脚
  pinMode(PIN_COIN_ACCEPTOR, INPUT);  // 投币机输出0V-5V，不需要上拉
  pinMode(PIN_DISPENSE_RELAY, OUTPUT);
  relayOff();

  // 中断
  attachInterrupt(digitalPinToInterrupt(PIN_COIN_ACCEPTOR), isrAcceptor, RISING);  // 0V→5V上升沿
  // 无出币传感器中断

  // BLE
  BLEDevice::init(BLE_DEVICE_NAME);
  server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService* service = server->createService(SERVICE_UUID);

  // 总投币数 Notify
  coinChar = service->createCharacteristic(CHAR_COIN_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  coinChar->addDescriptor(new BLE2902());

  // 指令 Write
  cmdChar = service->createCharacteristic(CHAR_CMD_UUID, BLECharacteristic::PROPERTY_WRITE);
  cmdChar->setCallbacks(new CmdCallbacks());

  // 事件 Notify
  statusChar = service->createCharacteristic(CHAR_STATUS_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  statusChar->addDescriptor(new BLE2902());

  service->start();

  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);
  adv->setMinPreferred(0x06);
  adv->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("[BLE] Advertising started");

  // 打印机初始化（UART2）
  Serial.println("[PRN] Initializing printer on UART2...");
  Serial2.begin(PRINTER_UART_BAUD, SERIAL_8N1, PRINTER_UART_RX_PIN, PRINTER_UART_TX_PIN);
  delay(100); // 给串口时间初始化
  
  // 发送最基础的打印机测试命令
  Serial.println("[PRN] Sending basic ESC/POS reset command...");
  uint8_t reset_cmd[] = {0x1B, 0x40}; // ESC @ (复位打印机)
  Serial2.write(reset_cmd, sizeof(reset_cmd));
  Serial2.flush();
  delay(500);
  
  // 发送简单文本测试
  Serial.println("[PRN] Sending text test...");
  Serial2.print("PRINTER TEST\n");
  uint8_t feed_cmd[] = {0x1B, 0x64, 0x03}; // ESC d 3 (走纸3行)
  Serial2.write(feed_cmd, sizeof(feed_cmd));
  Serial2.flush();
  delay(1000);
  
  Serial.println("[PRN] Creating printer instance...");
  printer = new_printer();
  if (printer == nullptr) {
    Serial.println("[PRN] ERROR: Failed to create printer instance!");
    return;
  }
  
  Serial.println("[PRN] Initializing printer buffer...");
  if (printer->buffer() == nullptr) {
    Serial.println("[PRN] ERROR: Failed to get buffer interface!");
    return;
  }
  printer->buffer()->buffer_init(sizeof(print_buffer), print_buffer);
  
  Serial.println("[PRN] Setting up printer device callbacks...");
  if (printer->device() == nullptr) {
    Serial.println("[PRN] ERROR: Failed to get device interface!");
    return;
  }
  
  printer->device()
    ->delay_init(printer_delay_ms)
    ->send_init(printer_uart_send);

  Serial.println("[PRN] Testing printer with welcome message...");
  
  // 先发送简单的测试数据
  Serial.println("[PRN] Sending basic test to UART...");
  Serial2.print("HELLO PRINTER\r\n");
  Serial2.flush();
  delay(500);
  
  // 然后尝试使用库函数，按照printerTest的正确方法
  if (printer->text() != nullptr) {
    Serial.println("[PRN] Testing library print...");
    
    int result = printer->text()
      ->utf8_text((uint8_t*)"[Printer] Ready")
      ->newline()
      ->print();
    
    Serial.print("[PRN] Library print result: "); Serial.println(result);
    
    if (result == 0) {
      Serial.println("[PRN] Library initialization SUCCESS!");
    } else {
      Serial.println("[PRN] Library initialization FAILED!");
    }
  } else {
    Serial.println("[PRN] ERROR: Failed to get text interface!");
  }
  
  Serial.println("[PRN] initialized on UART2 115200");
}

void loop() {
  // 主要由中断与BLE回调驱动
  // 周期性诊断输出
  const uint32_t nowMs = millis();
  if (nowMs - lastDebugMs >= 1000) {
    lastDebugMs = nowMs;
    int pinCoinIn = digitalRead(PIN_COIN_ACCEPTOR);
    int pinOutSensor = -1;
    Serial.print("[DBG] t="); Serial.print(nowMs);
    Serial.print("ms, BLE="); Serial.print(bleConnected ? "ON" : "OFF");
    Serial.print(", coinTotal="); Serial.print(coinTotal);
    Serial.print(", dispensed(time-based)");
    Serial.print(", IN14="); Serial.print(pinCoinIn);
    Serial.print(", OUT27="); Serial.println(pinOutSensor);
  }
  delay(20);
}