//
//  PagedViewerVC.m
//  manhwa
//
//  Created by shkim on 10/26/14.
//  Copyright (c) 2014 shkim. All rights reserved.
//

#import "PagedViewerVC.h"
#import "PvChildPageVC.h"
#import "ApiService.h"
#import "HttpMan.h"
#import "AppDelegate.h"
#import "util.h"

@implementation PvPicItem
#ifdef _DEBUG
- (NSString *)description
{
	return [NSString stringWithFormat:@"Pic(seq=%d,bm=%p)", self.nPageSeq, self.bitmap];
}
#endif
@end

@interface PagedViewerVC () <HttpQueryDelegate>
{
	dispatch_queue_t m_bgQueue;
	
	PvChildPageVC* m_aChildPages[3];
	PvChildPageVC* m_finalEndPage;

	int m_volumeId;
	BOOL m_isRtoL;
	BOOL m_isTwoPaged;
	NSMutableArray* m_pagePics;
}

- (void)loadPageImage:(int)pageSeq withCrop:(PvPicCropType)cropType forTargetVC:(PvChildPageVC*)vc;
- (void)postLoadPage:(PvPicItem*)pic forTargetVC:(PvChildPageVC*)vc isManual:(BOOL)isManualLoad;

@end

@implementation PagedViewerVC

- (id)initWithR2L:(BOOL)isR2L
{
	NSDictionary *opts = isR2L ? [NSDictionary dictionaryWithObject:
		[NSNumber numberWithInteger:UIPageViewControllerSpineLocationMax]
		forKey: UIPageViewControllerOptionSpineLocationKey] : nil;

	UIPageViewControllerTransitionStyle style = (GetAppDelegate().pref_PageFx == 1) ?
		UIPageViewControllerTransitionStyleScroll : UIPageViewControllerTransitionStylePageCurl;
	
	self = [super initWithTransitionStyle:style navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:opts];
	
	return self;
}

- (BOOL)isReverseDir
{
	return m_isRtoL;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.

	m_bgQueue = dispatch_queue_create("PgvQ", DISPATCH_QUEUE_SERIAL);
	
	m_finalEndPage = [[PvChildPageVC alloc] init];
	[m_finalEndPage setFinalPage];
#ifdef _DEBUG
	m_finalEndPage.arrayIdx = 99;
#endif
	
	for (int i=0; i<3; i++)
	{
		m_aChildPages[i] = [[PvChildPageVC alloc] init];
#ifdef _DEBUG
		m_aChildPages[i].arrayIdx = i;
#endif
	}
	
	m_aChildPages[0].prevPage = m_aChildPages[2];
	m_aChildPages[0].nextPage = m_aChildPages[1];

	m_aChildPages[1].prevPage = m_aChildPages[0];
	m_aChildPages[1].nextPage = m_aChildPages[2];

	m_aChildPages[2].prevPage = m_aChildPages[1];
	m_aChildPages[2].nextPage = m_aChildPages[0];
	
	self.delegate = self;
	self.dataSource = self;
}

