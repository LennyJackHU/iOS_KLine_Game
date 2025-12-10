#pragma once

// ==== 引脚定义（按硬件修改） ====
// 投币器脉冲输入（累计投币总数，会话内清零）
#define PIN_COIN_ACCEPTOR           14    // 中断输入（FALLING，开集电极输出，投币时拉低）
// 吐币继电器
#define PIN_DISPENSE_RELAY          25    // 继电器/电机驱动输出（HIGH=启，LOW=停）

// ==== 去抖与时序（可按机械特性调整） ====
#define COIN_ACCEPTOR_DEBOUNCE_US   20000  // 投币器脉冲去抖（us）- 100ms脉冲用20ms去抖

#define DISPENSE_GAP_MS             120   // 每两枚之间停顿（ms）
#define PER_COIN_TIMEOUT_MS         1500  // 单枚超时（ms）

// ==== BLE 广播名 ====
#define BLE_DEVICE_NAME             "KLine CoinBox"

// ==== GATT UUID（与 iOS 固定一致） ====
#define UUID_SERVICE                "8F1D0001-7E08-4E27-9D94-7A2C3B6E10A1"
#define UUID_CHAR_COIN              "8F1D0002-7E08-4E27-9D94-7A2C3B6E10A1" // Notify: u16 LE 总币数
#define UUID_CHAR_CMD               "8F1D0003-7E08-4E27-9D94-7A2C3B6E10A1" // Write: 指令
#define UUID_CHAR_STATUS            "8F1D0004-7E08-4E27-9D94-7A2C3B6E10A1" // Notify: 事件

// ==== 协议常量 ====
#define CMD_START_SESSION           0x01  // 开启投币会话
#define CMD_PAYOUT                  0x02  // 吐币（u16 个数）
#define CMD_PRINT_RECEIPT           0x03  // 打印小票（后续携带数据）
#define CMD_DEBUG_PRINTER           0x04  // 调试打印机（测试不同方式）

#define EVT_PAYOUT_DONE             0x10  // 吐币完成（u16 已吐币数）

// ==== 打印机/BLE 扩展指令 ====
#define CMD_PRINT_RECEIPT           0x03  // 打印小票（后续携带数据）

// 打印机串口配置（如有需要可根据硬件调整）
#define PRINTER_UART_BAUD           115200
#define PRINTER_UART_TX_PIN         17    // ESP32 TX2 默认 17
#define PRINTER_UART_RX_PIN         16    // ESP32 RX2 默认 16

// ==== 吐币速度（时间换算吐币，不依赖出币传感器） ====
// 实测：每秒约 7.1 枚
#define DISPENSE_COINS_PER_SEC      6.5f