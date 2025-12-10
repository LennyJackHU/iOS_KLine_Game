#ifndef __PRINTER_TYPE_H__
#define __PRINTER_TYPE_H__
#include <stdio.h>

/*
 * 定义下划线模式
 */
typedef enum underline
{
    NO_UNDERLINE,    // 无下划线
    ONE_POINT_WIDTH, // 一点宽
    TWO_POINT_WIDTH  // 两点宽
} underline_type_t;

typedef enum hri_pos
{
    NO_PRINT,       // 不打印
    ABOVE,          // 条码上方
    BELOW,          // 条码下方
    ABOVE_AND_BELOW // 条码上下方
} hri_pos_t;

/*
 * 定义对齐方式
 */
typedef enum align_type
{
    ALIGN_LEFT,   // 左对齐
    ALIGN_CENTER, // 居中对齐
    ALIGN_RIGHT   // 右对齐
} align_type_t;

/*
 * 自定义指令中
 * 执行结果返回值类型枚举
 */
typedef enum result_type
{
    NOTYPE, // 没有类型
    STRING, // 字符串
    NUMBER  // 数字
} result_type_t;

/*
 * 字体类型枚举
 */
typedef enum font_style
{
    SIM_SUN = 1, // 宋体
    SIM_HEI      // 黑体
} font_style_t;

/*
 * 字符集编码类型枚举
 */
typedef enum encoding_type
{
    ENCODING_CP936,  // 中文简体
    ENCODING_CP437,  // 美国，欧洲标准
} encoding_type_t;  // 字符编码集

/*
 * 自定义指令枚举
 */
typedef enum custom_command
{
    /* 出厂设置 */
    Factory_Reset, // 恢复出厂设置
    Self_Check,    // 自检信息
    Machine_Name,  // 机器名称
    Machine_Type,  // 机器类型
    Restart,       // 重启
    /* 打印头相关指令 */
    Print_Darkness,       // 打印浓度（取值范围0~39）
    Print_Maximum_Speed,  // 最高打印速度（取值范围0~12）
    Print_Current_Level,  // 电流等级（取值范围5~9）
    Print_Operation_Mode, // 运行模式（取值参考OperationMode枚举）
    Print_Temperature,    // 打印温度
    Print_Voltage,        // 打印电压
    Print_Usage_Record,   // 打印使用记录

    /* 通用指令相关设置 */
    Error_Clear_Buffer, // 错误时清缓存功能开关（取值范围 ENABLE / DISABLE）
    Open_Cash_Box,      // 开启钱箱

    /* 蜂鸣器相关设置 */
    Buzzer,             // 蜂鸣器开关（取值范围 ENABLE / DISABLE）
    Buzzer_Command_Set, // 指令设置蜂鸣器开关（取值范围 ENABLE / DISABLE）
    Buzzer_Paper_Out,   // 缺纸警告蜂鸣器开关（取值范围 ENABLE / DISABLE）
    Buzzer_Duty_Cycle,  // 蜂鸣器占空比（取值范围10~90）
    Buzzer_Frequency,   // 蜂鸣器频率（取值范围600~5000）

    /* 指示灯相关指令 */
    Light_Error,            // 错误指示灯开关（取值范围 ENABLE / DISABLE）
    Light_Overheat,         // 打印机芯过热指示灯开关（取值范围 ENABLE / DISABLE）
    Light_Paper_Out,        // 缺纸指示灯开关（取值范围 ENABLE / DISABLE）
    Light_Power,            // 电源指示灯开关（取值范围 ENABLE / DISABLE）
    Light_Power_Connect,    // 电源指示灯已连接开关（取值范围 ENABLE / DISABLE）
    Light_Power_Disconnect, // 电源指示灯已断开开关（取值范围 ENABLE / DISABLE）

    /* 纸张节约相关指令 */
    Paper_Saving,                   // 纸张节约开关（取值范围 ENABLE / DISABLE）
    Line_Spacing_Reduction_Ratio,   // 行间距削减比例（取值参考ReductionRatio枚举）
    Barcode_Height_Reduction_Ratio, // 条码高度削减比例（取值参考ReductionRatio枚举）
    Line_Break_Saving_Ratio,        // 换行节省比例（取值参考ReductionRatio枚举）

    /* 语言相关指令 */
    Encoding_Type,          // 语言（取值参考EncodingType枚举）
    Chinese_Character_Mode, // 汉字模式（取值范围 ENABLE / DISABLE）
    Font_Style,             // 字体样式（取值参考FontStyle枚举）

    /* 语音相关指令 */
    Voice_Prompt,               // 语音提示（取值范围 ENABLE / DISABLE）
    Voice_Prompt_Volume,        // 语音播报音量（取值范围0~15）
    Demonstration_Sound_Effect, // 演示音效（取值参考SoundEffect枚举）

    /* 按键设置 */
    Key_Paper_Feed,             // 按键走纸开关（取值范围 ENABLE / DISABLE）
    Key_Paper_Feed_Distance,    // 按键走纸距离（取值范围10~10000）
    Cutter_Paper_Feed_Distance, // 切刀后走纸距（取值范围0~300）

    Get_hardware_version, // 获取硬件版本号

} custom_command_t;

/*
 * 自定义指令中的批量设置结构体
 */
typedef struct setting_batch
{
    custom_command_t command;
    union
    {
        char string[128]; // 设置的字符串
        int value;        // 设置的值
    } data;
} setting_batch_t;

/*
 * 运行模式枚举
 */
typedef enum operation_mode
{
    CONSTANT_SPEED_MODE = 1, // 匀速模式
    LOW_CURRENT_MODE,        // 小电流模式
    VOLTAGE_ADAPTIVE_MODE,   // 电压自适应模式
    MODULE_WIDE_VOLTAGE_MODE // 模组宽电压模式
} operation_mode_t;

/*
 * 自定义指令执行返回结构体
 */
typedef struct execute_ret
{
    int result;         // 指令执行结果,0成功，其他失败
    result_type_t type; // 执行返回值的类型
    union
    {
        char string[128]; // 返回的字符串
        int value;        // 返回的值
    } data;
} execute_ret_t;

#endif
