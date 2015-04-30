//
//  PvChildPageVC.m
//  manhwa
//
//  Created by shkim on 10/27/14.
//  Copyright (c) 2014 shkim. All rights reserved.
//

#import "PvChildPageVC.h"
#import "PagedViewerVC.h"

@interface PvChildPageVC () <UIScrollViewDelegate>
{
	UIScrollView* m_scrView;
	UIImageView* m_imgView;
	UIActivityIndicatorView* m_activityWait;
	
	CGSize m_sizeContainer;
	CGSize m_sizeImageFrame;
	UIEdgeInsets m_insetMargins;
}

@end

@implementation PvChildPageVC

@synthesize pendingPageAndCrop = m_pendingPageAndCrop;
@synthesize pageSeq = m_curPageSeq;
@synthesize cropType = m_curCropType;

- (id)init
{
	self = [super init];
	if (self)
	{
		m_curPageSeq = -1;	// initial not-yet-engaged state	
	}
	
	return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
	
	CGRect frm = self.view.frame;
	m_scrView = [[UIScrollView alloc] initWithFrame:frm];
	m_scrView.delegate = self;
	m_scrView.showsHorizontalScrollIndicator = YES;
	m_scrView.showsVerticalScrollIndicator = YES;
	m_scrView.bounces = YES;
	m_scrView.bouncesZoom = YES;
	[self.view addSubview:m_scrView];
	
	m_imgView = [[UIImageView alloc] initWithFrame:frm];
	[m_scrView addSubview:m_imgView];
	
	m_activityWait = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	m_activityWait.center = self.view.center;
	m_activityWait.hidesWhenStopped = YES;
	[self.view addSubview:m_activityWait];
	[m_activityWait startAnimating];
	
	NSTRACE(@"PvChildPageVC %d did load.", self.arrayIdx);
}

#ifdef _DEBUG
- (NSString *)description
{
	return [NSString stringWithFormat:@"CPV%d(seq=%d,cr=%d,pend=%d,%d)", self.arrayIdx,
		self.pageSeq, (int)self.cropType, (self.pendingPageAndCrop >> 8), self.pendingPageAndCrop & 0xFF];
}
#endif

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

	if (m_curPageSeq == PV_FINAL_PAGE_SEQ)
	{
		NSTRACE(@"final can appear");
		[m_activityWait stopAnimating];
		//self.view.backgroundColor = [UIColor blueColor];
		return;
	}
	
//	NSTRACE(@"CH viewWillAppear: container=(%.1f,%.1f) view=(%.1f,%.1f), scr=(%.1f,%.1f)",
//		m_sizeContainer.width, m_sizeContainer.height, self.view.frame.size.width, self.view.frame.size.height, m_scrView.frame.size.width, m_scrView.frame.size.height);

	if (m_sizeContainer.width != m_sizeImageFrame.width
	|| m_sizeContainer.height != m_sizeImageFrame.height)
	{
		NSTRACE(@"update image frame (%f,%f) (%f,%f)", m_sizeContainer.width, m_sizeImageFrame.width, m_sizeContainer.height, m_sizeImageFrame.height);
		[self handleOrientationChange];
	}
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	NSTRACE(@"CHV view(%@) did appear %d,%d", self, m_curPageSeq, (int)m_curCropType);
	
	if (m_curPageSeq == PV_FINAL_PAGE_SEQ)
	{
		// show eval page
		ASSERT([self.parentViewController isKindOfClass:[PagedViewerVC class]]);
		PagedViewerVC* parentVC = (PagedViewerVC*) self.parentViewController;
		[parentVC onFinalPageReached];
	}
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
	return m_imgView;
}

#define ZOOM_STEP 2

