/**
 * WeChat Tag Group - v11
 * 直接获取"客户"标签的联系人
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static BOOL _alertShown = NO;

static void showDebugAlert(NSString *info) {
    if (_alertShown) return;
    _alertShown = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"WeChatTagGroup v11"
                                                                       message:info
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    if (!_alertShown) {
        NSString *className = NSStringFromClass([self class]);
        if ([className isEqualToString:@"NewMainFrameViewController"]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                NSMutableString *info = [NSMutableString string];
                
                // 1. 获取 MMServiceCenter
                Class serviceCenterClass = NSClassFromString(@"MMServiceCenter");
                id serviceCenter = nil;
                if (serviceCenterClass && [serviceCenterClass respondsToSelector:@selector(defaultCenter)]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    serviceCenter = [serviceCenterClass performSelector:@selector(defaultCenter)];
                    #pragma clang diagnostic pop
                }
                
                // 2. 获取 ContactTagMgr
                Class tagMgrClass = NSClassFromString(@"ContactTagMgr");
                id tagMgr = nil;
                if (serviceCenter && tagMgrClass && [serviceCenter respondsToSelector:@selector(getService:)]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    tagMgr = [serviceCenter performSelector:@selector(getService:) withObject:tagMgrClass];
                    #pragma clang diagnostic pop
                }
                if (!tagMgr && tagMgrClass) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    tagMgr = [[tagMgrClass alloc] init];
                    #pragma clang diagnostic pop
                }
                
                [info appendFormat:@"ContactTagMgr: %@\n", tagMgr ? @"获取成功" : @"失败"];
                
                if (tagMgr) {
                    // 3. 先尝试 shouldGetAllLabelsFromServer 刷新数据
                    SEL refreshSel = NSSelectorFromString(@"shouldGetAllLabelsFromServer");
                    if ([tagMgr respondsToSelector:refreshSel]) {
                        [info appendString:@"\n[刷新标签数据]\n"];
                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        [tagMgr performSelector:refreshSel];
                        #pragma clang diagnostic pop
                        [info appendString:@"已调用刷新\n"];
                    }
                    
                    // 4. 获取所有标签列表 GetContactLabelItemsFromFile
                    SEL labelItemsSel = NSSelectorFromString(@"GetContactLabelItemsFromFile");
                    if ([tagMgr respondsToSelector:labelItemsSel]) {
                        [info appendString:@"\n[所有标签列表]\n"];
                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        id labelItems = [tagMgr performSelector:labelItemsSel];
                        #pragma clang diagnostic pop
                        if (labelItems && [labelItems isKindOfClass:[NSArray class]]) {
                            [info appendFormat:@"共有 %lu 个标签\n", (unsigned long)[labelItems count]];
                            
                            // 找"客户"标签
                            NSString *customerTagID = nil;
                            for (id item in labelItems) {
                                // 尝试获取标签名和ID
                                NSString *name = nil;
                                NSString *tagId = nil;
                                
                                // 尝试属性
                                SEL nameSel = NSSelectorFromString(@"getLabelName");
                                if ([item respondsToSelector:nameSel]) {
                                    #pragma clang diagnostic push
                                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                    name = [item performSelector:nameSel];
                                    #pragma clang diagnostic pop
                                }
                                
                                SEL idSel = NSSelectorFromString(@"getLabelId");
                                if ([item respondsToSelector:idSel]) {
                                    #pragma clang diagnostic push
                                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                    tagId = [item performSelector:idSel];
                                    #pragma clang diagnostic pop
                                }
                                
                                if (name) {
                                    [info appendFormat:@"  标签: %@ (ID: %@)\n", name, tagId ? tagId : @"?"];
                                    
                                    if ([name isEqualToString:@"客户"]) {
                                        customerTagID = tagId;
                                        [info appendString:@"  ★ 找到了\"客户\"标签!\n"];
                                    }
                                }
                            }
                            
                            // 5. 如果找到"客户"标签ID，获取该标签的联系人
                            if (customerTagID) {
                                [info appendFormat:@"\n[获取\"客户\"标签联系人, TagID: %@]\n", customerTagID];
                                
                                // 这里可能需要调用某个方法通过TagID获取联系人
                                // 或者用 getContactTagIDListToNameList: 传入标签名
                                SEL getByTagSel = NSSelectorFromString(@"getContactTagIDListToNameList:");
                                if ([tagMgr respondsToSelector:getByTagSel]) {
                                    [info appendString:@"尝试 getContactTagIDListToNameList:\n"];
                                }
                            }
                        } else if (labelItems) {
                            [info appendFormat:@"返回类型: %@\n", NSStringFromClass([labelItems class])];
                        } else {
                            [info appendString:@"返回为空\n"];
                        }
                    } else {
                        [info appendString:@"GetContactLabelItemsFromFile 不可用\n"];
                    }
                    
                    // 6. 列出 ContactTagMgr 所有方法
                    [info appendString:@"\n[ContactTagMgr 完整方法列表]\n"];
                    unsigned int mcount = 0;
                    Method *methods = class_copyMethodList(tagMgrClass, &mcount);
                    if (methods) {
                        for (unsigned int i = 0; i < mcount; i++) {
                            NSString *mn = NSStringFromSelector(method_getName(methods[i]));
                            [info appendFormat:@"  %@\n", mn];
                        }
                        free(methods);
                    }
                }
                
                showDebugAlert(info);
            });
        }
    }
}
%end

%ctor {
    NSLog(@"[WeChatTagGroup] v11已加载");
}