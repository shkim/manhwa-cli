//
//  SliderFrameVC.m
//  manhwa
//
//  Created by shkim on 10/29/14.
//  Copyright (c) 2014 shkim. All rights reserved.
//

#import "SliderFrameVC.h"
#import "PagedViewerVC.h"
#import "AppDelegate.h"
#import "ApiService.h"
#import "RecentListVC.h"
#import "util.h"

#import "MBProgressHUD.h"
#import "PvChildPageVC.h"

@interface SliderFrameVC () <ApiResultDelegate, UITableViewDataSource, UITableViewDelegate, UIPopoverControllerDelegate>
{
	MBProgressHUD* m_hud;
	
	__weak id<SliderFrameDelegate> m_coreDelegate;
	PagedViewerVC* m_curPvc;
	// AnotherViewerVC* m_curAnother; // which implements SliderFrameDelegate

	NSInteger m_curRequestVolumeIndex;	// index of volumes array, 0~
	
	BOOL m_wasManuallyBarHidden;
	BOOL m_isRtoL;	// TRUE => japanese book type
	float m_progressRate;	// 0~1
	
	UIAlertView* m_alertPageEnd;
	UIPopoverController* m_popoverBugReport;
	UIPopoverController* m_popoverMenu;
	NSMutableArray* m_menuItems;
}

@end

@implementation SliderFrameVC

/*
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}
*/

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
	
	m_progressRate = -1;
		
	UITapGestureRecognizer* tap1r = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
	[self.vwContainer addGestureRecognizer:tap1r];

	[self selectVolumeAtIndex:self.resumeVolumeIdx];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

	self.navigationController.navigationBarHidden = YES;
	[UIApplication sharedApplication].statusBarHidden = YES;
	//[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];

	if (!GetAppDelegate().isIOS7)
	{
		self.view.frame = [[UIScreen mainScreen] bounds];
	}
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	[self logRecentState];
	[GetAppDelegate() setCurrentViewer:nil];
	
	[UIApplication sharedApplication].statusBarHidden = NO;
	self.navigationController.navigationBarHidden = NO;
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	[self reconfigure];
	
	[GetAppDelegate() setCurrentViewer:self];
}

- (void)logRecentState
{
	if (self.titleInfo.volumes.count > 0)
	{
		RecentListVC* rec = [GetAppDelegate() getRecentList];
		[rec logRecentTitleId:self.titleInfo.titleId andName:self.titleInfo.nameKor
			atPage:[m_curPvc getCurrentPageSeq] ofVolume:(int)m_curRequestVolumeIndex];
	}
}

- (BOOL)onApi:(int)jobId failedWithErrorCode:(NSString*)errCode andMessage:(NSString*)errMsg
{
	[m_hud hide:YES];
	m_hud = nil;
	
	if ([errCode isEqualToString:@"INVALID_SESSION"])
	{
		[self.navigationController popToRootViewControllerAnimated:YES];
		[GetAppDelegate() performSelector:@selector(onSessionInvalidated) withObject:nil afterDelay:0.1];
		return YES;
	}
	
	return NO;
}

- (void)onApi:(int)jobId result:(id)_param
{
	[m_hud hide:YES];
	m_hud = nil;
	
	if (jobId == JOBID_VOLUME_INFO)
	{
		API_VolumeInfo* res = (API_VolumeInfo*)_param;
		
		API_VolumeInfo* myVol = [self.titleInfo.volumes objectAtIndex:m_curRequestVolumeIndex];
		ASSERT(myVol.volumeId == res.volumeId);
		myVol.isReverseDir = res.isReverseDir;
		myVol.isTwoPaged = res.isTwoPaged;
		myVol.pages = res.pages;

		[self setViewerVolume:myVol];
	}
}

