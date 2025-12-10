# KLineCoinBox (ESP32-DevKitC, PlatformIO + Arduino)

- 单面额游戏币：投币计数 + 吐币确认
- BLE GATT（与 iOS 一致）：
  - Service: 8F1D0001-7E08-4E27-9D94-7A2C3B6E10A1
  - coinCountNotify (Notify, u16 LE 总投币数): 8F1D0002-...
  - commandWrite (Write, 指令): 8F1D0003-...
  - statusNotify (Notify, 事件): 8F1D0004-...

协议
- App→ESP32
  - 0x01: 开启投币会话（清零计数）
  - 0x02 + count(u16 LE): 吐币“个数”
  - 0x03 + payload(UTF-8 文本): 打印小票文本（仅文本，不含图形）
- ESP32→App
  - coinCountNotify: u16 LE 当前会话投币“总枚数”
  - statusNotify: [0x10, dispensed(u16 LE)] 吐币完成事件（以出币传感器计数为准）

硬件
- 继电器控制吐币：按枚启动/停止
- 出币传感器计数（光电/微动），去抖；每个有效脉冲记 1 枚
- 关键参数在 include/config.h 顶部宏统一配置

打印机
- 硬件串口：UART2，波特率 115200，TX=GPIO17，RX=GPIO16（可在 `include/config.h` 调整）
- SDK：`lib/printer/libprinter.a` + 头文件 `include/printer_*.h`
- 初始化：系统启动时初始化串口与SDK，收到 0x03 指令后打印

小票格式（建议由 iPad 组织文本并发送）：
```
交易小票
开盘价: xxx
收盘价: xxx
杠杆率: xxx
本金: xxx
收益率: xxx
吐币数量: xxx
```
说明：
- iPad 端直接拼接 UTF-8 文本，以换行分隔；MCU 侧原样打印并在末尾走纸 3 行。