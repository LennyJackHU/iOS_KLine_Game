#ifndef __PRINTER_LIB_H__
#define __PRINTER_LIB_H__
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "printer_type.h"
#ifdef PRINTER_BUILD_SHARED
#define PRINTER_API __declspec(dllexport)
#else
#define PRINTER_API
#endif
#ifdef __cplusplus
extern "C"
{
#endif

/**
 * @brief 毫秒延时宏（全工程可用）
 * @param ms 延时时长(毫秒)
 */
#define DELAY_MS(ms) Printer_DelayMS(ms)

#define Printf printf // 定义打印函数

    // 内部声明
    void Printer_DelayMS(uint32_t ms);
    int Printer_Send(const uint8_t *data, uint16_t size, uint32_t Timeout);

    typedef struct device
    {
        /**
         * 功能:注册串口数据发送函数
         */
        struct device *(*send_init)(int (*send_func)(const uint8_t *, uint16_t, uint32_t));

        /**
         * 功能:注册延时函数
         */
        struct device *(*delay_init)(void (*delay_ms)(uint32_t));

        /**
         * 功能:获取缓存区数据函数
         */
        int (*data_write)(uint8_t *data, uint8_t length);

    } device_t;

    typedef struct buffer
    {
        /*
         * 功能:清空发送缓冲区
         */
        void (*clean_send)(void);

        /**
         * 功能:初始化缓冲区
         * @param size  缓冲区大小
         * @param buffer 缓冲区指针
         * 注意:请确保缓冲区有足够的大小
         */
        void (*buffer_init)(uint16_t size, uint8_t *buffer);

    } buffer_t;

    typedef struct text
    {
        /**
         * 功能:设置字符的行间距
         * @param space   行间距的大小，表示每行之间的间距，单位为字符或点数，取值范围（0-255）
         */
        struct text *(*line_space)(uint8_t space);

        /**
         * 功能:设置字符的右间距
         * @param space   右间距的大小，以字符为单位，取值范围为（0-255）
         */
        struct text *(*right_space)(uint8_t space);

        /**
         * 功能:移动打印位置到下一个水平定位点的位置
         */
        struct text *(*next_ht)(void);

        /**
         * 功能:将当前位置设置到距离行首 [pos × 横向或纵向移动单位] 处
         * @param pos  距离行首的绝对位置，取值范围（0-384）
         */
        struct text *(*abs_pos)(uint16_t pos);

        /**
         * 功能:将打印位置设置到距当前位置 [pos × 横向或纵向移动单位] 处
         * @param pos  距离当前位置的相对位置，取值范围（0-384）
         */
        struct text *(*rel_pos)(uint16_t pos);

        /**
         * 功能:根据传入的字节数组 'pos' 设置打印机的水平定位位置。最多支持 32 个字节的位置参数
         * @param pos   位置数组，最大长度为 32 字节。该数组中的每个字节表示一个具体的定位位置
         * @param size  pos数组的长度，最大32字节
         */
        struct text *(*ht_pos)(uint8_t *pos, uint8_t size);

        /**
         * 功能:设置文本对齐方式
         * @param type  对齐方式，取值参考'align_type_t'枚举，可选 左对齐，居中对齐，右对齐
         */
        struct text *(*align)(align_type_t type);

        /**
         * 功能:设置左边距
         * @param left_margin  左边距的大小，取值范围为（0-384），单位为 0.125 毫米
         */
        struct text *(*left_margin)(uint16_t left_margin);

        /**
         * 功能:设置横向和纵向移动单位，分别将横向移动单位近似设置成 25.4/ x mm（ 1/ x 英寸）纵向移动单位设置成 25.4/ y mm（1/ y 英寸）
         * @param x_uint  横向移动单位，表示每次横向移动的单位，取值范围（0-255）
         * @param y_uint  纵向移动单位，表示每次纵向移动的单位，取值范围（0-255）
         */
        struct text *(*move_unit)(uint8_t x_uint, uint8_t y_uint);

        /**
         * 功能:设置字符倍宽打印，使打印的字符在水平方向上变为原来的两倍宽度
         * @param double_width  是否启用倍宽打印  ENABLE:开启倍宽打印, DISABLE:关闭倍宽打印
         */
        struct text *(*double_width)(uint8_t mode);

        /**
         * 功能:设置打印文本的下划线模式
         * @param underline  下划线模式，取值参考'underline_type_t'枚举，可选 无下划线，一点宽，两点宽
         */
        struct text *(*underline)(underline_type_t underline);

        /**
         * 功能:启用或禁用加粗模式
         * @param bold  是否启用加粗            ENABLE:启用, DISABLE:禁用
         */
        struct text *(*bold)(uint8_t mode);

        /**
         * 功能:选择/取消顺时针旋转 90°
         * @param rotate_90  是否启用旋转       ENABLE:启用, DISABLE:禁用
         */
        struct text *(*rotate_90)(uint8_t mode);

        /**
         * 功能:选择/取消180 度旋转打印
         * @param rotate_180  是否启用旋转      ENABLE:启用, DISABLE:禁用
         */
        struct text *(*rotate_180)(uint8_t mode);

        /**
         * 功能:设置黑白反显模式。反显模式下，打印机将反转打印的颜色（黑变白，白变黑）
         * @param inversion_mode 是否启用反显   ENABLE:启用, DISABLE:禁用
         */
        struct text *(*inversion)(uint8_t inversion_mode);

        /**
         * 功能:设置字符的大小，控制字符的宽度和高度
         * @param muti_width  字符宽度的倍数，取值范围为（1-8）
         * @param muti_height 字符高度的倍数，取值范围为（1-2）
         */
        struct text *(*font_size)(uint8_t muti_width, uint8_t muti_height);

        /**
         * 功能:设置打印机的打印模式
         * @param double_width     文本宽度模式   ENABLE:启用倍宽                  DIAABLE:禁用倍宽
         * @param double_height    文本高度模式   ENABLE:启用倍高                  DISABLE:禁用倍高
         * @param blod             加粗模式       ENABLE:启用加粗                  DISABLE:禁用加粗
         * @param font_type        字体类型       ENABLE:启用扩展字体（9*17）      DISABLE:禁用扩展字体(12 × 24)
         * @param underline        下划线         ENABLE:启用下划线                DISABLE:禁用下划线
         */
        struct text *(*print_mode)(uint8_t double_width, uint8_t double_height, uint8_t blod, uint8_t font_type, uint8_t underline);

        /**
         * 功能:设置打印机的汉字模式
         * @param double_width     文本宽度模式   ENABLE:启用倍宽                  DISABLE:禁用倍宽
         * @param double_height    文本高度模式   ENABLE:启用倍高                  DISABLE:禁用倍高
         * @param underline        下划线         ENABLE:启用下划线                DISABLE:禁用下划线
         */
        struct text *(*chinese_mode)(uint8_t double_width, uint8_t double_height, uint8_t underline);

        /**
         * 功能:设置字符编码页
         * @param type    字符编码，取值参考'encoding_type_t'枚举，可选43种编码
         */
        struct text *(*encoding)(encoding_type_t type);

        /**
         * 功能:设置打印（utf8 编码）文本
         * @param text_utf8   要打印的文本内容
         */
        struct text *(*utf8_text)(uint8_t *text_utf8);

        /**
         * 功能:添加自定义数据或指令
         * @param raw_data   自定义数据
         */
        struct text *(*add_raw)(uint8_t *raw_data);

        /**
         * 功能:按照当前行间距，把打印纸向前推进一行，放入缓冲区
         */
        struct text *(*newline)(void);

        /**
         * 功能:走纸指定的点行数，放入缓冲区
         * @param dots  走纸的点数,取值范围（0-255）
         */
        struct text *(*feed_dots)(uint8_t dots);

        /**
         * 功能:向前走纸 n 行（字符行），放入缓冲区
         * @param lines  走纸的行数,取值范围（0-255）
         */
        struct text *(*feed_lines)(uint8_t lines);

        /**
         * 功能:打印缓冲区里的数据
         * @param
         */
        int (*print)(void);

    } text_t;


    typedef struct setting
    {
        /**
         * 功能:自定义指令中的赋值操作，赋值的类型为字符串
         * @param command       自定义指令，取值参考'custom_command_t'枚举
         * @param string        需要设置的字符串
         * @param execute_ret   执行返回参数
         *          result                     指令执行结果
         *          type                       执行返回值的类型
         *          data.string                读取的字符串
         * @param timeout_ms    超时时间（单位毫秒）
         * @return 0:成功；其他值:失败
         */
        int (*assign_string)(custom_command_t command, char *string, execute_ret_t *execute_ret, int timeout_ms);

        /**
         * 功能:自定义指令中的赋值操作，赋值的类型为数字
         * @param command       自定义指令，取值参考'custom_command_t'枚举
         * @param number        需要设置的值
         * @param execute_ret   执行返回参数
         *          result                     指令执行结果
         *          type                       执行返回值的类型
         *          data.value                 读取的值
         * @param timeout_ms    超时时间（单位毫秒）
         * @return 0:成功；其他值:失败
         */
        int (*assign_number)(custom_command_t command, int number, execute_ret_t *execute_ret, int timeout_ms);

        /**
         * 功能:自定义指令中的获取操作
         * @param command       自定义指令，取值参考'custom_command_t'枚举
         * @param execute_ret   执行返回参数
         *          result                     指令执行结果
         *          type                       执行返回值的类型
         *          data.string                读取的字符串（根据type读取）
         *          data.value                 读取的值（根据type读取）
         * @param timeout_ms    超时时间（单位毫秒）
         * @return 0:成功；其他值:失败
         */
        int (*query)(custom_command_t command, execute_ret_t *execute_ret, int timeout_ms);

        /**
         * 功能:自定义指令中的执行操作
         * @param command       自定义指令，取值参考'custom_command_t'枚举
         * @param execute_ret   执行返回参数
         *          result                     指令执行结果
         * @param timeout_ms    超时时间（单位毫秒）
         * @return 0:成功；其他值:失败
         */
        int (*action)(custom_command_t command, execute_ret_t *execute_ret, int timeout_ms);

        /**
         * 功能:自定义指令中的批量设置操作
         * @param setting_batch
         *          command                    自定义指令，取值参考'custom_command_t'枚举
         *          data.string                需要设置的字符串（会根据command选择）
         *          data.value                 需要设置的值（会根据command选择）
         * @param batch_size        批量设置的数量
         * @param execute_ret       执行返回参数（只会返回最后一次设置的参数）
         *          result                     指令执行结果
         *          type                       执行返回值的类型
         *          data.string                读取的字符串（根据type读取）
         *          data.value                 读取的值（根据type读取）
         * @param timeout_ms    超时时间（单位毫秒）
         * @return 0:成功；其他值:失败（只会返回最后一次执行的结果）
         */
        int (*batch_assign)(setting_batch_t *setting_batch, int batch_size, execute_ret_t *execute_ret, int timeout_ms);

    } setting_t;

    typedef struct listener
    {
        /**
         * 功能:设置缺纸状态监听，在打印机缺纸时触发
         * @param enable   使能此功能，0关闭，1开启
         * @param handler  缺纸状态解除时触发回调通知打印机状态，关闭功能时，回调无效，每次打开功能，都需重新设置此回调
         */
        struct listener *(*no_paper)(uint8_t enable, void (*handler)(void));

        /**
         * 功能:设置缺纸状态解除监听，在打印机缺纸状态解除时触发
         * @param enable   使能此功能，0关闭，1开启
         * @param handler  缺纸状态解除时触发回调通知打印机状态，关闭功能时，回调无效，每次打开功能，都需重新设置此回调
         */
        struct listener *(*paper_ok)(uint8_t enable, void (*handler)(void));

        /**
         * 功能:设置过热状态监听，在打印机过热时触发
         * @param enable   使能此功能，0关闭，1开启
         * @param handler  缺纸状态解除时触发回调通知打印机状态，关闭功能时，回调无效，每次打开功能，都需重新设置此回调
         */
        struct listener *(*temp_high)(uint8_t enable, void (*handler)(void));

        /**
         * 功能:设置过热状态解除监听，在打印机解除过热状态时触发
         * @param enable   使能此功能，0关闭，1开启
         * @param handler  缺纸状态解除时触发回调通知打印机状态，关闭功能时，回调无效，每次打开功能，都需重新设置此回调
         */
        struct listener *(*temp_ok)(uint8_t enable, void (*handler)(void));

        /**
         * 功能:设置USB重连事件监听，在打印机USB断开后重新连接时触发
         * @param enable   使能此功能，0关闭，1开启
         * @param handler  usb重连时触发回调通知打印机状态，关闭功能时，回调无效，每次打开功能，都需重新设置此回调
         */
        struct listener *(*usb_connect)(uint8_t enable, void (*handler)(void));

        /**
         * 功能:设置USB重连事件监听，在打印机USB断开时触发
         * @param enable   使能此功能，0关闭，1开启
         * @param handler  usb断开时触发回调通知打印机状态，关闭功能时，回调无效，每次打开功能，都需重新设置此回调
         */
        struct listener *(*usb_disconnect)(uint8_t enable, void (*handler)(void));

        /**
         * 功能:开启状态监听功能，相应开启监听状态并设置回调的状态会进入监听状态
         *
         */
        void (*on)(void);

        /**
         * 功能:关闭状态监听功能
         *
         */
        void (*off)(void);

        /**
         * @brief 指令转译函数
         */
        void (*cmd_process)(void);

    } listener_t;

    typedef struct raw
    {
        /**
         * 功能:原生发送接口，调用此接口可以发送自定义数据到打印机
         * @param buffer  数据缓冲区
         * @param len     数据长度
         * @param timeout 超时时间
         * 返回值:发送成功时返回发送数据长度，失败时返回-1
         */
        int (*send)(uint8_t *buffer, int len, int timeout);

    } raw_t;

    typedef struct curve
    {
        /**
         * 功能:水平打印n条线段，连续使用该指令可以打印出用户所需要的线段，线段的数据不必按照顺序排列。
         * @param n           打印的线段数量，取值范围（0 ≤ n ≤ 8）
         * @param params[]    线段数据，格式为：xksL,xksH,xkeL,xkeH.....xksL 第k条线段起始点横向坐标的低位,xksH 第k条线段起始点横向坐标的高位,xksH 第k条线段起始点横向坐标的高位,xkeH 第k条线段结束点横向坐标的高位,坐标从打印区域最左侧开始计算，最小值为0，最大值为575，也就是说xkeL+xkeH*256最大值为575。
         */
        struct curve *(*line)(uint8_t n, uint8_t **params);

        /**
         * 功能:打印曲线上的文字,本命令自动将文字旋转了90度(字符串整体顺时针旋转)。
         * @param word            n xL xH c1 c2 … 	n 文字编号 xL xH	为字符横向坐标的；c1 c2 …  最大可以输入3个字符。
         * @param word_len        字符串长度
         */
        struct curve *(*word)(const uint8_t *word, uint8_t word_len);

        /**
         * 功能:初始化曲线打印数组，使用曲线数组必须调用
         */
        struct curve *(*init)(void);

        /**
         * 功能:写入曲线数组
         * @param n          打印数组的曲线个数
         * @param array      打印数组，按照想要打印的曲线个数为组填入，例如n=2时 曲线数组中 0x01,0x00,0x01,0x00,0x30,0x00,0x30,0x00 为一行（n*4），然后循环写入数组
         * @param len        数组中元素个数
         */
        struct curve *(*write_array)(int n, const uint8_t *array, int len);

        /**
         * 功能:调用该函数进入预备打印状态，获取曲线数组数据。
         */
        struct curve *(*printf_array)();

        /**
         * 功能:结束曲线打印，或者结束曲线数组打印，并最终整体打印出来
         */
        struct curve *(*stop)();

    } curve_t;

    typedef struct printer
    {
        device_t *(*device)(void);     // 管理函数
        buffer_t *(*buffer)(void);     // 缓冲区相关函数
        text_t *(*text)(void);         // 文本相关函数
        setting_t *(*setting)(void);   // 参数设置相关函数
        listener_t *(*listener)(void); // 状态监听相关功能
        raw_t *(*raw)(void);           // 原生接口功能
        curve_t *(*curve)(void);       // 曲线打印功能
    } printer_t;

    /**
     * 功能:获取打印机函数指针
     */
    PRINTER_API printer_t *new_printer();

#ifdef __cplusplus
}
#endif

#endif
