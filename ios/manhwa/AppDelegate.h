//
//  AppDelegate.h
//  manhwa
//
//  Created by shkim on 10/26/14.
//  Copyright (c) 2014 shkim. All rights reserved.
//

#import <UIKit/UIKit.h>

#ifdef _DEBUG
#define DEV_QUICK
#endif

@class HttpMan;
@class ApiService;
@class MBProgressHUD;
@class RecentListVC;
@class SliderFrameVC;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
//@property (nonatomic, strong, setter = setCurrentSession:) SleekSession* currentSession;
@property (nonatomic, readonly) BOOL isIpad;
@property (nonatomic, readonly) BOOL isIOS7;
@property (nonatomic, readonly) BOOL isIOS5;

@property (nonatomic, readonly) int pref_PageFx;

- (void)setPref_PageFx:(int)pageFx;

- (HttpMan*)getHttpManager;
- (ApiService*)getApiService;
- (RecentListVC*)getRecentList;

- (void)setCurrentViewer:(SliderFrameVC*)vc;

- (MBProgressHUD*)createHUD;
- (MBProgressHUD*)createToast;

- (void)onUserLoggedIn;
- (void)onUserLoggedOut;
- (void)onSessionInvalidated;

@end
