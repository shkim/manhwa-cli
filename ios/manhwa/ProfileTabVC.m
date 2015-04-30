//
//  ProfileTabVC.m
//  manhwa
//
//  Created by shkim on 10/26/14.
//  Copyright (c) 2014 shkim. All rights reserved.
//

#import "ProfileTabVC.h"
#import "AppDelegate.h"
#import "MBProgressHUD.h"

static NSString* const KEY_IgnoreAppVer = @"IgAV";

@interface ProfileTabVC () <FBLoginViewDelegate>
{
	MBProgressHUD* m_hud;
	UIAlertView* m_alertInetFail;
	UIAlertView* m_alertForceUpdate;
	UIAlertView* m_alertNewVerAvail;
	NSString* m_newAppVersion;
	
	NSString* m_objectId;
	NSString* m_email;
	NSString* m_name;
	NSString* m_profileUrl;
}

@property (strong, nonatomic) IBOutlet FBProfilePictureView *profilePic;
@property (weak, nonatomic) IBOutlet UILabel *lbFirstName;
@property (strong, nonatomic) id<FBGraphUser> loggedInUser;

@end

@implementation ProfileTabVC

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.

	self.title = GetLocalizedString(@"tab_login");
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)startVersionCheck
{
	m_hud = [GetAppDelegate() createHUD];
	m_hud.labelText = GetLocalizedString(@"wait_verchk");
	[m_hud show:YES];
	
	[GetApiService() requestVersionInfo:self];
}

- (void)addLoginView
{
    FBLoginView *loginView = [[FBLoginView alloc] init];
	loginView.readPermissions = @[@"email", @"public_profile"];
	loginView.center = self.view.center;
	loginView.delegate = self;

	[self.view addSubview:loginView];
}

- (BOOL)onApi:(int)jobId failedWithErrorCode:(NSString*)errCode andMessage:(NSString*)errMsg
{
	if (jobId == JOBID_LOGIN_FACEBOOK)
	{
		if ([errCode isEqualToString:@"NO_USER"])
		{
			NSTRACE(@"Try register...");
			[GetApiService() requestRegisterUser:m_name withEmail:m_email andFbObjId:m_objectId andProfileUrl:m_profileUrl delegate:self];
			return YES;
		}
	}
	
	[m_hud hide:YES];
	m_hud = nil;
	
	if (jobId == JOBID_VERSION_INFO)
	{
		m_alertInetFail = [[UIAlertView alloc]
			initWithTitle:GetLocalizedString(@"a_nosvr")
			message:GetLocalizedString(@"a_uselater")
			delegate:self
			cancelButtonTitle:GetLocalizedString(@"ok")
			otherButtonTitles:nil];
		[m_alertInetFail show];
		return YES;
	}
	
	return NO;
}

- (void)onApi:(int)jobId result:(id)_param
{
	[m_hud hide:YES];
	m_hud = nil;
	
	if (jobId == JOBID_VERSION_INFO)
	{
		API_VersionResult* res = (API_VersionResult*)_param;
		
		if ([self shouldIUpdateApp:res.appVersion])
		{
			m_alertForceUpdate = [[UIAlertView alloc]
				initWithTitle:GetLocalizedString(@"a_needupd")
				message:GetLocalizedString(@"a_gostore")
				delegate:self
				cancelButtonTitle:GetLocalizedString(@"ok")
				otherButtonTitles:nil];
			[m_alertForceUpdate show];
		}
		else
		{
			[self addLoginView];
		}
	}
	else if (jobId == JOBID_LOGIN_FACEBOOK || jobId == JOBID_REGISTER_FBUSER)
	{
		API_LoginResult* res = (API_LoginResult*)_param;
		NSTRACE(@"LoginRes: %@, level=%d", res.sessKey, res.level);
		
		if (res.sessKey != nil)
		{
			self.lbFirstName.text = m_name;
			self.profilePic.profileID = m_objectId;
			[GetAppDelegate() onUserLoggedIn];
		}
	}
}

- (BOOL)shouldIUpdateApp:(NSString*)latestVersion
{
	NSString* myVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];

	NSTRACE(@"myVer:%@, appVer:%@", myVersion, latestVersion);
	if ([myVersion isEqualToString:latestVersion])
		return NO;

	NSArray* my = [myVersion componentsSeparatedByString:@"."];
	NSArray* svr = [latestVersion componentsSeparatedByString:@"."];
	if (svr.count < 2)
	{
		// invalid server response, give up
		return NO;
	}

	int dMajor = [[svr objectAtIndex:0] intValue] - [[my objectAtIndex:0] intValue];
	int dMinor = [[svr objectAtIndex:1] intValue] - [[my objectAtIndex:1] intValue];
	if (dMajor > 0 || dMinor > 0)
	{
		// goto appstore!
		return YES;
	}

	if ([myVersion compare:latestVersion options:NSNumericSearch] == NSOrderedAscending)
	{
		NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
		NSString* ignoreVer = [ud stringForKey:KEY_IgnoreAppVer];
		if (![latestVersion isEqualToString:ignoreVer])
		{
			m_newAppVersion = latestVersion;
			m_alertNewVerAvail = [[UIAlertView alloc]
				initWithTitle:GetLocalizedString(@"a_newver")
				message:[NSString stringWithFormat:@"현재 버전: %@\n새 버전: %@", myVersion, latestVersion]
				delegate:self
				cancelButtonTitle:GetLocalizedString(@"ignore")
				otherButtonTitles:GetLocalizedString(@"gostore"), nil];
			[m_alertNewVerAvail performSelector:@selector(show) withObject:nil afterDelay:0.1];
		}
	}
	
	return NO;
}