- (void)setViewerVolume:(API_VolumeInfo*)volumeInfo
{
	if (m_curPvc != nil)
	{
		ASSERT(self.childViewControllers.count == 1);
		ASSERT(m_curPvc == [self.childViewControllers objectAtIndex:0]);
		
		if ([m_curPvc isReverseDir] != volumeInfo.isReverseDir)
		{
			// very rare case
			[m_curPvc willMoveToParentViewController:nil];
			[m_curPvc.view removeFromSuperview];
			[m_curPvc removeFromParentViewController];
			[m_curPvc didMoveToParentViewController:nil];
			m_curPvc = nil;
		}
	}
	
	if (m_curPvc == nil)
	{
		m_curPvc = [[PagedViewerVC alloc] initWithR2L:volumeInfo.isReverseDir];
		m_coreDelegate = m_curPvc;
		[self setRtoL:volumeInfo.isReverseDir];

		[self addChildViewController:m_curPvc];
		m_curPvc.view.frame = self.vwContainer.frame;
		[self.vwContainer addSubview:m_curPvc.view];
		[m_curPvc didMoveToParentViewController:self];
	}

	self.navBar.topItem.title = [NSString stringWithFormat:@"%@ (%d of %lu)", self.titleInfo.nameKor, volumeInfo.seqNum, (unsigned long)self.titleInfo.volumes.count];
	[m_curPvc updateVolumeInfo:volumeInfo];
	
	if (self.navBar.hidden)
		[self toggleTopBottomBars];

	m_wasManuallyBarHidden = NO;
	[self performSelector:@selector(autoHideBars) withObject:nil afterDelay:2.5f];
}

- (void)reconfigure
{
	// TODO: orientation update
}

- (void)selectVolumeAtIndex:(NSInteger)iVolume
{
	ASSERT(self.titleInfo.volumes.count > 0);

	API_VolumeInfo* volumeInfo = [self.titleInfo.volumes objectAtIndex:iVolume];
	if (volumeInfo.pages == nil)
	{
		m_hud = [GetAppDelegate() createHUD];
		m_hud.labelText = GetLocalizedString(@"wait_getvol");
		[m_hud show:YES];
	
		m_curRequestVolumeIndex = iVolume;
		[GetApiService() requestVolumeInfo:volumeInfo.volumeId delegate:self];
		return;
	}
	
	[self setViewerVolume:volumeInfo];
}

- (void)autoHideBars
{
	if (self.navBar.hidden == NO && m_wasManuallyBarHidden == NO)
	{
		[self toggleTopBottomBars];
	}
}

#define TBBAR_TOGGLE_DURATION	0.3

- (void)toggleTopBottomBars
{
	if (self.navBar.hidden)
	{
		// show
		CGRect frmTopEnter = self.navBar.frame;
		frmTopEnter.origin.y = 0;

		CGRect frmBtmEnter = self.vwBtmBar.frame;
		frmBtmEnter.origin.y = self.vwContainer.frame.size.height - frmBtmEnter.size.height;
				
		self.navBar.hidden = NO;
		self.vwBtmBar.hidden = NO;
		[UIView animateWithDuration:TBBAR_TOGGLE_DURATION
			animations:^{
				self.navBar.frame = frmTopEnter;
				self.vwBtmBar.frame = frmBtmEnter;
			} completion:^(BOOL finished) {
				//m_btnViewTypeSwicher.hidden = NO;
				//[UIApplication sharedApplication].statusBarHidden = NO;
			}
		];
	}
	else
	{
		// hide
		m_wasManuallyBarHidden = YES;
		CGRect frmTopExit = self.navBar.frame;
		frmTopExit.origin.y -= frmTopExit.size.height;

		CGRect frmBtmExit = self.vwBtmBar.frame;
		frmBtmExit.origin.y += frmBtmExit.size.height;
		
		[UIView animateWithDuration:TBBAR_TOGGLE_DURATION
			animations:^{
				self.navBar.frame = frmTopExit;
				self.vwBtmBar.frame = frmBtmExit;
			} completion:^(BOOL finished) {
				self.navBar.hidden = YES;
				self.vwBtmBar.hidden = YES;
				//[UIApplication sharedApplication].statusBarHidden = YES;
			}
		];
	}
}

- (void)handleSingleTap:(UITapGestureRecognizer*)sender
{
	if (sender.state == UIGestureRecognizerStateEnded)
	{
		CGPoint pt = [sender locationInView:self.vwContainer];
		float third = self.vwContainer.frame.size.width / 3;
		
		BOOL isLeft;
		BOOL isForward;
		
		if (pt.x < third)
		{
			// left
			isLeft = YES;
			isForward = m_isRtoL;
		}
		else if (pt.x > 2 * third)
		{
			// right
			isLeft = NO;
			isForward = !m_isRtoL;
		}
		else
		{
			// toggle ui
			[self toggleTopBottomBars];
			return;
		}
		
		[m_coreDelegate onTapScreenSide:isLeft forDirection:isForward];
	}
}