- (CGRect)zoomRectForScale:(float)scale withCenter:(CGPoint)center
{
	CGRect zoomRect;

	// the zoom rect is in the content view's coordinates. 
	//    At a zoom scale of 1.0, it would be the size of the imageScrollView's bounds.
	//    As the zoom scale decreases, so more content is visible, the size of the rect grows.
//	zoomRect.size.height = [m_scrView frame].size.height / scale;
//	zoomRect.size.width  = [m_scrView frame].size.width  / scale;
	zoomRect.size.height = m_sizeImageFrame.height / scale;
	zoomRect.size.width  = m_sizeImageFrame.width  / scale;

	// choose an origin so as to get the right center.
	zoomRect.origin.x    = center.x - (zoomRect.size.width  / 2.0);
	zoomRect.origin.y    = center.y - (zoomRect.size.height / 2.0);

	return zoomRect;
}

- (void)handleDoubleTap:(UITapGestureRecognizer*)sender
{
	// double tap zooms in
	float newScale = [m_scrView zoomScale] * ZOOM_STEP;
	if (newScale >= m_scrView.maximumZoomScale)
		return;
		
	CGRect zoomRect = [self zoomRectForScale:newScale withCenter:[sender locationInView:m_imgView]];
	[m_scrView zoomToRect:zoomRect animated:YES];
}

- (void)handleTwoFingerDoubleTap:(UITapGestureRecognizer*)sender
{
	// two-finger tap zooms out
	float newScale = [m_scrView zoomScale] / ZOOM_STEP;
	if (newScale <= m_scrView.minimumZoomScale)
		return;
	
	CGRect zoomRect = [self zoomRectForScale:newScale withCenter:[sender locationInView:m_imgView]];
	[m_scrView zoomToRect:zoomRect animated:YES];
}

- (void)handleOrientationChange
{
	if (m_imgView.image == nil)
		return;

	CGSize sizeImg = m_imgView.image.size;
	CGSize sizeScr = m_sizeContainer;// m_scrView.frame.size;

	const CGFloat ratioImg = sizeImg.width / sizeImg.height;
    const CGFloat ratioScr = sizeScr.width / sizeScr.height;
	//NSTRACE(@"view=(%f,%f) scrview=(%fx%f), img=(%fx%f) r=I%f vs S%F", self.view.frame.size.width, self.view.frame.size.height, sizeScr.width, sizeScr.height, sizeImg.width, sizeImg.height, ratioImg, ratioScr);
	
    CGFloat zoomMax, zoomMin;
    CGRect frameImg;

    if (ratioScr < ratioImg)
    {
		frameImg.size.height = sizeScr.width / ratioImg;
		frameImg.size.width = sizeScr.width;
		frameImg.origin.x = 0;
		frameImg.origin.y = (sizeScr.height - frameImg.size.height) /2;

		//zoomMin = sizeScr.width / sizeImg.width;
		//zoomMax = sizeImg.height / sizeScr.height;
    }
    else
    {
		frameImg.size.width = sizeScr.height * ratioImg;
		frameImg.size.height = sizeScr.height;
		frameImg.origin.y = 0;
		frameImg.origin.x = (sizeScr.width - frameImg.size.width) /2;
		
		//zoomMin = sizeScr.height / sizeImg.height;
        //zoomMax = sizeImg.width / sizeScr.width;
    }
	
	//NSTRACE(@"ImgFrm1: %f,%f %f,%f", frameImg.origin.x, frameImg.origin.y, frameImg.size.width, frameImg.size.height);

/*
	m_imgView.backgroundColor = [UIColor redColor];
	m_scrView.backgroundColor = [UIColor yellowColor];
	
//	m_imgView.layer.cornerRadius = 5;
//	m_imgView.clipsToBounds = YES;
	m_imgView.layer.borderColor = [[UIColor greenColor] CGColor];
	m_imgView.layer.borderWidth = 1;
	m_imgView.layer.masksToBounds = YES;
*/

/* TODO
	self.cstrImgWidth.constant = m_sizeImageFrame.width = frameImg.size.width;
	self.cstrImgHeight.constant = m_sizeImageFrame.height = frameImg.size.height;
	
	self.cstrImgLeftMargin.constant = m_insetMargins.left = frameImg.origin.x;
	self.cstrImgTopMargin.constant = m_insetMargins.top = frameImg.origin.y;
	self.cstrImgRightMargin.constant = m_insetMargins.right = sizeScr.width - frameImg.size.width - frameImg.origin.x;
	self.cstrImgBottomMargin.constant = m_insetMargins.bottom = sizeScr.height - frameImg.size.height - frameImg.origin.y;
*/
	zoomMin = 1;
	zoomMax = zoomMin * 4;
//	if (zoomMax < 1)
//		zoomMax = 1;
	
	m_scrView.minimumZoomScale = zoomMin;
    m_scrView.maximumZoomScale  = zoomMax;
	m_scrView.zoomScale = zoomMin;
}