- (void)updateVolumeInfo:(API_VolumeInfo*)volumeInfo
{
	if (!self.isViewLoaded)
	{
		[self performSelector:@selector(updateVolumeInfo:) withObject:volumeInfo afterDelay:0.1];
		return;
	}
	
	m_volumeId = volumeInfo.volumeId;
	m_isRtoL = volumeInfo.isReverseDir;
	m_isTwoPaged = volumeInfo.isTwoPaged;

	m_pagePics = [[NSMutableArray alloc] initWithCapacity:volumeInfo.pages.count];
	for (int i=0; i<volumeInfo.pages.count; i++)
	{
		API_PageInfo* pgi = [volumeInfo.pages objectAtIndex:i];

		PvPicItem* pic = [PvPicItem new];
		pic.nPageSeq = i;
		pic.pageId = pgi.pageId;
		pic.fileFormat = pgi.fileFormat;
		[m_pagePics addObject:pic];
	}
	
	SliderFrameVC* sliFrame = [self getSliderFrameVC];
	int pageSeq = sliFrame.resumePageSeq;
	sliFrame.resumePageSeq = 0;
	if (pageSeq >= m_pagePics.count)
		pageSeq = (int)m_pagePics.count -1;
	
	[m_aChildPages[1] setPendingPage:0 andCrop:0];
	[m_aChildPages[2] setPendingPage:0 andCrop:0];
	[self loadPageImage:pageSeq withCrop:PvPicCropNone forTargetVC:m_aChildPages[0]];
		
	//[sliFrame setPageProgress:0 withLabel:nil];
	//[self updatePageProgress:m_aChildPages[0]];

	[self setViewControllers:@[m_aChildPages[0]]
		direction:UIPageViewControllerNavigationDirectionForward
		animated:NO
		completion:NULL];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
- (void)resumeCreate:(API_VolumeInfo*)volInfo
{
	m_isRtoL = volInfo.isReverseDir;
	m_isTwoPaged = volInfo.isTwoPaged;

	ASSERT(m_arrPages == nil && volInfo.pages.count > 0);
	NSMutableArray* pics = [[NSMutableArray alloc] initWithCapacity:volInfo.pages.count];
	for (int i=0; i<volInfo.pages.count; i++)
	{
		API_PageInfo* pgi = [volInfo.pages objectAtIndex:i];

		PvPicItem* pic = [PvPicItem new];
		pic.nPageSeq = i;
		pic.pageId = pgi.pageId;
		pic.fileFormat = pgi.fileFormat;
		[pics addObject:pic];
	}
	m_arrPages = pics;
	m_nTotalPages = m_arrPages.count;
	
	// setup ui and start loading
	
	[[self getSliderFrameVC] setRtoL:m_isRtoL];
	[[self getSliderFrameVC] setPageProgress:0];

	int nInitialPageSeq = 0;
	m_aChildPages[0].pageIndex = nInitialPageSeq;
	[self loadPageImage:nInitialPageSeq forTargetVC:m_aChildPages[0]];
	
	[self setViewControllers:@[m_aChildPages[0]]
		direction:UIPageViewControllerNavigationDirectionForward
		animated:NO
		completion:NULL];
}
*/

- (void)onFinalPageReached
{
	[[self getSliderFrameVC] showPageEndPopup];
}

- (void)handleDoubleTap:(UITapGestureRecognizer*)sender
{
	PvChildPageVC* vcNow = [self.viewControllers objectAtIndex:0];
	[vcNow handleDoubleTap:sender];
}

- (void)handleTwoFingerDoubleTap:(UITapGestureRecognizer*)sender
{
	PvChildPageVC* vcNow = [self.viewControllers objectAtIndex:0];
	[vcNow handleTwoFingerDoubleTap:sender];
}

- (void)onOrientationChanged:(CGSize)viewSize
{
	for (int i=0; i<3; i++)
	{
		[m_aChildPages[i] setViewSize:viewSize];
	}
	
	if (self.viewControllers.count > 0)
	{
		PvChildPageVC* vcNow = [self.viewControllers objectAtIndex:0];
		[vcNow handleOrientationChange];
	}
}

- (int)getCurrentPageSeq
{
	PvChildPageVC* vcNow = [self.viewControllers objectAtIndex:0];
	if (vcNow.pageSeq == PV_FINAL_PAGE_SEQ)
		vcNow = vcNow.prevPage;
	
	return vcNow.pageSeq;
}

- (void)onTapScreenSide:(BOOL)isLeft forDirection:(BOOL)isForward
{
	NSTRACE(@"onTapScreenSide %d", isForward);
	
	PvChildPageVC* vcNow = [self.viewControllers objectAtIndex:0];

	UIPageViewControllerNavigationDirection dir = isLeft ? UIPageViewControllerNavigationDirectionReverse : UIPageViewControllerNavigationDirectionForward;
	PvChildPageVC* vc = isForward ? [self getNextPageVC:vcNow] : [self getPreviousPageVC:vcNow];
	if (vc == nil)
	{
		if (!isForward)
			alertSimpleMessage(GetLocalizedString(@"a_1page"));
			
		return;
	}
	
	[self setViewControllers:@[vc]
		direction:dir
		animated:YES
		completion:(vc == m_finalEndPage) ? nil : ^(BOOL finished) {
			[self updatePageProgress:vc];
		}
	];
}

- (void)onSliderChanged:(float)rate
{
	NSTRACE(@"onSliderChanged %.1f", rate);
	ASSERT(rate >= 0 && rate <= 1);
	
	if (m_pagePics.count == 0)
	{
		NSTRACE(@"slider changed but page array is empty.");
		return;
	}
	
	int pageSeq = (int)(rate * m_pagePics.count);
	if (pageSeq == m_pagePics.count)
		--pageSeq;

	PvChildPageVC* vc = m_aChildPages[0];
	if (vc.pageSeq != pageSeq)
	{
		[self loadPageImage:pageSeq withCrop:PvPicCropNone forTargetVC:vc];
	}
	
	[self setViewControllers:@[vc]
		direction:UIPageViewControllerNavigationDirectionForward
		animated:NO
		completion:nil];
}

- (void)handleImageLoaded:(PvPicItem*)item forTargetVC:(PvChildPageVC*)vc isManual:(BOOL)isManualLoad
{
	if (item.bitmap == nil)
	{
		NSTRACE(@"handleImageLoaded: bitmap is null (LOAD FAILED)");
		[vc setImageLoadFailed];
		alertSimpleMessage([NSString stringWithFormat:@"이미지 로딩에 실패하였습니다. (%d of %d)", item.nPageSeq, (int)m_pagePics.count]);
		return;
	}

	if (isManualLoad)
	{
		int pendingPage = vc.pendingPageAndCrop >> 8;
		if (pendingPage != item.nPageSeq)
		{
			NSTRACE(@"bitmap(%d) loaded but page changed to %d.", item.nPageSeq, pendingPage);
		}
		else
		{
			int pendingCrop = vc.pendingPageAndCrop & 0xFF;
		
			PvPicCropType cropType;
			if (m_isTwoPaged)
			{
				CGSize imgSize = item.bitmap.size;
				
				if (pendingCrop == PvPicCropNone)
				{
					// auto
					if (imgSize.width > imgSize.height)
					{
						// maybe two-paged
						if (m_isRtoL)
						{
							cropType = PvPicCropRight;
						}
						else
						{
							cropType = PvPicCropLeft;
						}
					}
					else
					{
						// single page
						cropType = PvPicCropNone;
					}
				}
				else
				{
					if (imgSize.width < imgSize.height)
					{
						// maybe single
						cropType = PvPicCropNone;
					}
					else
					{
						cropType = pendingCrop;
					}
				}
			}
			else
			{
				cropType = PvPicCropNone;
			}
			
			[vc setImageLoaded:item withCrop:cropType];

			if(self.viewControllers.count == 1)
			{
				PvChildPageVC* vcNow = [self.viewControllers objectAtIndex:0];
				if (vcNow == vc)
					[self updatePageProgress:vc];
			}
		}
		
		// unload far and preload near
		int lower = item.nPageSeq -1;
		if (lower >= 0)
		{
			PvPicItem* lowerPic = [m_pagePics objectAtIndex:lower];
			if (lowerPic.bitmap == nil)
			{
				[self postLoadPage:lowerPic forTargetVC:nil isManual:NO];
			}
		}
		
		for (--lower; lower >= 0; --lower)
		{
			PvPicItem* pi = [m_pagePics objectAtIndex:lower];
			pi.bitmap = nil;
		}
		
		int upper = item.nPageSeq +1;
		if (upper < m_pagePics.count)
		{
			PvPicItem* upperPic = [m_pagePics objectAtIndex:upper];
			if (upperPic.bitmap == nil)
			{
				[self postLoadPage:upperPic forTargetVC:nil isManual:NO];
			}
		}
		
		for (++upper; upper<m_pagePics.count; ++upper)
		{
			PvPicItem* pi = [m_pagePics objectAtIndex:upper];
			pi.bitmap = nil;
		}
	}
	else
	{
		NSTRACE(@"preloaded bitmap at page %d", item.nPageSeq);
	}
	
}

- (void)httpQueryJob:(int)jobId didFailWithStatus:(NSInteger)status forSpec:(HttpQuerySpec*)spec
{
	int nPageSeq = jobId - JOBID_GET_IMAGE;
	ASSERT(nPageSeq >= 0 && nPageSeq < m_pagePics.count);
	PvPicItem* pic = [m_pagePics objectAtIndex:nPageSeq];
	pic.loadFired = NO;
	
	alertSimpleMessage([NSString stringWithFormat:@"Image loading failed: %d", jobId - JOBID_GET_IMAGE]);
}

- (void)httpQueryJob:(int)jobId didSucceedWithResult:(id)result forSpec:(HttpQuerySpec*)spec
{
	int nPageSeq = jobId - JOBID_GET_IMAGE;
	ASSERT(nPageSeq >= 0 && nPageSeq < m_pagePics.count);
	
	PvPicItem* pic = [m_pagePics objectAtIndex:nPageSeq];
	if(pic.bitmap == nil)
	{
		pic.bitmap = [UIImage imageWithData:(NSData*)result];
	}
	else NSTRACE(@"WARNING: already loaded pic seq=%d", nPageSeq);

	pic.loadFired = NO;
	PvChildPageVC* vc = (PvChildPageVC*) spec.userObj;
	BOOL isManualLoad = [[spec getUserVarForKey:@"isML"] intValue];

	NSTRACE(@"http ok: %d,%d => %@", pic.pageId, vc.pageSeq, pic.bitmap);
	dispatch_async(dispatch_get_main_queue(), ^{
		[self handleImageLoaded:pic forTargetVC:vc isManual:isManualLoad];
	});
}

- (void)postLoadPage:(PvPicItem*)pic forTargetVC:(PvChildPageVC*)vc isManual:(BOOL)isManualLoad
{
//	if (network mode)
	{
		if (pic.loadFired)
		{
			NSTRACE(@"Pic seq=%d already LoadHttp fired.", pic.nPageSeq);
			return;
		}
		
		if (pic.purgeFired)
		{
			NSTRACE(@"Pic seq=%d purge fired, but load also fired. clearing purge...", pic.nPageSeq);
			pic.purgeFired = NO;
		}
		
		pic.loadFired = YES;
		HttpQuerySpec* spec = [GetApiService() getSpecForPage:pic.pageId ofVolume:m_volumeId];
		spec.userObj = vc;
		[spec addUserVar:(isManualLoad ? @"1":@"0") forKey:@"isML"];
		[GetHttpMan() request:(JOBID_GET_IMAGE + pic.nPageSeq) forSpec:spec delegate:self];
	}
/*	else
	{

		dispatch_async(m_bgQueue, ^{
	
			// load picture from pak on bg-thread
			pic.bitmap = [m_pakArc getImage:pic.filename];
		
			dispatch_async(dispatch_get_main_queue(), ^{
				[self handleImageLoaded:pic forTargetVC:vc isManual:isManualLoad];
			});
		});
	}
*/
}

- (void)deferHandleImageLoaded:(NSArray*)args
{
	PvPicItem* item = [args objectAtIndex:0];
	PvChildPageVC* vc = [args objectAtIndex:1];
	
	NSTRACE(@"deferHIL_2: item=%@, vc=%@ (%d)", item, vc, vc.isViewLoaded);
	
	if (vc.isViewLoaded)
	{
	    [self handleImageLoaded:item forTargetVC:vc isManual:YES];
	}
	else
	{
		[self performSelector:@selector(deferHandleImageLoaded:)
			withObject:[NSArray arrayWithObjects:item, vc, nil]
			afterDelay:0.1];
	}
}

- (void)loadPageImage:(int)pageSeq withCrop:(PvPicCropType)cropType forTargetVC:(PvChildPageVC*)vc
{
	PvPicItem* item = [m_pagePics objectAtIndex:pageSeq];
    NSTRACE(@"loadPageImage:%d,%d vc=%@, pic=%@", pageSeq, (int)cropType, vc, item);
	
	[vc setPendingPage:pageSeq andCrop:cropType];
	
	if (item.bitmap == nil)
	{
		[self postLoadPage:item forTargetVC:vc isManual:YES];
	}
	else
	{
		if (vc.isViewLoaded)
		{
			[self handleImageLoaded:item forTargetVC:vc isManual:YES];
		}
		else
		{
            NSTRACE(@"deferHIL: pic=%@, vc=%@", item, vc);
			[self performSelector:@selector(deferHandleImageLoaded:)
				withObject:[NSArray arrayWithObjects:item, vc, nil]
				afterDelay:0.1];
		}
	}
}

- (void)updatePageProgress:(PvChildPageVC*)vcNow
{
	const float page1rate = 1.0f / (float)m_pagePics.count;
	float progress = vcNow.pageSeq * page1rate;
	
	if (vcNow.pageSeq == m_pagePics.count -1)
	{
		if (m_isTwoPaged)
		{
			if (m_isRtoL)
			{
				if (vcNow.cropType != PvPicCropRight)
					progress = 1;
			}
			else
			{
				if (vcNow.cropType != PvPicCropLeft)
					progress = 1;
			}
		}
		else
		{
			progress = 1;
		}
	}
	else
	{
		if (m_isTwoPaged)
		{
			if (m_isRtoL)
			{
				if (vcNow.cropType == PvPicCropLeft)
					progress += page1rate * 0.5f;
			}
			else
			{
				if (vcNow.cropType == PvPicCropRight)
					progress += page1rate * 0.5f;
			}
		}
	}
	
	NSString* pageLR;
	if (vcNow.cropType == PvPicCropLeft)
		pageLR = @"L";
	else if (vcNow.cropType == PvPicCropRight)
		pageLR = @"R";
	else
		pageLR = @"";

	NSString* lb = [NSString stringWithFormat:@"%d%@/%d",
		vcNow.pageSeq +1, pageLR, (int)m_pagePics.count];
	
	[[self getSliderFrameVC] setPageProgress:progress withLabel:lb];
}

#pragma mark - Page View Controller Data Source

- (PvChildPageVC*)getPreviousPageVC:(PvChildPageVC *)vcCurrent
{
	if (vcCurrent.pageSeq == PV_FINAL_PAGE_SEQ)
	{
		ASSERT(vcCurrent == m_finalEndPage);
		ASSERT(m_finalEndPage.prevPage != nil);
		return m_finalEndPage.prevPage;
	}
	
	int curPageSeq = vcCurrent.pageSeq;
	if (curPageSeq < 0)
		curPageSeq = PvGetPendingPage(vcCurrent.pendingPageAndCrop);
	
	int prevSeq;
	PvPicCropType prevCrop;
	
	if (vcCurrent.cropType == PvPicCropNone)
	{
		prevSeq = curPageSeq -1;
		
		if (!m_isTwoPaged)
			prevCrop = PvPicCropNone;
		else if (m_isRtoL)
			prevCrop = PvPicCropLeft;
		else
			prevCrop = PvPicCropRight;
	}
	else
	{
		if (m_isRtoL)
		{
			if (vcCurrent.cropType == PvPicCropLeft)
			{
				prevSeq = curPageSeq;
				prevCrop = PvPicCropRight;
			}
			else
			{
				prevSeq = curPageSeq -1;
				prevCrop = PvPicCropLeft;
			}
		}
		else
		{
			if (vcCurrent.cropType == PvPicCropRight)
			{
				prevSeq = curPageSeq;
				prevCrop = PvPicCropLeft;
			}
			else
			{
				prevSeq = curPageSeq -1;
				prevCrop = PvPicCropRight;
			}
		}
	}
		
	if (prevSeq < 0)
		return nil;
	
	PvChildPageVC* ret = vcCurrent.prevPage;
	if (ret.pageSeq != prevSeq || ret.cropType != prevCrop)
	{
		[self loadPageImage:prevSeq withCrop:prevCrop forTargetVC:ret];
	}
	
	return ret;
}

- (PvChildPageVC*)getNextPageVC:(PvChildPageVC *)vcCurrent
{
	if (vcCurrent.pageSeq == PV_FINAL_PAGE_SEQ)
	{
		ASSERT(vcCurrent == m_finalEndPage);
		return nil;
	}
	
	int curPageSeq = vcCurrent.pageSeq;
	if (curPageSeq < 0)
		curPageSeq = PvGetPendingPage(vcCurrent.pendingPageAndCrop);

	int nextSeq;
	PvPicCropType nextCrop;
	
	if (vcCurrent.cropType == PvPicCropNone)
	{
		nextSeq = curPageSeq +1;
		
		if (!m_isTwoPaged)
			nextCrop = PvPicCropNone;
		else if (m_isRtoL)
			nextCrop = PvPicCropRight;
		else
			nextCrop = PvPicCropLeft;
	}
	else
	{
		if (m_isRtoL)
		{
			if (vcCurrent.cropType == PvPicCropRight)
			{
				nextSeq = curPageSeq;
				nextCrop = PvPicCropLeft;
			}
			else
			{
				nextSeq = curPageSeq +1;
				nextCrop = PvPicCropRight;
			}
		}
		else
		{
			if (vcCurrent.cropType == PvPicCropLeft)
			{
				nextSeq = curPageSeq;
				nextCrop = PvPicCropRight;
			}
			else
			{
				nextSeq = curPageSeq +1;
				nextCrop = PvPicCropLeft;
			}
		}
	}
		
	if (nextSeq >= m_pagePics.count)
	{
		m_finalEndPage.prevPage = vcCurrent;
		return m_finalEndPage;
	}
	
	PvChildPageVC* ret = vcCurrent.nextPage;
	if (ret.pageSeq != nextSeq || ret.cropType != nextCrop)
	{
		[self loadPageImage:nextSeq withCrop:nextCrop forTargetVC:ret];
	}
	
	return ret;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(PvChildPageVC *)vc
{
	if (m_isRtoL)
	{
		return [self getNextPageVC:vc];
	}
	else
	{
		return [self getPreviousPageVC:vc];
	}
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(PvChildPageVC *)vc
{
	if (m_isRtoL)
	{
		return [self getPreviousPageVC:vc];
	}
	else
	{
		return [self getNextPageVC:vc];
	}
}

#pragma mark - UIPageViewController delegate methods

// Sent when a gesture-initiated transition begins.
/* iOS 6.0 only
- (void)pageViewController:(UIPageViewController *)pageViewController willTransitionToViewControllers:(NSArray *)pendingViewControllers
{
	ASSERT(pendingViewControllers.count == 1);
	PvChildPageVC* vc = [pendingViewControllers objectAtIndex:0];
	NSTRACE(@"vc willTransitionToViewControllers index=%d", vc.pageIndex);
	
	if (vc.pageIndex >= 0 && ![vc isImageReady])
		[self loadPageImage:vc.pageIndex forTargetVC:vc];
}
*/

// Sent when a gesture-initiated transition ends. The 'finished' parameter indicates whether the animation finished, while the 'completed' parameter indicates whether the transition completed or bailed out (if the user let go early).
- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray *)previousViewControllers transitionCompleted:(BOOL)completed
{
	ASSERT(previousViewControllers.count == 1);
	PvChildPageVC* vcNow = [self.viewControllers objectAtIndex:0];
	
//	PvChildPageVC* vc = [previousViewControllers objectAtIndex:0];
//	NSTRACE(@"vc(%d,%ld) didFinishAnim=%d, %ld vcNow(%d,%ld)", vc.pageSeq, vc.cropType, completed, self.viewControllers.count, vcNow.pageSeq, vcNow.cropType);

	if (vcNow.pageSeq >= 0)
	{
		[self updatePageProgress:vcNow];
	}
}

// Delegate may specify a different spine location for after the interface orientation change. Only sent for transition style 'UIPageViewControllerTransitionStylePageCurl'.
// Delegate may set new view controllers or update double-sided state within this method's implementation as well.
- (UIPageViewControllerSpineLocation)pageViewController:(UIPageViewController *)pageViewController spineLocationForInterfaceOrientation:(UIInterfaceOrientation)orientation
{
	if (UIInterfaceOrientationIsPortrait(orientation))
	{
		return (m_isRtoL ? UIPageViewControllerSpineLocationMax : UIPageViewControllerSpineLocationMin);
	}
	else
	{
		return UIPageViewControllerSpineLocationMid;
	}
}

- (NSUInteger)pageViewControllerSupportedInterfaceOrientations:(UIPageViewController *)pageViewController
{
	return (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown);
}

- (UIInterfaceOrientation)pageViewControllerPreferredInterfaceOrientationForPresentation:(UIPageViewController *)pageViewController
{
	return UIInterfaceOrientationPortrait;
}

@end