- (void)setRtoL:(BOOL)isR2L
{
	m_isRtoL = isR2L;
	
	UIColor *clrMin, *clrMax;
	if (m_isRtoL)
	{
		clrMin = [UIColor whiteColor];
		clrMax = [UIColor blueColor];
	}
	else
	{
		clrMin = [UIColor blueColor];
		clrMax = [UIColor whiteColor];
	}

	self.pageSlider.minimumTrackTintColor = clrMin;
	self.pageSlider.maximumTrackTintColor = clrMax;

	if (GetAppDelegate().isIOS7)
	{
		// UISlider bug workaround
		CGRect rect = CGRectMake(0, 0, 1, 1);
		UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0);
		[clrMax setFill];
		UIRectFill(rect);
		UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
		
		[self.pageSlider setMaximumTrackImage:image forState:UIControlStateNormal];
	}

	[self setPageProgress:0 withLabel:nil];
}

- (void)setProgressPercent:(float)rate
{
	rate *= 100;
	NSString* fmt = (rate - floorf(rate) < 0.1f) ? @"%.0f%%" : @"%.1f%%";
	self.lbProgress.text = [NSString stringWithFormat:fmt, rate];
}

- (void)setPageProgress:(float)rate withLabel:(NSString*)lb
{
	if (lb != nil)
		self.lbProgress.text = lb;
	else
		[self setProgressPercent:rate];
		
	m_progressRate = rate;
	
	if (m_isRtoL)
	{
		self.pageSlider.value = self.pageSlider.maximumValue - m_progressRate;
	}
	else
	{
		self.pageSlider.value = m_progressRate;
	}
}

- (void)showPageEndPopup
{
	if (m_curRequestVolumeIndex +1 < self.titleInfo.volumes.count)
	{
		m_alertPageEnd = [[UIAlertView alloc] initWithTitle:self.navBar.topItem.title
			message:GetLocalizedString(@"a_gonext")
			delegate:self
			cancelButtonTitle:GetLocalizedString(@"no")
			otherButtonTitles:GetLocalizedString(@"yes"), nil];
	}
	else
	{
		m_alertPageEnd = [[UIAlertView alloc] initWithTitle:self.navBar.topItem.title
			message:GetLocalizedString(@"a_nonext")
			delegate:self
			cancelButtonTitle:GetLocalizedString(@"ok")
			otherButtonTitles:nil];
	}
	
	[m_alertPageEnd show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView == m_alertPageEnd)
	{
		m_alertPageEnd = nil;
		if (buttonIndex == 0)
		{
			// go back
			[m_coreDelegate onTapScreenSide:(!m_isRtoL) forDirection:NO];
		}
		else
		{
			[self selectVolumeAtIndex:m_curRequestVolumeIndex +1];
		}
	}
}

- (IBAction)onSliderChange:(UISlider *)sender
{
	m_progressRate = m_isRtoL ? (sender.maximumValue - sender.value) : sender.value;
	[self setProgressPercent:m_progressRate];
}

- (IBAction)onSliderTouchUp:(UISlider *)sender
{
	[self onSliderChange:sender];	
	[m_coreDelegate onSliderChanged:m_progressRate];
}

