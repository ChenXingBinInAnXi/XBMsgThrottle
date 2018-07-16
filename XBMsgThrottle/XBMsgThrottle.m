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
@property (nonatomic,strong) NSMutableSet *itemSet;
@property (nonatomic) dispatch_semaphore_t lock;
@end

@implementation XBTargetInfo

- (instancetype)init{
    self = [super init];
    if (self) {
        _itemSet = [NSMutableSet new];
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


-(NSUInteger)hash{
    long v1 = (long)((void *)_selector);
    long v2 = (long)_target;
    return v1 ^ v2;
}


+(NSUInteger)hashWithTarget:(id)target selector:(SEL)selector{
    long v1 = (long)((void *)selector);
    long v2 = (long)target;
    return v1 ^ v2;
}

-(BOOL)isEqual:(XBThrottleItem *)object{
    if ( !object.target || !object.selector) return NO;
    if ( !self.target || !self.selector) return NO;
    if ([self hash] == [object hash]) return YES;
    return NO;
}

@end

@interface XBMsgThrottle(){
    dispatch_semaphore_t _lock;
}
@property (nonatomic,strong) NSPointerArray *items;
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
        _items = [NSPointerArray weakObjectsPointerArray];
        _aliasTable = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSMapTableObjectPointerPersonality valueOptions:NSPointerFunctionsOpaqueMemory | NSMapTableObjectPointerPersonality];
        _lock = dispatch_semaphore_create(1);
    }
    return self;
}

#pragma mark private
-(SEL)aliasForSelector:(SEL)selector{
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

-(XBThrottleItem *)itemWithTarget:(id)target selector:(SEL)selector{
    XBTargetInfo *targetInfo = [self targetInfo:target];
    
    for (XBThrottleItem *item in targetInfo.itemSet) {
        if (item.hash == [XBThrottleItem hashWithTarget:target selector:selector]) {
            return item;
        }
    }
    return nil;
}


-(void)checkItemClass:(XBThrottleItem *)item{
    for (XBThrottleItem *exitsItem in self.items.allObjects){
        if (sel_isEqual(item.selector,exitsItem.selector) && object_isClass(item.target) && object_isClass(exitsItem.target)) {
            
            Class clsA = exitsItem.target;
            Class clsB = item.target;
            
            BOOL boolApplay = !([clsA isSubclassOfClass:clsB] || [clsB isSubclassOfClass:clsA]);
            NSCAssert(boolApplay, @"Error: %@ already apply rule in %@. A message can only have one rule per class hierarchy.", NSStringFromSelector(item.selector), NSStringFromClass(clsB));
        }
        
    }
}


#pragma mark public
-(void)addItem:(XBThrottleItem *)item{
 
   dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    
    if ([[self.items allObjects] containsObject:item]) {  dispatch_semaphore_signal(_lock);  return;}
    

    [self checkItemClass:item];

    XBTargetInfo *info = [self targetInfo:item.target];
    [info.itemSet addObject:item];
    [self.items addPointer:(__bridge void * _Nullable)(item)];
    
    xb_hookMethod(item.target, item.selector);
    dispatch_semaphore_signal(_lock);
}

-(void)removeItem:(XBThrottleItem *)item{
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    if (![[self.items allObjects] containsObject:item]) {   dispatch_semaphore_signal(_lock); return;}
    

    NSUInteger index = [self.items.allObjects indexOfObject:item];
    [self.items removePointerAtIndex:index];
    XBTargetInfo *info = [self targetInfo:item.target];
    [info.itemSet removeObject:item];
    
     Class cls = object_getClass(item.target);
    info.itemSet.count > 0? xb_reverkTarget(cls,item.selector) : xb_revertHook(cls,item.selector);
    
    dispatch_semaphore_signal(_lock);
}


+ (XBThrottleItem *)throttleTarget:(id)target selector:(SEL)selector durationInterval:(NSTimeInterval)durationInterval{
    return [self throttleTarget:(id)target selector:selector durationInterval:durationInterval mode:XBThrottleModeDefaultDebounce];;
}
+ (XBThrottleItem *)throttleTarget:(id)target selector:(SEL)selector durationInterval:(NSTimeInterval)durationInterval mode:(XBThrottleMode)mode{
     return [self throttleTarget:(id)target selector:selector durationInterval:durationInterval mode:mode msgQuene:dispatch_get_main_queue()];
}

+(XBThrottleItem *)throttleTarget:(id)target selector:(SEL)selector durationInterval:(NSTimeInterval)durationInterval mode:(XBThrottleMode)mode msgQuene:(dispatch_queue_t)msgQuene{
    XBThrottleItem *item = [[XBThrottleItem alloc] initWithTarget:target selector:selector durationInterval:durationInterval mode:mode];
    item.msgQueue = msgQuene;
    [XBMsgThrottle.sharedThrottle addItem:item];
    return item;
}

#pragma mark base
static NSString *const XBForwardInvocationSelectorName = @"__xb_forwardInvocation:";
#pragma mark hook 技术
static void xb_hookMethod(id target,SEL selector){
    Class cls = object_getClass(target);

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
        NSInvocation *forwardIncation = [NSInvocation invocationWithMethodSignature:methodSignature];
        [forwardIncation setTarget:slf];
        [forwardIncation setSelector:originForwardSelector];
        [forwardIncation setArgument:&invocation atIndex:2];
        [forwardIncation invoke];
        
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
            
        case XBThrottleModeDefaultDebounce:{
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








static void xb_reverkTarget(Class cls,SEL selector){

    Method originMethod = class_getInstanceMethod(cls, selector);
    if (!originMethod) NSCAssert(NO,@"unrecognized selector -%@ for class %@", NSStringFromSelector(selector), NSStringFromClass(cls));
    
    SEL fixedOriginalSelector = [XBMsgThrottle.sharedThrottle aliasForSelector:selector];
    const char *orginalType = (char *)method_getTypeEncoding(originMethod);
    if (class_respondsToSelector(cls,fixedOriginalSelector)) {
        IMP originalIMP = class_getMethodImplementation(cls, fixedOriginalSelector);
        class_replaceMethod(cls, selector, originalIMP, orginalType);
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





