//
//  XBMsgThrottle.m
//  XBMsgThrottle
//
//  Created by chenxingbin on 2018/7/9.
//  Copyright © 2018年 chenxingbin. All rights reserved.
//

#import "XBMsgThrottle.h"
#import <objc/message.h>
#import <objc/runtime.h>





@interface XBTargetInfo : NSObject
@property (nonatomic,strong) NSMutableDictionary *selectorItems;
@property (nonatomic) dispatch_semaphore_t lock;
@end

@implementation XBTargetInfo

- (instancetype)init{
    self = [super init];
    if (self) {
        _selectorItems = NSMutableDictionary.new;
        _lock = dispatch_semaphore_create(1);
    }
    return self;
}

@end



@interface XBThrottleItem()
@property (nonatomic,assign) NSTimeInterval lastTimeInterval;
@property (nonatomic,strong) NSInvocation *lastInvocation;
@end

@implementation XBThrottleItem

- (instancetype)init{
    NSCAssert(NO, @"请使用initWithTarget:selector:durationInterval:mode创建XBThrottleItem实例");
    self = [super init];
    return self;
}
-(instancetype)initWithTarget:(id)target selector:(SEL)selector durationInterval:(NSTimeInterval)durationInterval mode:(XBThrottleMode)mode{
    self = [super init];
    if (self) {
        _target = target;
        _selector = selector;
        _durationInterval = durationInterval;
        _mode = mode;
        _msgQueue = dispatch_get_main_queue();
        _lastTimeInterval = 0;
    }
    return self;
}
@end

@interface XBMsgThrottle (){
    dispatch_semaphore_t _lock;
}

@property (nonatomic,strong) NSMapTable<id, NSMutableSet<NSString *> *> *targetSelsTable;
@property (nonatomic,strong) NSMapTable *aliasTable;

@end

@implementation XBMsgThrottle

+(instancetype)sharedThrottle{
    static XBMsgThrottle *msgThrottle;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        msgThrottle = [[XBMsgThrottle alloc] initThrottle];
    });
    return msgThrottle;
}
-(instancetype)init{
    NSCAssert(NO, @"请使用sharedThrottle拿到XBMsgThrottle实例");
    self = [super init];
    return self;
}
-(instancetype)initThrottle{
    self = [super init];
    if (self){
        _targetSelsTable = [NSMapTable weakToStrongObjectsMapTable];
        _aliasTable = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSMapTableObjectPointerPersonality valueOptions:NSPointerFunctionsOpaqueMemory | NSMapTableObjectPointerPersonality];
        _lock = dispatch_semaphore_create(1);
    }
    return self;
}

#pragma mark private
-(SEL)aliasForSelector:(SEL)selector{
    //线程安全

    
    SEL aliaSelector = (__bridge void *)[XBMsgThrottle.sharedThrottle.aliasTable objectForKey:(__bridge id)(void *)selector];
    if (aliaSelector == nil) {
        NSString *selectorName = NSStringFromSelector(selector);
        aliaSelector = NSSelectorFromString([NSString stringWithFormat:@"__xb_%@",selectorName]);
        [XBMsgThrottle.sharedThrottle.aliasTable setObject:(__bridge id)(void *)aliaSelector forKey:(__bridge id)(void *)selector];
    }
    

    return aliaSelector;
}

const char *XBTargetInfoKey = "XBTargetInfoKey";
-(XBTargetInfo *)targetInfo:(id)target{
    XBTargetInfo *targetInfo = objc_getAssociatedObject(target, XBTargetInfoKey);
    if (!targetInfo) {
        targetInfo = XBTargetInfo.new;
        objc_setAssociatedObject(target, XBTargetInfoKey, targetInfo, OBJC_ASSOCIATION_RETAIN);
    }
    return targetInfo;
}
-(void)persistentItem:(XBThrottleItem *)item{


    id target = item.target;
    NSString *selectorName = NSStringFromSelector(item.selector);
    
    XBTargetInfo *targetInfo = [self targetInfo:target];
    targetInfo.selectorItems[selectorName] = item;

}

-(XBThrottleItem *)itemWithTarget:(id)target selector:(SEL)selector{
    NSString *selectorName = NSStringFromSelector(selector);
    XBTargetInfo *targetInfo = [self targetInfo:target];
    XBThrottleItem *item = targetInfo.selectorItems[selectorName];
    return item;
}


- (void)addSelector:(SEL)selector onTarget:(id)target{
    if (!target) return;
    
    NSMutableSet *selectors = [self.targetSelsTable objectForKey:target];
    if (!selectors) {
        selectors = [NSMutableSet set];
    }
    [selectors addObject:NSStringFromSelector(selector)];
    [self.targetSelsTable setObject:selectors forKey:target];
}
- (void)removeSelector:(SEL)selector onTarget:(id)target{
    if (!target) return;

    NSMutableSet *selectors = [self.targetSelsTable objectForKey:target];
    if (!selectors) {
        selectors = [NSMutableSet set];
       [self.targetSelsTable setObject:selectors forKey:target];
    }
    [selectors removeObject:NSStringFromSelector(selector)];
 
}


