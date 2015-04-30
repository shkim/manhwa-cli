//
//  util.h
//  SleekClient
//
//  Created by shkim on 5/17/13.
//  Copyright (c) 2013 shkim. All rights reserved.
//

#import <Foundation/Foundation.h>

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]
#define UIColorFromRGBA(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:((float)((rgbValue & 0xFF000000) >> 24))/255.0]

void alertSimpleMessage(NSString* msg);
void alertSimpleMessageWithTitle(NSString* msg, NSString* title);

BOOL isIPhone(void);
void confirmDialPhone(NSString* num);
void dialPhoneNow(NSString* phoneNum);

NSComparisonResult compareInt(int a, int b);

NSString* mergeWriterArtist(NSString* writer, NSString* artist);
NSString* dateToString(NSDate* now);
//NSString* MD5ofFile(NSString* filePath);

void setSkipBackupAttributeToFile(NSString* filepath);
void setDefaultButtonBorder(UIButton* btn);

void showToast(UIViewController*vc, NSString* msg);

@interface PortraitNavigationController : UINavigationController
@end

