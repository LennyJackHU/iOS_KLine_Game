// ESP32 Arduino BLE firmware for Coin Box + Dispenser
// GATT UUIDs must match iOS app BLEManager.UUIDs

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

// UUIDs
static BLEUUID SERVICE_UUID("8F1D0001-7E08-4E27-9D94-7A2C3B6E10A1");
static BLEUUID CHAR_COIN_UUID("8F1D0002-7E08-4E27-9D94-7A2C3B6E10A1");
static BLEUUID CHAR_CMD_UUID("8F1D0003-7E08-4E27-9D94-7A2C3B6E10A1");
static BLEUUID CHAR_STATUS_UUID("8F1D0004-7E08-4E27-9D94-7A2C3B6E10A1");

// Hardware config macros (easy to adjust)
#define PIN_COIN_ACCEPTOR 14  // pulse input from coin acceptor
#define PIN_DISPENSE       25  // motor/solenoid for single-denomination coin

#define COIN_PULSE_DEBOUNCE_US  3000  // debounce time for acceptor pulses
#define DISPENSE_PULSE_MS       150   // pulse width for one coin
#define DISPENSE_GAP_MS         120   // gap between coins

BLEServer* server = nullptr;
BLECharacteristic* coinChar = nullptr;   // notify running total
BLECharacteristic* cmdChar = nullptr;    // write commands
BLECharacteristic* statusChar = nullptr; // notify events

volatile uint16_t coinTotal = 0;     // total inserted coins in current session
volatile bool countingEnabled = false;
volatile uint32_t lastPulseUs = 0;

class CmdCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* characteristic) override {
    std::string v = characteristic->getValue();
    if (v.size() < 1) return;
    uint8_t cmd = v[0];
    if (cmd == 0x01) { // start coin session
      coinTotal = 0;
      countingEnabled = true;
      notifyCoin();
    } else if (cmd == 0x02) { // payout
      if (v.size() < 3) return;
      uint16_t amt = (uint16_t)((uint8_t)v[1] | ((uint16_t)(uint8_t)v[2] << 8));
      handlePayout(amt);
    }
  }
};

void IRAM_ATTR onCoinPulse() {
  if (!countingEnabled) return;
  uint32_t nowUs = micros();
  if (nowUs - lastPulseUs < COIN_PULSE_DEBOUNCE_US) return; // debounce
  lastPulseUs = nowUs;
  coinTotal++;
  notifyCoin();
}

void notifyCoin() {
  if (!coinChar) return;
  uint16_t le = coinTotal;
  uint8_t buf[2];
  buf[0] = (uint8_t)(le & 0xFF);
  buf[1] = (uint8_t)((le >> 8) & 0xFF);
  coinChar->setValue(buf, 2);
  coinChar->notify();
}

void notifyPayoutDone(uint16_t dispensed) {
  if (!statusChar) return;
  uint8_t payload[3] = {0x10, (uint8_t)(dispensed & 0xFF), (uint8_t)((dispensed >> 8) & 0xFF)};
  statusChar->setValue(payload, 3);
  statusChar->notify();
}

void pulseDispenseOne() {
  digitalWrite(PIN_DISPENSE, HIGH);
  delay(DISPENSE_PULSE_MS);
  digitalWrite(PIN_DISPENSE, LOW);
}

void handlePayout(uint16_t count) {
  for (uint16_t i = 0; i < count; ++i) {
    pulseDispenseOne();
    delay(DISPENSE_GAP_MS);
  }
  notifyPayoutDone(count);
}

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {}
  void onDisconnect(BLEServer* pServer) override {
    pServer->getAdvertising()->start();
  }
};

void setup() {
  pinMode(PIN_COIN_ACCEPTOR, INPUT_PULLUP);
  pinMode(PIN_DISPENSE, OUTPUT);
  digitalWrite(PIN_DISPENSE, LOW);

  attachInterrupt(digitalPinToInterrupt(PIN_COIN_ACCEPTOR), onCoinPulse, FALLING);

  BLEDevice::init("KLine CoinBox");
  server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService* service = server->createService(SERVICE_UUID);

  coinChar = service->createCharacteristic(
      CHAR_COIN_UUID,
      BLECharacteristic::PROPERTY_NOTIFY
  );
  coinChar->addDescriptor(new BLE2902());

  cmdChar = service->createCharacteristic(
      CHAR_CMD_UUID,
      BLECharacteristic::PROPERTY_WRITE
  );
  cmdChar->setCallbacks(new CmdCallbacks());

  statusChar = service->createCharacteristic(
      CHAR_STATUS_UUID,
      BLECharacteristic::PROPERTY_NOTIFY
  );
  statusChar->addDescriptor(new BLE2902());

  service->start();

  BLEAdvertising* advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->setMinPreferred(0x06);
  advertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
}

void loop() {
  // nothing, ISR and callbacks drive behavior
}


