//
//  AppDelegate.m
//  CIBSafeBrowser
//
//  Created by cib on 14/12/4.
//  Copyright (c) 2014年 cib. All rights reserved.
//

#import "AppDelegate.h"

#import "LoginViewController.h"
#import "CustomWebViewController.h"
#import "MainViewController.h"
#import "MenuViewController.h"

#import "CIBURLProtocol.h"
#import "MyUtils.h"
#import "Config.h"
#import "CoreDataManager.h"
#import "AppProduct.h"
#import "SecUtils.h"
#import "CIBURLCache.h"
#import "CIBResourceInfo.h"

#import "UIImage+BlurGlass.h"

#import <CIBBaseSDK/CIBBaseSDK.h>
#import <openssl/crypto.h>
#import "PushManager.h"
//#include <objc/runtime.h>

@interface AppDelegate () <PushManagerDelegate, DeviceTokenDelegate>
{
    NSDate *enterBackgroundTime;  // 进入后台时间
    int lockInterval;  // 进入后台 -> 进入前台 需要解锁的间隔，单位:s
}

@end

@implementation AppDelegate
{
    UILocalNotification *localNotification;
NSDictionary *selectNotiDic;
    }
// Override point for customization after application launch.
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
//    Class LSApplicationWorkspace_class = objc_getClass("LSApplicationWorkspace");
//    NSObject* workspace = [LSApplicationWorkspace_class performSelector:@selector(defaultWorkspace)];
//    NSArray *result = [workspace performSelector:@selector(applicationsAvailableForHandlingURLScheme:)withObject:@"alipay"];
    
    // 解除bug
//    [DeviceKeyManager deleteDeviceKey];
//    [FingerWorkManager clearFingerWork];
//    [AppInfoManager clearUserInfo];

    // 通过推送消息打开应用的情况
    if (launchOptions) {
        NSDictionary *userInfo = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];

        BOOL isWebAppNoti = [userInfo objectForKey:@"isWebAppNoti"];
        if (isWebAppNoti) {
            // 获取推送来自的WebApp名称
            NSString *notiAppName = [userInfo objectForKey:@"appName"];
            // 修改数据库中相应WebApp的通知相关字段
            CoreDataManager *cdManager = [[CoreDataManager alloc] init];
//            NSArray *appList = [cdManager getAppList];
            NSArray *appList = [[AppDelegate delegate] getAppProductList];
            for (AppProduct *app in appList) {
                if ([notiAppName isEqualToString:app.appName]) {
                    int notiNo = [app.notiNo intValue];
                    notiNo ++;
                    app.notiNo = [NSNumber numberWithInt:notiNo];
                    [cdManager updateAppInfo:app];
                    // 更新明文临时变量为空 需要重新从数据库中读取
                    [[AppDelegate delegate] setAppProductList:appList];
                    break;
                }
            }
        }
        else {
            // 如果是应用门户本身的推送消息，做相应处理
            UILocalNotification *notifi = [[UILocalNotification alloc]init];
            notifi=[launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
            [application cancelLocalNotification:notifi];
        }
        
    }
    // 去除app图标上的小红点
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    // 由于mPush的SDK没有注册成功的回调方法，只有收到deviceToken的回调方法。因此，无法判断推送服务是否注册成功。只能采用每次程序启动时，均注册推送服务的方法。
    
    // 注册推送服务
    [PushManager startPushServicePushDelegate:self tokenDelegate:self];
    [PushManager setDebugMode:NO];

    // 设置收到消息的处理Delegate
    [PushManager setPushDelegate:self append:NO];

    
    // 设置初始状态
    self.hasCheckedUpdate = NO;
    self.hasLoadAppListFromServer = NO;
    self.lockVc = nil;
    self.tabList = [[NSMutableArray alloc] init];
    self.isLogin = NO;
    self.isUnlock = NO;
    self.isActive = YES;
    
    // 状态栏浅色
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    
    // UINavigationBar默认样式
    [[UINavigationBar appearance] setBackgroundImage:[MyUtils createImageWithColor:kUIColorLight] forBarMetrics:UIBarMetricsDefault];
    [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
    [[UINavigationBar appearance] setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         [UIColor whiteColor], NSForegroundColorAttributeName,
                                                         [UIFont boldSystemFontOfSize:20], NSFontAttributeName,
                                                         nil]];
    
    // 初始化服务器、应用信息
    // 测试配置
    [AppInfoManager initialAppInfoWithBasicURLAddress:@"https://168.3.23.207:7050/openapi"];