#pragma mark public
-(void)addItem:(XBThrottleItem *)item{
    //线程安全
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    //检测Item

    for (id target in [self.targetSelsTable.keyEnumerator allObjects]) {
        NSMutableSet *selectors = [self.targetSelsTable objectForKey:target];
        
        for (NSString *selectorName in selectors) {
            if (sel_isEqual(item.selector, NSSelectorFromString(selectorName)) && object_isClass(item.target) && object_isClass(target)) {
                Class clsA = item.target;
                Class clsB = target;
                
                BOOL boolApplay = !([clsA isSubclassOfClass:clsB] || [clsB isSubclassOfClass:clsA]);
                NSCAssert(boolApplay, @"Error: %@ already apply rule in %@. A message can only have one rule per class hierarchy.", selectorName, NSStringFromClass(clsB));
            }
        }
    }

    [self addSelector:item.selector onTarget:item.target];
    [self persistentItem:item];
     overrideMothod(item.target, item.selector);
    
    dispatch_semaphore_signal(_lock);
}

-(void)removeItem:(XBThrottleItem *)item{
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    //线程安全
    [self removeSelector:item.selector onTarget:item.target];
    Class cls = xb_classOfTarget(item.target);
    xb_revertHook(cls, item.selector);
    
    dispatch_semaphore_signal(_lock);
}

#pragma mark base

static NSString *const XBForwardInvocationSelectorName = @"__xb_forwardInvocation:";

static inline BOOL xb_object_isClass(id _Nullable obj){
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_8_0 || __TV_OS_VERSION_MIN_REQUIRED >= __TVOS_9_0 || __WATCH_OS_VERSION_MIN_REQUIRED >= __WATCHOS_2_0 || __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_10_10
    return object_isClass(obj);
#else
    if (!obj) return NO;
    return obj == [obj class];
#endif
}

static Class xb_classOfTarget(id target){
    Class cls;
    if (xb_object_isClass(target)){
        cls = target;
    }else {
        cls = object_getClass(target);
    }
    return cls;
}


#pragma mark hook 技术
static void overrideMothod(id target,SEL selector){
    Class cls = xb_classOfTarget(target);
    
    Method originalMethod = class_getInstanceMethod(cls, selector);
    
    if (originalMethod == nil){
        NSCAssert(NO, @"unrecoginzed selector -%@ for class %@",NSStringFromSelector(selector),NSStringFromClass(cls));
        return;
    }
    
    const char *originalType = method_getTypeEncoding(originalMethod);
    IMP originalIMP = class_respondsToSelector(cls, selector) ? class_getMethodImplementation(cls, selector) : NULL;
    
    IMP msgForwardIMP = _objc_msgForward;
#if !defined(__arm64__)
    if (originalType[0] == _C_STRUCT_B) {
        NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:originalType];
        if ([methodSignature.debugDescription rangeOfString:@"is special struct return? YES"].location != NSNotFound) {
            msgForwardIMP = (IMP)_objc_msgForward_stret;
        }
    }
#endif
    if (originalIMP == msgForwardIMP) return;
    
    if (class_getMethodImplementation(cls, @selector(forwardInvocation:)) != (IMP)xb_forwardInvocation){
        IMP originalForwardIMP = class_replaceMethod(cls, @selector(forwardInvocation:), (IMP)xb_forwardInvocation, "v@:@");
        if (originalForwardIMP) {
            class_addMethod(cls,NSSelectorFromString(XBForwardInvocationSelectorName), originalForwardIMP, "v@:@");
        }
    }
    
    
    if (class_respondsToSelector(cls, selector)) {
        SEL fixedOriginalSelector = [XBMsgThrottle.sharedThrottle aliasForSelector:selector];
        if (!class_respondsToSelector(cls, fixedOriginalSelector)) {
            class_addMethod(cls, fixedOriginalSelector, originalIMP, originalType);
        }
    }
    
    // Replace the original selector at last, preventing threading issus when
    // the selector get called during the execution of `overrideMethod`
    class_replaceMethod(cls, selector, msgForwardIMP, originalType);
}

static void xb_forwardInvocation(__unsafe_unretained id slf,SEL selector,NSInvocation *invocation){
    
    SEL originalSelector = invocation.selector;
    SEL fixedOriginalSelector = [XBMsgThrottle.sharedThrottle aliasForSelector:originalSelector];
    
    if (![slf respondsToSelector:fixedOriginalSelector]) {
        xb_executeOriginForwardInvocation(slf,selector,invocation);
        return;
    }
    
    //线程安全
    XBTargetInfo *info = [XBMsgThrottle.sharedThrottle targetInfo:invocation.target];
    dispatch_semaphore_wait(info.lock, DISPATCH_TIME_FOREVER);
    xb_handleInvocation(invocation, fixedOriginalSelector);
    dispatch_semaphore_signal(info.lock);
}