+ (void)gotoAppStore
{
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:
		@"itms-apps://itunes.apple.com/us/app/seulligmanhwabang/id938609191"]];
}

- (void)dieLater
{
	exit(0);
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView == m_alertInetFail)
	{
		[self performSelector:@selector(dieLater) withObject:nil afterDelay:1];
	}
	else if (alertView == m_alertForceUpdate)
	{
		[ProfileTabVC gotoAppStore];
		[self performSelector:@selector(dieLater) withObject:nil afterDelay:1];
	}
	else if (alertView == m_alertNewVerAvail)
	{
		m_alertNewVerAvail = nil;
		
		if (buttonIndex == 0)
		{
			NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
			[ud setObject:m_newAppVersion forKey:KEY_IgnoreAppVer];
			[ud synchronize];
		}
		else if (buttonIndex == 1)
		{
			[ProfileTabVC gotoAppStore];
		}
	}
}

#pragma mark - FBLoginViewDelegate

- (void)loginViewShowingLoggedInUser:(FBLoginView *)loginView
{
	NSTRACE(@"loginViewShowingLoggedInUser called");
	//[GetAppDelegate() onUserLoggedIn];
/*
//	[[FBRequest requestForMe] startWithCompletionHandler:^(FBRequestConnection *connection, NSDictionary<FBGraphUser> *user, NSError *error) {
	[FBRequestConnection startForMeWithCompletionHandler:^(FBRequestConnection *connection, id<FBGraphUser> fbUserData, NSError *error) {
		NSString *name = nil;
		NSString *email = nil;
		if (!error)
		{
			name = fbUserData.name;
			email = [fbUserData objectForKey:@"email"];
			if (name != nil && email != nil)
			{
			NSString* token = [FBSession activeSession].accessTokenData.accessToken;
			NSTRACE(@"FBR, email=%@, token=%@, name=%@", email, token, name);
			return;
			}
		}

		NSTRACE(@"Facebook login not available (name=%@, email=%@): %@", name, email, error);
	}];
*/
}

- (void)loginViewFetchedUserInfo:(FBLoginView *)loginView user:(id<FBGraphUser>)user
{
    // here we use helper properties of FBGraphUser to dot-through to first_name and
    // id properties of the json response from the server; alternatively we could use
    // NSDictionary methods such as objectForKey to get values from the my json object
	//self.lbFirstName.text = [NSString stringWithFormat:@"Hello %@!", user.first_name];
//	self.lbFirstName.text = user.name;
	NSTRACE(@"FB PROP: %@, %@, %@, %@ %@", user.username, user.link, user.name, user.objectID, [user objectForKey:@"email"]);
    // setting the profileID property of the FBProfilePictureView instance
    // causes the control to fetch and display the profile picture for the user
//    self.profilePic.profileID = user.objectID;
    self.loggedInUser = user;
	
	if (m_email == nil)
	{
		m_name = user.name;
		m_email = [user objectForKey:@"email"];
		m_objectId = user.objectID;
		m_profileUrl = user.link;
		
		NSTRACE(@"Try login...");
		[GetApiService() requestLoginEmail:m_email withFbObjId:m_objectId delegate:self];
	}
}

- (void)loginViewShowingLoggedOutUser:(FBLoginView *)loginView
{
/*
    // test to see if we can use the share dialog built into the Facebook application
    FBLinkShareParams *p = [[FBLinkShareParams alloc] init];
    p.link = [NSURL URLWithString:@"http://developers.facebook.com/ios"];
    BOOL canShareFB = [FBDialogs canPresentShareDialogWithParams:p];
    BOOL canShareiOS6 = [FBDialogs canPresentOSIntegratedShareDialogWithSession:nil];
    BOOL canShareFBPhoto = [FBDialogs canPresentShareDialogWithPhotos];
	NSTRACE(@"loginViewShowingLoggedOutUser %d,%d,%d", canShareFB, canShareiOS6, canShareFBPhoto);
	
//    self.buttonPostStatus.enabled = canShareFB || canShareiOS6;
//    self.buttonPostPhoto.enabled = canShareFBPhoto;
//    self.buttonPickFriends.enabled = NO;
//    self.buttonPickPlace.enabled = NO;

    // "Post Status" available when logged on and potentially when logged off.  Differentiate in the label.
//    [self.buttonPostStatus setTitle:@"Post Status Update (Logged Off)" forState:self.buttonPostStatus.state];
*/

    self.profilePic.profileID = nil;
    self.lbFirstName.text = nil;
    self.loggedInUser = nil;

	m_objectId = nil;
	m_email = nil;
	m_name = nil;
	m_profileUrl = nil;
	
	[GetAppDelegate() onUserLoggedOut];
}

- (void)loginView:(FBLoginView *)loginView handleError:(NSError *)error
{
	// see https://developers.facebook.com/docs/reference/api/errors/ for general guidance on error handling for Facebook API
	// our policy here is to let the login view handle errors, but to log the results
	NSTRACE(@"FBLoginView encountered an error=%@", error);
}

- (void)forceLogout
{
	[[FBSession activeSession]closeAndClearTokenInformation];
}

@end
