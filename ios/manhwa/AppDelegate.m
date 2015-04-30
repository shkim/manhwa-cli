//
//  AppDelegate.m
//  manhwa
//
//  Created by shkim on 10/26/14.
//  Copyright (c) 2014 shkim. All rights reserved.
//

#import "AppDelegate.h"
#import "HttpMan.h"
#import "ApiService.h"
#import "MBProgressHUD.h"

#import "ProfileTabVC.h"
#import "DirListVC.h"
#import "RecentListVC.h"
#import "SettingsVC.h"
#import "SliderFrameVC.h"

#import <FacebookSDK/FacebookSDK.h>

static NSString* const KEY_PageFx = @"PgFX";

@interface AppDelegate ()
{
	HttpMan* m_httpMan;
	ApiService* m_apiService;
	RecentListVC* m_recentList;
	__weak SliderFrameVC* m_currentViewer;
	
	ProfileTabVC* m_profileTab;
	UINavigationController* m_dirListTab;
	UINavigationController* m_recentListTab;
	UINavigationController* m_settingsTab;
	
	UITabBarController* m_tabBarCtlr;
	UIAlertView* m_alertInvalidSession;
}

@end

@implementation AppDelegate

@synthesize isIpad = m_isIpad;
@synthesize isIOS7 = m_isIOS7;
@synthesize isIOS5 = m_isIOS5;
@synthesize pref_PageFx = m_prefPageFX;

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	m_isIpad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
	m_isIOS7 = SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0");
	m_isIOS5 = [[[UIDevice currentDevice] systemVersion] hasPrefix:@"5."];
	
	m_httpMan = [[HttpMan alloc] init];
	m_apiService = [[ApiService alloc] init];
	m_recentList = [[RecentListVC alloc] init];

	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	m_prefPageFX = (int)[ud integerForKey:KEY_PageFx];
	[m_recentList loadRecentList:ud];
		
	// Override point for customization after application launch.
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	
    // If you have not added the -ObjC linker flag, you may need to uncomment the following line because
    // Nib files require the type to have been loaded before they can do the wireup successfully.
    // http://stackoverflow.com/questions/1725881/unknown-class-myclass-in-interface-builder-file-error-at-runtime
    [FBProfilePictureView class];
	
	m_profileTab = [[ProfileTabVC alloc] initWithNibName:@"ProfileTab_iPad" bundle:nil];
	m_profileTab.tabBarItem = [[UITabBarItem alloc] initWithTitle:GetLocalizedString(@"tab_profile")
		image:[UIImage imageNamed:@"tab_profile.png"] tag:1];

	SettingsVC* settingsVC = [[SettingsVC alloc] init];
	m_settingsTab = [[UINavigationController alloc] initWithRootViewController:settingsVC];
	m_settingsTab.tabBarItem = [[UITabBarItem alloc] initWithTitle:GetLocalizedString(@"tab_config")
		image:[UIImage imageNamed:@"tab_config.png"] tag:4];

	m_tabBarCtlr = [[UITabBarController alloc] init];
	m_tabBarCtlr.viewControllers = [NSArray arrayWithObjects:m_profileTab, m_settingsTab, nil];

	self.window.rootViewController = m_tabBarCtlr;

	[self.window makeKeyAndVisible];
	
	[m_profileTab startVersionCheck];
	
	return YES;
}

// FBSample logic
// If we have a valid session at the time of openURL call, we handle Facebook transitions
// by passing the url argument to handleOpenURL; see the "Just Login" sample application for
// a more detailed discussion of handleOpenURL
- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    // attempt to extract a token from the url
    return [FBAppCall handleOpenURL:url sourceApplication:sourceApplication fallbackHandler:^(FBAppCall *call) {
		NSTRACE(@"In fallback handler");
	}];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
	// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
	// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
	
	if (m_currentViewer != nil)
	{
		[m_currentViewer logRecentState];
	}
	
	NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
	[m_recentList saveRecentList:ud];
	[ud synchronize];
	
#ifdef DEBUG
	exit(0);