//    [AppInfoManager initialAppInfoWithBasicURLAddress:@"https://220.250.30.210:8050/openapi/"];
//    [AppInfoManager initialAppInfoWithBasicURLAddress:[MyUtils propertyOfResource:@"Setting" forKey:@"BaseUrl"]];
    
    // 使用自定义的NSURLProtocol实现ssl双向认证
    [NSURLProtocol registerClass:[CIBURLProtocol class]];
    
    long cacheTime = [[MyUtils propertyOfResource:@"Setting" forKey:@"CacheExpire"] longValue];
    CIBURLCache *urlCache = [[CIBURLCache alloc] initWithMemoryCapacity:20 * 1024 * 1024
                                                           diskCapacity:200 * 1024 * 1024
                                                               diskPath:[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject]
                                                              cacheTime:cacheTime];
    
    [CIBURLCache setSharedURLCache:urlCache];
    
    // 手势解锁间隔，单位s
    lockInterval = [[MyUtils propertyOfResource:@"Setting" forKey:@"LockInterval"] intValue];
    
    
    
    //获取storyboard: 通过bundle根据storyboard的名字来获取我们的storyboard,
    UIStoryboard *story = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
    //由storyboard根据myView的storyBoardID来获取我们要切换的视图
    MainViewController *mainView = [story instantiateViewControllerWithIdentifier:@"main"];
    MenuViewController *menuView = [story instantiateViewControllerWithIdentifier:@"menu"];
    
    self.sideView = [[CIBSideViewController alloc] initWithMenuViewController:menuView
                                                                          contentViewController:mainView];
    [self.sideView setDerection:CIBSideViewControllerDirectionRight];
    
    self.window.rootViewController = self.sideView;
    [self.window makeKeyAndVisible];
    
    //  如果是第一次启动
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"IsBundleFilesCached"]) {
        /*
        // 将本地包中的js、css等资源文件读取到缓存中
        NSMutableArray *resourceInfoList = [[NSMutableArray alloc] init];
        
        id resourceFileInfoArray = [MyUtils propertyOfResource:@"ResourceFile" forKey:@"ResourceFileInfo"];
        if ([resourceFileInfoArray isKindOfClass:[NSArray class]]) {
            for (NSDictionary *infoDic in resourceFileInfoArray) {
                NSString *url = [infoDic objectForKey:@"url"];
                NSString *fileName = [infoDic objectForKey:@"fileName"];
                NSString *versionCode = [infoDic objectForKey:@"versionCode"];
                NSString *mimeType = [infoDic objectForKey:@"mimeType"];
                NSString *encodingType = [infoDic objectForKey:@"encodingType"];
                CIBResourceInfo *resourceInfo = [[CIBResourceInfo alloc] initWithUrlAddress:url fileName:fileName versionCode:versionCode mimeType:mimeType encodingType:encodingType];
                [resourceInfoList addObject:resourceInfo];
            }
        }
        
        for (CIBResourceInfo *info in resourceInfoList) {
            NSString *localFilePath = [[NSBundle mainBundle] pathForResource:[info fileName] ofType:nil];
            if ([Function isFileExistedAtPath:localFilePath]) {
                [urlCache readLocalFileResourceToCache:info];
            }
        }
         */
        [self cacheLocalResourceFiles];
        // app包里的文件已经复制到缓存中
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"IsBundleFilesCached"];
    }
    
    
    
    if ([SecUtils isP12ExistInDir:[SecUtils defaultCertDir]]) {
        
        // 检查是否达到资源文件检查更新的间隔
        CoreDataManager *cdManager = [[CoreDataManager alloc] init];
        double lastUpdateTime = [cdManager getUpdateTimeByName:@"ResourceFileUpdate"];
        double currentTime = [[NSDate date] timeIntervalSince1970];
        NSNumber *updateTimeInterval = [MyUtils propertyOfResource:@"Setting" forKey:@"ResourceFileUpdateInterval"];
        
        if (lastUpdateTime != 0.0 && currentTime - lastUpdateTime < [updateTimeInterval longValue]) {
            
        }
        else {
            [self updateResourceFileInfo];
        }
    }
    
    _isAppActive = YES;
    
    // 如果本地已经存在浏览器证书的话，把解密后的p12数据读取到全局变量里
    NSString *p12Path = [[SecUtils defaultCertDir] stringByAppendingPathComponent:SecFileP12];
    if ([Function isFileExistedAtPath:p12Path]) {
        NSData *p12data = [NSData dataWithContentsOfFile:p12Path];
        _decryptedP12Data = [[[CryptoManager alloc] init] decryptData:p12data];
    }
    else {
        _decryptedP12Data = nil;
    }
    
    return YES;
}