- (IBAction)onBackButtonClick:(UIBarButtonItem *)sender
{
	if (m_popoverMenu != nil)
	{
		[m_popoverMenu dismissPopoverAnimated:NO];
		m_popoverMenu = nil;
	}
	
	[self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)onMoreButtonClick:(UIBarButtonItem *)sender
{
	if (m_popoverMenu != nil)
	{
		NSTRACE(@"Popover still visible.");
		return;
	}
	
	m_menuItems = [[NSMutableArray alloc] initWithCapacity:4];
	
	if (m_curRequestVolumeIndex > 0)
	{
		[m_menuItems addObject:@"menu_prevvol"];
	}
	
	if (m_curRequestVolumeIndex +1 < self.titleInfo.volumes.count)
	{
		[m_menuItems addObject:@"menu_nextvol"];
	}
	
	//[m_menuItems addObject:@"menu_bugreport"];
	
	UITableViewController* tvc = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
	tvc.tableView.dataSource = self;
	tvc.tableView.delegate = self;
	if (GetAppDelegate().isIOS7)
	{
		tvc.preferredContentSize = CGSizeMake(320, 640);
	}
	else
	{
		tvc.contentSizeForViewInPopover = CGSizeMake(320, 640);
	}

	if (GetAppDelegate().isIpad)
	{
		m_popoverMenu = [[UIPopoverController alloc] initWithContentViewController:tvc];
		m_popoverMenu.delegate = self;
		
		[m_popoverMenu presentPopoverFromBarButtonItem:sender
			permittedArrowDirections:UIPopoverArrowDirectionAny
			animated:YES];
	}
	else
	{
		tvc.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:tvc animated:YES];
		self.hidesBottomBarWhenPushed = YES;
	}
}

// Popover Menu TableView

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
	if (popoverController == m_popoverMenu)
	{
		m_popoverMenu = nil;
	}
	else if (popoverController == m_popoverBugReport)
	{
		m_popoverBugReport = nil;
	}
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section == 0)
	{
		return GetLocalizedString(@"sect_menu");
	}
	
	return GetLocalizedString(@"sect_vols");
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (section == 0)
	{
		return m_menuItems.count;
	}
	else
	{
		return self.titleInfo.volumes.count;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString* CellIdentifier = @"MoreMnu";

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil)
	{
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
	}
	
	if (indexPath.section == 0)
	{
		cell.textLabel.text = GetLocalizedString([m_menuItems objectAtIndex:indexPath.row]);
		cell.accessoryType = UITableViewCellAccessoryNone;
	}
	else
	{
		API_VolumeInfo* vol = [self.titleInfo.volumes objectAtIndex:indexPath.row];
		cell.textLabel.text = [NSString stringWithFormat:@"%d 권", vol.seqNum];
		cell.accessoryType = (indexPath.row == m_curRequestVolumeIndex) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	}
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0)
	{
		NSString* key = [m_menuItems objectAtIndex:indexPath.row];
		if ([key isEqualToString:@"menu_prevvol"])
		{
			[self selectVolumeAtIndex:(m_curRequestVolumeIndex -1)];
		}
		else if ([key isEqualToString:@"menu_nextvol"])
		{
			[self selectVolumeAtIndex:(m_curRequestVolumeIndex +1)];
		}
		else if ([key isEqualToString:@"menu_bugreport"])
		{
			PvChildPageVC* vc = [[PvChildPageVC alloc] init];
			vc.preferredContentSize = CGSizeMake(400,600);
			m_popoverBugReport = [[UIPopoverController alloc] initWithContentViewController:vc];
			
			CGRect frm = self.view.frame;
			frm.origin.x = frm.size.width /2;
			frm.origin.y = frm.size.height /2;
			frm.size.width = 2;
			frm.size.height = 2;
			[m_popoverBugReport presentPopoverFromRect:frm
				inView:self.view
				permittedArrowDirections:UIPopoverArrowDirectionDown
				animated:YES];
			}
	}
	else
	{
		if (indexPath.row != m_curRequestVolumeIndex)
			[self selectVolumeAtIndex:indexPath.row];
	}
	
	if (GetAppDelegate().isIpad)
	{
		[m_popoverMenu dismissPopoverAnimated:YES];
		m_popoverMenu = nil;
	}
	else
	{
		[self.navigationController popViewControllerAnimated:YES];
	}
}

@end


@implementation UIViewController (SliderFrame)

- (SliderFrameVC*)getSliderFrameVC
{
	if ([self.parentViewController isKindOfClass:[SliderFrameVC class]])
	{
		SliderFrameVC* parentVC = (SliderFrameVC*) self.parentViewController;
		return parentVC;
	}

	NSTRACE(@"getSliderFrameVC failed: %@", self.parentViewController);
	ASSERT(!"getSliderFrameVC failed: not SliderFrameVC");
	return nil;
}

@end
