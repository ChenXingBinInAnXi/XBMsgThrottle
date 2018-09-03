XBMsgThrottle

本库已经配置到cocoapods。 在podfile文件中加入 pod 'XBMsgThrottle', '~> 1.0.1' 或 pod "XBMsgThrottle" 使用 pod XBMsgThrottle即可一键引入。

MessageThrottle：
1.不支持类方法。
2.添加多个Rule，然后进行移除的时候，会崩溃。

XBMsgThrottle：
1.支持类方法。
2.支持添加多个Item，移除的时候不影响。
3.更加简化的代码逻辑。



+ (XBThrottleItem *)throttleTarget:(id)target selector:(SEL)selector durationInterval:(NSTimeInterval)durationInterval;
向Throttle直接添加Target和selector进行消息限制

XBThrottleItem：一个Item代表一个消息节流，重写hash函数，保证唯一性。
用Hook进行消息拦截。


参考：https://github.com/yulingtianxia/MessageThrottle
感谢杨萧玉大佬提供的资料，我在此基础上更改了规则。