- (void)setFinalPage
{
	m_curPageSeq = PV_FINAL_PAGE_SEQ;
	m_activityWait.hidden = YES;
	NSTRACE(@"Self %@ is final page", self);
}

- (void)setViewSize:(CGSize)viewSize
{
	m_sizeContainer = viewSize;
}

- (void)setPendingPage:(int)pageSeq andCrop:(PvPicCropType)cropType
{
	[m_activityWait startAnimating];
	
	m_pendingPageAndCrop = PvPageAndCrop(pageSeq, cropType);
	m_imgView.image = nil;
	//m_scrView.hidden = YES;
}

- (void)setImageLoadFailed
{
	[m_activityWait stopAnimating];
	//m_scrView.hidden = NO;
}

- (CGRect)getVisibleRect
{
	const float zoomScale = m_scrView.zoomScale;
	const float invZoomScale = 1.f / zoomScale;
	
	float left = (m_scrView.contentOffset.x - m_insetMargins.left) * invZoomScale;
	float top = (m_scrView.contentOffset.y - m_insetMargins.top) * invZoomScale;
	float right = left + m_sizeContainer.width * invZoomScale;
	float bottom = top + m_sizeContainer.height * invZoomScale;
	
	if (left < 0)
		left = 0;
	if (top < 0)
		top = 0;
	if (right > m_sizeImageFrame.width)
		right = m_sizeImageFrame.width;
	if (bottom > m_sizeImageFrame.height)
		bottom = m_sizeImageFrame.height;
	
	CGSize imgSize = m_imgView.image.size;
	
	CGRect rect;
	rect.origin.x = left * imgSize.width / m_sizeImageFrame.width;
	rect.size.width = (right - left) * imgSize.width / m_sizeImageFrame.width;
	rect.origin.y = top * imgSize.height / m_sizeImageFrame.height;
	rect.size.height = (bottom - top) * imgSize.height / m_sizeImageFrame.height;
	
	return rect;
}

- (BOOL)setImageLoaded:(PvPicItem*)pic withCrop:(PvPicCropType)cropType
{
	[m_activityWait stopAnimating];
	
	if (cropType == PvPicCropNone)
	{
		m_imgView.image = pic.bitmap;
	}
	else
	{
		CGRect cropRect;
		cropRect.origin.y = 0;
		cropRect.size = pic.bitmap.size;
		cropRect.size.width /= 2;
		
		if (cropType == PvPicCropLeft)
		{
			cropRect.origin.x = 0;
		}
		else
		{
			cropRect.origin.x = cropRect.size.width;
		}
		
		CGImageRef imageRef = CGImageCreateWithImageInRect([pic.bitmap CGImage], cropRect);
		m_imgView.image = [UIImage imageWithCGImage:imageRef];
		CGImageRelease(imageRef);
	}
	
	m_curPageSeq = pic.nPageSeq;
	m_curCropType = cropType;
	m_pendingPageAndCrop = 0;
		
	[self handleOrientationChange];
	
	return TRUE;
}

@end