static void xb_executeOriginForwardInvocation(id slf,SEL selector,NSInvocation *invocation){
    SEL originForwardSelector = NSSelectorFromString(XBForwardInvocationSelectorName);
    if ([slf respondsToSelector:originForwardSelector]) {
        
        NSMethodSignature *methodSignature = [slf methodSignatureForSelector:originForwardSelector];
        if (!methodSignature) {
            NSCAssert(NO, @"unrecognized selector -%@ for instance %@", NSStringFromSelector(originForwardSelector), slf);
            return;
        }
        NSInvocation *forwardInv= [NSInvocation invocationWithMethodSignature:methodSignature];
        [forwardInv setTarget:slf];
        [forwardInv setSelector:originForwardSelector];
        [forwardInv setArgument:&invocation atIndex:2];
        [forwardInv invoke];
        
    }else{
        Class superCls = [[slf class] superclass];
        Method superForwardMethod = class_getInstanceMethod(superCls, @selector(forwardInvocation:));
        void (*superForwardIMP)(id, SEL, NSInvocation *);
        superForwardIMP = (void (*)(id, SEL, NSInvocation *))method_getImplementation(superForwardMethod);
        superForwardIMP(slf, @selector(forwardInvocation:), invocation);
    }
}


static void xb_handleInvocation(NSInvocation *invocation,SEL fixedSelector){
    XBThrottleItem *item = [XBMsgThrottle.sharedThrottle itemWithTarget:invocation.target selector:invocation.selector];
    
    if (item.durationInterval <= 0) {
        invocation.selector = fixedSelector;
        [invocation invoke];
    }
    
    NSTimeInterval nowInterval = NSDate.date.timeIntervalSince1970;
    switch (item.mode) {
        case XBThrottleModePerBegin:{
            if (nowInterval - item.lastTimeInterval > item.durationInterval) {
                item.lastTimeInterval = nowInterval;
                invocation.selector = fixedSelector;
                [invocation invoke];
                item.lastInvocation = nil;
            }
            break;
        }
            
        case XBThrottleModePerEnd:{
            if (nowInterval - item.lastTimeInterval > item.durationInterval) {
                item.lastTimeInterval = nowInterval;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(item.durationInterval * NSEC_PER_SEC)),item.msgQueue, ^{
                    [item.lastInvocation invoke];
                    item.lastInvocation = nil;
                });
            }
            break;
        }
            
        case XBThrottleModePerDebounce:{
            
            invocation.selector = fixedSelector;
            item.lastInvocation = invocation;
            [item.lastInvocation retainArguments];
            if (nowInterval - item.lastTimeInterval > item.durationInterval) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(item.durationInterval * NSEC_PER_SEC)),item.msgQueue, ^{
                    if (item.lastInvocation == invocation) {
                        [item.lastInvocation invoke];
                        item.lastInvocation = nil;
                    }
             
                });
            }
            break;
        }
            
        default:
            break;
    }
    
}



static void xb_revertHook(Class cls,SEL selector){
    
    if (class_getMethodImplementation(cls, @selector(forwardInvocation:)) == (IMP)xb_forwardInvocation){
        IMP originalForwardIMP = class_getMethodImplementation(cls, NSSelectorFromString(XBForwardInvocationSelectorName));
        if (originalForwardIMP) {
            class_replaceMethod(cls, @selector(forwardInvocation:), originalForwardIMP, "v@:@");
        }
    }else{ return;}
    
    Method originMethod = class_getInstanceMethod(cls, selector);
    if (!originMethod) {
        NSCAssert(NO, @"unrecognized selector -%@ for class %@", NSStringFromSelector(selector), NSStringFromClass(cls));
    }
    
    const char *originType = (char *)method_getTypeEncoding(originMethod);
    
    SEL fixedOriginalSelector = [XBMsgThrottle.sharedThrottle aliasForSelector:selector];
    if (class_respondsToSelector(cls, fixedOriginalSelector)) {

        IMP originalIMP = class_getMethodImplementation(cls, fixedOriginalSelector);
        class_replaceMethod(cls, selector, originalIMP, originType);
    }
    
}



@end


@implementation NSObject (XBMsgThrottle)


- (XBThrottleItem *)limitSelector:(SEL)selector durationInterval:(NSTimeInterval)durationInterval{
    XBThrottleItem *item = [[XBThrottleItem alloc] initWithTarget:self selector:selector durationInterval:durationInterval mode:XBThrottleModePerDebounce];
    [XBMsgThrottle.sharedThrottle addItem:item];
    return item;
}

- (XBThrottleItem *)limitSelector:(SEL)selector durationInterval:(NSTimeInterval)durationInterval mode:(XBThrottleMode)mode{
    XBThrottleItem *item = [[XBThrottleItem alloc] initWithTarget:self selector:selector durationInterval:durationInterval mode:mode];
    [XBMsgThrottle.sharedThrottle addItem:item];
    return item;
}

- (XBThrottleItem *)limitSelector:(SEL)selector durationInterval:(NSTimeInterval)durationInterval mode:(XBThrottleMode)mode msgQuene:(dispatch_queue_t)msgQuene{
    XBThrottleItem *item = [[XBThrottleItem alloc] initWithTarget:self selector:selector durationInterval:durationInterval mode:mode];
    item.msgQueue = msgQuene;
    [XBMsgThrottle.sharedThrottle addItem:item];
    return item;
}

@end