// 缓存一些常用js、css等资源
- (void) cacheMajorFiles {
    // TODO:缓存白名单中的js和css，下面的列表还需要整理，请玉麦资讯各位webapp开发者
    NSMutableArray *whiteList = [[NSMutableArray alloc] initWithObjects:
                                 @"https://220.250.30.210:8051/contact/js/global/allinone.min.js",
                                 @"https://220.250.30.210:8051/contact/css/global/allinone.min.css",
                                 nil];
    // sendSynchronousRequest请求也要经过NSURLCache，所以无需额外处理
    for (NSString *url in whiteList) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
            [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
        });
    }
}

// 从服务端获取资源文件的更新信息，并更新资源文件
- (void)updateResourceFileInfo {
    
    // 向服务端查询缓存文件的版本信息
    [CIBRequestOperationManager invokeAPI:@"gsfl" byMethod:@"POST" withParameters:nil onRequestSucceeded:^(NSString *responseCode, NSString *responseInfo) {
        if ([responseCode isEqualToString:@"I00"]) {
            NSDictionary *responseDic = (NSDictionary *)responseInfo;
            NSString *resultCode = [responseDic objectForKey:@"resultCode"];
            if ([resultCode isEqualToString:@"0"]) {
                
                
                
                NSArray *resourceInfoList = [responseDic objectForKey:@"result"];
                
                if (resourceInfoList && [resourceInfoList count] != 0) {
                    CoreDataManager *cdManager = [[CoreDataManager alloc] init];
                    [cdManager updateUpdateTimeByName:@"ResourceFileUpdate"];
                }
                
                NSOperationQueue *queue = [[NSOperationQueue alloc] init];
                [queue setMaxConcurrentOperationCount:3];
                
                for (NSDictionary *info in resourceInfoList) {
                    NSString *url = [info objectForKey:@"url"];
                    NSString *versionCode = [info objectForKey:@"versionCode"];
                    NSString *mimeType = [info objectForKey:@"mimeType"];
                    NSString *encodingType = [info objectForKey:@"encoding"];
                    
                    
                    
                    CIBLog(@"queue count: %lu", (unsigned long)[queue operationCount]);
                    
//                    [queue addOperationWithBlock:^{
//                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
//                            
//                            // 将版本信息、mime类型、编码类型写进request的头里，以便后续使用
//                            [request setValue:versionCode forHTTPHeaderField:@"versionCode"];
//                            [request setValue:mimeType forHTTPHeaderField:@"mimeType"];
//                            [request setValue:encodingType forHTTPHeaderField:@"encodingType"];
//                            
//                            [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
//                        });
//                    }];
                    // 直接将request加入queue
                    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
                    // 将版本信息、mime类型、编码类型写进request的头里，以便后续使用
                    [request setValue:versionCode forHTTPHeaderField:@"versionCode"];
                    [request setValue:mimeType forHTTPHeaderField:@"mimeType"];
                    [request setValue:encodingType forHTTPHeaderField:@"encodingType"];
                    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                        
                    }];
                    
                    
                }
            }
        }
    } onRequestFailed:^(NSString *responseCode, NSString *responseInfo) {
        
    }];
}


// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
- (void)applicationWillResignActive:(UIApplication *)application {
    // Webview进入后台后增加毛玻璃模糊效果
    if ([self.window.rootViewController isKindOfClass:[CustomWebViewController class]]) {
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        imageView.tag = 71111;
        imageView.image = [[MyUtils screenShotFromView:self.window.rootViewController.view] imgWithBlur];  // 默认配置即可
        [[[UIApplication sharedApplication] keyWindow] addSubview:imageView];
    }
    // 标记app为非激活状态
    _isAppActive = NO;
    enterBackgroundTime = [NSDate date];
}

// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
- (void)applicationDidEnterBackground:(UIApplication *)application {
//    enterBackgroundTime = [NSDate date];
        NSArray *localArray = [application scheduledLocalNotifications];
        [application cancelAllLocalNotifications];
        NSArray *Arr = [[NSArray alloc]init];
        if (localArray) {
            NSSortDescriptor *descriptor = [[NSSortDescriptor alloc]initWithKey:@"fireDate.timeIntervalSince1970" ascending:YES];
            NSArray *sortArray = [NSArray arrayWithObjects:descriptor, nil];
            Arr = [localArray sortedArrayUsingDescriptors:sortArray];
            for (int i = 0; i < Arr.count; i++) {
                
                UILocalNotification *noti = [[UILocalNotification alloc]init];
                noti = [Arr objectAtIndex:i];
                noti.applicationIconBadgeNumber = i+1;
                [application scheduleLocalNotification:noti];
                
            }
            
        }

}

// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
- (void)applicationWillEnterForeground:(UIApplication *)application {
    
    // 手势解锁相关
    if ([FingerWorkManager isFingerWorkExisted]) {
        NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:enterBackgroundTime];
        if (interval > lockInterval) {
//            [self showLockViewController:LockViewTypeCheck onSucceeded:nil onFailed:nil];
        }
    }
        // 去除app图标上的小红点
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
}

// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
- (void)applicationDidBecomeActive:(UIApplication *)application {
    // 移除Webview毛玻璃模糊效果
    NSLog(@"notiAlertBody = %@",localNotification.alertBody);
    if ([self.window.rootViewController isKindOfClass:[CustomWebViewController class]]) {
        NSArray *subViews = [[UIApplication sharedApplication] keyWindow].subviews;
        for (id object in subViews) {
            if ([[object class] isSubclassOfClass:[UIImageView class]]) {
                UIImageView *imageView = (UIImageView *)object;
                if(imageView.tag == 71111) {  // 动画移除模糊层
                    [UIView animateWithDuration:0.2 animations:^{
                        imageView.alpha = 0;
                        [imageView removeFromSuperview];
                    }];
                }
            }
        }
    }
    // 若app是从未激活状态返回且超过五分钟，弹出手势界面
    if (!_isAppActive) {
        _isAppActive = YES;
        if ([FingerWorkManager isFingerWorkExisted]) {
            NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:enterBackgroundTime];
            if (interval > lockInterval) {
//               [self showLockViewController:LockViewTypeCheck onSucceeded:nil onFailed:nil];
                [self showLockViewController:LockViewTypeCheck onSucceeded:^{
                    if (localNotification.alertBody != nil ) {
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                                        message:localNotification.alertBody
                                                                       delegate:self
                                                              cancelButtonTitle:@"取消"
                                                              otherButtonTitles:@"查看",@"停止",nil];
                        
                        
                        [alert show];
                        localNotification.alertBody = nil;
                        NSLog(@"localNotification.alertBody(E) = %@",localNotification.alertBody);
                    }

                } onFailed:nil];
                
                
            }else {
                NSLog(@"localNotification.alertBody(F) = %@",localNotification.alertBody);
                if (localNotification.alertBody != nil ) {
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                                    message:localNotification.alertBody
                                                                   delegate:self
                                                          cancelButtonTitle:@"取消"
                                                          otherButtonTitles:@"查看",@"停止",nil];
                    
                    
                    [alert show];
                    localNotification.alertBody = nil;
                    NSLog(@"localNotification.alertBody(E) = %@",localNotification.alertBody);
                }
             
            }
        }
    }

    
}

// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
- (void)applicationWillTerminate:(UIApplication *)application {
    CRYPTO_cleanup_all_ex_data();  // crypto.h中抄的注释:Release all "exself.data" state to prevent memory leaks.
//    [[NSURLCache sharedURLCache] removeAllCachedResponses];  // 目前版本禁止缓存
}
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
//    [[CIBURLCache sharedURLCache] removeAllCachedResponses];
}

+ (AppDelegate *)delegate {
    return (AppDelegate *)[[UIApplication sharedApplication] delegate];
}

#pragma mark - 弹出手势解锁密码输入框
/*
 typedef enum {
     LockViewTypeCheck,  // 检查手势密码
     LockViewTypeCreate, // 创建手势密码
     LockViewTypeModify, // 修改
     LockViewTypeClean,  // 清除
 } LockViewType;
 */
