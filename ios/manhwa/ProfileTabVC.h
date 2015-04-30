//
//  ProfileTabVC.h
//  manhwa
//
//  Created by shkim on 10/26/14.
//  Copyright (c) 2014 shkim. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <FacebookSDK/FacebookSDK.h>

#import "ApiService.h"

@interface ProfileTabVC : UIViewController <ApiResultDelegate>

- (void)startVersionCheck;
- (void)forceLogout;

@end
