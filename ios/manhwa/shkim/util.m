//
//  util.m
//  sleek (iOS7 Version)
//
//  Created by shkim on 5/17/13.
//  Copyright (c) 2013 shkim. All rights reserved.
//

#import "util.h"
#import "AppDelegate.h"
#import "MBProgressHUD.h"

void alertSimpleMessage(NSString* msg)
{
	UIAlertView* alert = [[UIAlertView alloc] initWithTitle:msg
		message:@"" delegate:nil cancelButtonTitle:GetLocalizedString(@"ok") otherButtonTitles:nil];
	[alert show];
}

void alertSimpleMessageWithTitle(NSString* msg, NSString* title)
{
	UIAlertView* alert = [[UIAlertView alloc] initWithTitle:title
		message:msg delegate:nil
		cancelButtonTitle:GetLocalizedString(@"ok")
		otherButtonTitles:nil];
	[alert show];
}


BOOL isIPhone(void)
{
	NSString *deviceType = [UIDevice currentDevice].model;
	return ([deviceType isEqualToString:@"iPhone"]);
}

/*
void dialPhoneNow(NSString* phoneNum)
{
	if (!isIPhone())
	{
		alertSimpleMessage(GetLocalizedString(@"a_nodial"));
		return;
	}

	NSString* telstr = [NSString stringWithFormat:@"tel:%@", phoneNum];
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:telstr]];
}

@interface DialConfirmBox : NSObject <UIActionSheetDelegate>
{
	UIActionSheet* sheet;
	NSString* phoneNum;
}

- (void)show:(NSString*)num;

@end

@implementation DialConfirmBox

- (void)show:(NSString*)num
{
	phoneNum = [num retain];
	sheet = [[UIActionSheet alloc] initWithTitle:GetLocalizedString(@"q_pcall")
		delegate:self
		cancelButtonTitle:GetLocalizedString(@"cancel")
		destructiveButtonTitle:[NSString stringWithFormat:@"%@ (%@)", GetLocalizedString(@"call"), num]
		otherButtonTitles:nil];

	[sheet showInView:GetMainWindow()];		
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == 0)
	{
		dialPhoneNow(phoneNum);		
	}
	
//	[self release];
}

@end

void confirmDialPhone(NSString* num)
{
	if (!isIPhone())
	{
		alertSimpleMessage(GetLocalizedString(@"a_nodial"));
		return;
	}

	DialConfirmBox* box = [[DialConfirmBox alloc] init];
	[box show:num];
	[box autorelease];
}
*/

///////////////////////////////////////////////////////////////////////////////

NSComparisonResult compareInt(int a, int b)
{
	if (a < b)
		return NSOrderedAscending;
	
	if (a > b)
		return NSOrderedDescending;

	return NSOrderedSame;
}

NSString* mergeWriterArtist(NSString* writer, NSString* artist)
{
	if (writer.length == 0)
		return artist;
		
	if (artist.length == 0)
		return writer;

	if ([artist isEqualToString:writer])
		return artist;
		
	return [NSString stringWithFormat:@"%@•%@", writer, artist];
}

NSString* dateToString(NSDate* regdate)
{
	NSTimeInterval secs = [[NSDate date] timeIntervalSinceDate:regdate];
	int nSecs = (int) secs;

	int nDays = nSecs / (24*60*60);
	nSecs -= nDays * 24*60*60;
	
	int nHours = nSecs / (60*60);
	nSecs -= nHours * 60*60;
	
	int nMins = nSecs / 60;
	nSecs -= nMins * 60;
	
	NSString* str;
	if (nDays > 3)
	{
		NSDateComponents *components = [[NSCalendar currentCalendar]
			components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear fromDate:regdate];
		str = [NSString stringWithFormat:@"%d년 %d월 %d일",
			(int)[components year], (int)[components month], (int)[components day]];
	}
	else if (nDays > 0)
	{
		str = [NSString stringWithFormat:@"%d일 %d시간 전", nDays, nHours];
	}
	else if (nHours > 0)
	{
		str = [NSString stringWithFormat:@"%d시간 전", nHours];
	}
	else if (nMins > 0)
	{
		str = [NSString stringWithFormat:@"%d분 전", nMins];
	}
	else
	{
		str = @"방금";
	}

	return str;
}

void setDefaultButtonBorder(UIButton* btn)
{
	UIImage* imgEditP = [[UIImage imageNamed:@"btn_edit_p9.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(2, 2, 2, 2)];
	UIImage* imgOkN = [[UIImage imageNamed:@"btn_ok_n9.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(2, 2, 2, 2)];

	[btn setBackgroundImage:imgOkN forState:UIControlStateNormal];
	[btn setBackgroundImage:imgEditP forState:UIControlStateHighlighted];
}

void showToast(UIViewController*vc, NSString* msg)
{
	MBProgressHUD* toast = [[MBProgressHUD alloc] initWithWindow:GetAppDelegate().window];
	[vc.view addSubview:toast];
	toast.removeFromSuperViewOnHide = YES;
	toast.mode = MBProgressHUDModeText;
	toast.userInteractionEnabled = NO;
	toast.margin = 10.f;
	toast.yOffset = vc.view.frame.size.height * 0.5f - 50;

	toast.labelText = msg;
	[toast show:YES];
	[toast hide:YES afterDelay:3];
}

void setSkipBackupAttributeToFile(NSString* filepath)
{
	NSURL* url = [NSURL fileURLWithPath:filepath];
	[url setResourceValue:[NSNumber numberWithBool:YES]
		forKey:NSURLIsExcludedFromBackupKey
		error:nil];
}

#if 0

#pragma mark --

@implementation PortraitNavigationController

// iOS6+
- (BOOL)shouldAutorotate
{
	return NO;
}

- (NSUInteger)supportedInterfaceOrientations
{
	return (UIInterfaceOrientationPortrait | UIInterfaceOrientationPortraitUpsideDown);
}

// iOS5
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return (interfaceOrientation == UIInterfaceOrientationPortrait || interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown);
}

@end




#include <CoreFoundation/CoreFoundation.h>
#include <CommonCrypto/CommonDigest.h>

#define MD5_CHUNK_SIZE	4096

NSString* MD5ofFile(NSString* filePath)
{
	NSInputStream* ins = [NSInputStream inputStreamWithFileAtPath:filePath];
	if (ins == nil)
	{
		NSTRACE(@"MD5 file open failed: %@", filePath);
		return nil;
	}

	NSString* ret;
	Byte* buff = malloc(MD5_CHUNK_SIZE);
	if (buff)
	{
		[ins open];
				
		CC_MD5_CTX hashObject;
		CC_MD5_Init(&hashObject);

		for (;;)
		{
			int cbRead = [ins read:buff maxLength:MD5_CHUNK_SIZE];
			if (cbRead <= 0)
				break;
				
			CC_MD5_Update(&hashObject, buff, cbRead);
		}
		
		free(buff);
		[ins close];
		
		Byte digest[CC_MD5_DIGEST_LENGTH];
		CC_MD5_Final(digest, &hashObject);
		ret = toHexString(digest, CC_MD5_DIGEST_LENGTH);
	}
	else
	{
		ASSERT(!"MD5: Out of memory");
		ret = nil;
	}
	
	return ret;
}

#endif
