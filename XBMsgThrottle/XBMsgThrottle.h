//
//  XBMsgThrottle.h
//  XBMsgThrottle
//
//  Created by chenxingbin on 2018/7/9.
//  Copyright © 2018年 chenxingbin. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSUInteger,XBThrottleMode){
    XBThrottleModePerBegin,
    XBThrottleModePerEnd,
    XBThrottleModeDefaultDebounce,//默认
};


@interface XBThrottleItem : NSObject

@property (nonatomic,weak,readonly) id target;
@property (nonatomic, readonly) SEL selector;
@property (nonatomic,assign,readonly) NSTimeInterval durationInterval;
@property (nonatomic,assign,readonly) XBThrottleMode mode;
@property (nonatomic) dispatch_queue_t msgQueue;
-(instancetype)initWithTarget:(id)target selector:(SEL)selector durationInterval:(NSTimeInterval)durationInterval mode:(XBThrottleMode)mode;

@end



@interface XBMsgThrottle : NSObject

+(instancetype)sharedThrottle;

-(void)addItem:(XBThrottleItem *)item;
-(void)removeItem:(XBThrottleItem *)item;


+ (XBThrottleItem *)throttleTarget:(id)target selector:(SEL)selector durationInterval:(NSTimeInterval)durationInterval;
+ (XBThrottleItem *)throttleTarget:(id)target selector:(SEL)selector durationInterval:(NSTimeInterval)durationInterval mode:(XBThrottleMode)mode;
+(XBThrottleItem *)throttleTarget:(id)target selector:(SEL)selector durationInterval:(NSTimeInterval)durationInterval mode:(XBThrottleMode)mode msgQuene:(dispatch_queue_t)msgQuene;

@end