#endif
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
	// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	[FBAppEvents activateApp];
	
	// We need to properly handle activation of the application with regards to SSO
	//  (e.g., returning from iOS 6.0 authorization dialog or from fast app switching).
	[FBAppCall handleDidBecomeActive];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.

    // if the app is going away, we close the session object
    [FBSession.activeSession close];
}


- (void)setPref_PageFx:(int)pageFx
{
	m_prefPageFX = pageFx;
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	[ud setInteger:pageFx forKey:KEY_PageFx];
	[ud synchronize];
}

- (MBProgressHUD*)createHUD
{
	MBProgressHUD* hud = [[MBProgressHUD alloc] initWithView:m_tabBarCtlr.view];
	[m_tabBarCtlr.view addSubview:hud];
	hud.removeFromSuperViewOnHide = YES;
	return hud;
}

- (MBProgressHUD*)createToast
{
	MBProgressHUD* toast = [[MBProgressHUD alloc] initWithWindow:GetAppDelegate().window];
	[m_tabBarCtlr.view addSubview:toast];
	toast.removeFromSuperViewOnHide = YES;
	toast.mode = MBProgressHUDModeText;
	toast.userInteractionEnabled = NO;
	toast.margin = 10.f;
	toast.yOffset = m_tabBarCtlr.view.frame.size.height * 0.5f - 50;

	return toast;
}

- (HttpMan*)getHttpManager
{
	return m_httpMan;
}

- (ApiService*)getApiService
{
	return m_apiService;
}

- (RecentListVC*)getRecentList
{
	return m_recentList;
}

- (void)setCurrentViewer:(SliderFrameVC*)vc
{
	m_currentViewer = vc;
}

- (void)onUserLoggedIn
{
	NSTRACE(@"APP: Log In");
	m_profileTab.title = GetLocalizedString(@"tab_profile");

	DirListVC* dirList = [[DirListVC alloc] init];
	m_dirListTab = [[UINavigationController alloc] initWithRootViewController:dirList];
	m_dirListTab.tabBarItem = [[UITabBarItem alloc] initWithTitle:GetLocalizedString(@"tab_dir")
		image:[UIImage imageNamed:@"tab_directory.png"] tag:2];

	m_recentListTab = [[UINavigationController alloc] initWithRootViewController:m_recentList];
	m_recentListTab.tabBarItem = [[UITabBarItem alloc] initWithTitle:GetLocalizedString(@"tab_recent")
		image:[UIImage imageNamed:@"tab_recent.png"] tag:3];

	m_tabBarCtlr.viewControllers = [NSArray arrayWithObjects:m_profileTab, m_dirListTab, m_recentListTab, m_settingsTab, nil];
	[m_tabBarCtlr.view setNeedsDisplay];
	
	m_tabBarCtlr.selectedIndex = [m_recentList isRecentEmpty] ? 1 : 2;
}

- (void)onUserLoggedOut
{
	NSTRACE(@"APP: Log Out");
	m_profileTab.title = GetLocalizedString(@"tab_login");
	
	m_tabBarCtlr.viewControllers = [NSArray arrayWithObjects:m_profileTab, m_settingsTab, nil];
	
	if (m_dirListTab != nil)
	{
		[m_dirListTab popToRootViewControllerAnimated:NO];
		m_dirListTab = nil;
		
		[m_recentListTab popToRootViewControllerAnimated:NO];
		m_recentListTab = nil;
	}
	
	m_tabBarCtlr.selectedIndex = 0;
}

- (void)onSessionInvalidated
{
	NSTRACE(@"App: session invalidated");
	
	m_alertInvalidSession = [[UIAlertView alloc]
		initWithTitle:GetLocalizedString(@"a_invsess")
		message:GetLocalizedString(@"a_relogin")
		delegate:self
		cancelButtonTitle:GetLocalizedString(@"ok")
		otherButtonTitles:nil];
	[m_alertInvalidSession show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView == m_alertInvalidSession)
	{
		m_alertInvalidSession = nil;
		[m_profileTab forceLogout];
	}
}

@end