- (void)showLockViewController:(LockViewType)type onSucceeded:(void(^)())onSucceededBlock onFailed:(void(^)())onFailedBlock
{
    
    if (self.lockVc == nil)
    {
        self.lockVc = [[LockViewController alloc] initWithType:type user:[AppInfoManager getUserName]];
        
        // 验证手势成功时的操作
        self.lockVc.succeededBlock = ^()
        {
            [AppDelegate delegate].lockVc = nil;
            
            if (onSucceededBlock) {
                onSucceededBlock();
                
            }
            
        };
        
        // 验证手势失败时的操作
        self.lockVc.failBlock = ^()
        {
            [AppDelegate delegate].lockVc = nil;
            
            if (onFailedBlock)
            {
                onFailedBlock();
            }
            
            LoginViewController *loginVC = [[LoginViewController alloc] init];
            loginVC.dismissWhenSucceeded = NO;
            UIViewController *vcPointer = loginVC;
            loginVC.loginSucceededBlock = ^()
            {
                
                // 登录成功后重新设置手势
                [AppDelegate delegate].isLogin = YES;
                [vcPointer dismissViewControllerAnimated:YES completion:^
                {
                    [[AppDelegate delegate] showLockViewController:LockViewTypeCreate onSucceeded:nil onFailed:nil];
                }];
            };

            [[AppDelegate delegate].window.rootViewController presentViewController:loginVC animated:YES completion:nil];
            
        };
        
        
        self.lockVc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        [self.window.rootViewController presentViewController:self.lockVc animated:YES completion:nil];
    }
}

#pragma mark - 向应用服务端注册推送服务
- (void)registerPushServiceToAppServerWithDeviceToken:(NSString *)deviceToken {
    // 如果本地密钥存在，则调用应用服务端注册接口，上报设备标识
    if ([DeviceKeyManager isDeviceKeyExisted]) {
        NSString *pushAppId = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"MPushAppID"];
        NSString *pushAppKey = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"MPushAppKey"];
        NSString *appId = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
        NSString *deviceId = [AppInfoManager getDeviceID];
        NSString *notesId = [NSString stringWithFormat:@"%@", [AppInfoManager getUserName]];
        id paramDic = @{@"pushAppId":pushAppId,
                        @"pushAppKey":pushAppKey,
                        @"pushToken":deviceToken,
                        @"notesId":notesId,
                        @"appId":appId,
                        @"sysType":@"ios",
                        @"deviceId":deviceId};
        [CIBRequestOperationManager invokeAPI:@"pushreg" byMethod:@"POST" withParameters:paramDic onRequestSucceeded:^(NSString *responseCode, NSString *responseInfo) {
            NSDictionary *responseDic = (NSDictionary *)responseInfo;
            NSString *resultCode = [responseDic objectForKey:@"resultCode"];
            if ([resultCode isEqualToString:@"0"]) {
                CIBLog(@"注册服务调用成功");
                // 此设备标识已经在应用服务端注册成功
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:deviceToken];
                // 标记一下此时设备已经激活，可以打开WebApp
                [AppDelegate delegate].isActive = YES;
            }
            else {
                CIBLog(@"注册服务调用失败");
                // 此设备标识在应用服务端注册失败
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:deviceToken];
            }
            
        } onRequestFailed:^(NSString *responseCode, NSString *responseInfo) {
            CIBLog(@"注册服务调用失败");
            // 此设备标识在应用服务端注册失败
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:deviceToken];
            if ([responseCode isEqualToString:@"11"]) {
                // 标记一下此时设备未激活，不能打开WebApp
                [AppDelegate delegate].isActive = NO;
            }
        }];
    }
}
#pragma mark - 本地通知的处理逻辑



-(void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    localNotification = notification;

    NSLog(@"notification.alertBody = %@",notification.alertBody);
    application.applicationIconBadgeNumber = 0;
    
}


-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) {
        //添加事件
        

    }
    if (buttonIndex == 1)
    {
        //添加事件
        

        
    }else if (buttonIndex == 2)
    {
        //添加事件

        
    }
   
}



#pragma mark - 推送相关的回调方法
/**
 *  接收到推送消息的回调函数
 *
 *  @param title     消息的标题
 *  @param content   消息的正文
 *  @param extention 消息的附带信息（用于标记具体的WebApp等）
 *
 *  @return BOOL 当返回YES时，仅处理至当前事件处，后续事件将不再执行，当返回NO时，按照事件链继续执行，直至返回YES或者所有事件执行完。
 */
