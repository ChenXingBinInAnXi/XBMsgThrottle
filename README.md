XBMsgThrottle

本库已经配置到cocoapods。 在podfile文件中加入 pod 'XBMsgThrottle', '~> 1.0.1' 或 pod "XBMsgThrottle" 使用 pod XBMsgThrottle即可一键引入。

+ (XBThrottleItem *)throttleTarget:(id)target selector:(SEL)selector durationInterval:(NSTimeInterval)durationInterval;
向Throttle直接添加Target和selector进行消息限制

XBThrottleItem：一个Item代表一个消息节流，重写hash函数，保证唯一性。
用Hook进行消息拦截。


参考：https://github.com/yulingtianxia/MessageThrottle
感谢杨萧玉大佬提供的资料，我在此基础改进修复了一些缺陷。