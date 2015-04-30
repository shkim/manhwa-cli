//
//  PagedViewerVC.h
//  manhwa
//
//  Created by shkim on 10/26/14.
//  Copyright (c) 2014 shkim. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SliderFrameVC.h"

@class API_VolumeInfo;

@interface PagedViewerVC : UIPageViewController <UIPageViewControllerDataSource, UIPageViewControllerDelegate, SliderFrameDelegate>

- (id)initWithR2L:(BOOL)isRtoL;
- (void)updateVolumeInfo:(API_VolumeInfo*)volumeInfo;
- (void)onFinalPageReached;	// called by PvChildPageVC

// used by SliderFrameVC
- (BOOL)isReverseDir;
- (int)getCurrentPageSeq;

@end


@interface PvPicItem : NSObject

@property (nonatomic, strong) UIImage* bitmap;

@property (nonatomic, assign) BOOL purgeFired;
@property (nonatomic, assign) BOOL loadFired;

@property (nonatomic, assign) int pageId;	// may not be sequential, usually 0~
@property (nonatomic, assign) int nPageSeq;	// 0~ sequential
//@property (nonatomic, assign) char pageCount;	// 0:unknown, 1:full, 2:two-paged
@property (nonatomic, assign) char fileFormat;

@end