- (BOOL)onMessage:(NSString *)title content:(NSString *)content extention:(NSDictionary *)extention {
    CIBLog(@"title : %@ \n content : %@ \n extention : %@ \n",title,content,[extention description]);

    // 判断此消息是应用门户自身的消息还是给WebApp的消息
    BOOL isWebAppNoti = [extention objectForKey:@"isWebAppNoti"];
    if (isWebAppNoti) {
        // 获取推送来自的WebApp名称
        NSString *notiAppName = [extention objectForKey:@"appName"];
        // 修改数据库中相应WebApp的通知相关字段
        CoreDataManager *cdManager = [[CoreDataManager alloc] init];
//        NSArray *appList = [cdManager getAppList];
        NSArray *appList = [[AppDelegate delegate] getAppProductList];
        for (AppProduct *app in appList) {
            if ([notiAppName isEqualToString:app.appName]) {
                int notiNo = [app.notiNo intValue];
                notiNo ++;
                app.notiNo = [NSNumber numberWithInt:notiNo];
                [cdManager updateAppInfo:app];
                // 更新明文临时变量为空 需要重新从数据库中读取
                [[AppDelegate delegate] setAppProductList:appList];
                break;
            }
        }
        // 如果当前显示页面是主页的话，刷新一下主页上WebApp的图标
        if ([self.window.rootViewController isKindOfClass:[CIBSideViewController class]]) {
            CIBSideViewController *sideVC = (CIBSideViewController *)self.window.rootViewController;
            if ([sideVC.contentViewController isKindOfClass:[MainViewController class]]) {
                MainViewController *mainVC = (MainViewController *)sideVC.contentViewController;
                if ([mainVC respondsToSelector:@selector(reloadFavorCollectionView)]) {
                    [mainVC performSelector:@selector(reloadFavorCollectionView) withObject:nil];
                }
            }
            
        }
    }
    else {
        // 如果是应用门户本身的推送消息，做相应处理
    }

    return YES;
}

-(void)didReciveDeviceToken:(NSString *)deviceToken {
    CIBLog(@"deviceToken --- String : %@",deviceToken);
//    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:deviceToken];
    // 获取之前存储的设备标识
    NSString *formerDeviceToken = [[NSUserDefaults standardUserDefaults] objectForKey:kKeyOfDeviceToken];

    // 如果从未有过设备标识，或者此次获得的设备标识与之前本次存储的不一致，则将此新的设备标识存储在本地
    if (!formerDeviceToken || ![formerDeviceToken isEqualToString:deviceToken]) {
        [[NSUserDefaults standardUserDefaults] setObject:deviceToken forKey:kKeyOfDeviceToken];
        [self registerPushServiceToAppServerWithDeviceToken:deviceToken];
    }
    // 两次返回的设备标识一致
    
    else {
        // 此设备标识在应用服务端未能注册成功
        if (![[NSUserDefaults standardUserDefaults] boolForKey:deviceToken]) {
            [self registerPushServiceToAppServerWithDeviceToken:deviceToken];
        }
    }
}

- (NSArray *)getAppProductList {
    if (!_plainAppProductList) {
        _plainAppProductList = [[[CoreDataManager alloc] init] getAppList];
    }
    return _plainAppProductList;
}

- (void)setAppProductList:(NSArray *)appProductList {
    _plainAppProductList = appProductList;
}

- (void)cacheLocalResourceFiles {
    // 将本地包中的js、css等资源文件读取到缓存中
    NSMutableArray *resourceInfoList = [[NSMutableArray alloc] init];
    
    id resourceFileInfoArray = [MyUtils propertyOfResource:@"ResourceFile" forKey:@"ResourceFileInfo"];
    if ([resourceFileInfoArray isKindOfClass:[NSArray class]]) {
        for (NSDictionary *infoDic in resourceFileInfoArray) {
            NSString *url = [infoDic objectForKey:@"url"];
            NSString *fileName = [infoDic objectForKey:@"fileName"];
            NSString *versionCode = [infoDic objectForKey:@"versionCode"];
            NSString *mimeType = [infoDic objectForKey:@"mimeType"];
            NSString *encodingType = [infoDic objectForKey:@"encodingType"];
            CIBResourceInfo *resourceInfo = [[CIBResourceInfo alloc] initWithUrlAddress:url fileName:fileName versionCode:versionCode mimeType:mimeType encodingType:encodingType];
            [resourceInfoList addObject:resourceInfo];
        }
    }
    CIBURLCache *cache = (CIBURLCache *)[CIBURLCache sharedURLCache];
    for (CIBResourceInfo *info in resourceInfoList) {
        NSString *localFilePath = [[NSBundle mainBundle] pathForResource:[info fileName] ofType:nil];
        if ([Function isFileExistedAtPath:localFilePath]) {
            [cache readLocalFileResourceToCache:info];
        }
    }
}

@end
