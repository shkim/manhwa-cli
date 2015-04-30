//
//  PvChildPageVC.h
//  manhwa
//
//  Created by shkim on 10/27/14.
//  Copyright (c) 2014 shkim. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PvPicItem;

typedef NS_ENUM(NSInteger, PvPicCropType) {
    PvPicCropNone,
    PvPicCropLeft,
    PvPicCropRight
};

#define PV_FINAL_PAGE_SEQ			9999
#define PvPageAndCrop(_seq,_crop)	((_seq << 8)|_crop)
#define PvGetPendingPage(_pend)		(_pend >> 8)

@interface PvChildPageVC : UIViewController

@property (nonatomic, weak) PvChildPageVC* prevPage;
@property (nonatomic, weak) PvChildPageVC* nextPage;
@property (nonatomic, readonly) int pageSeq;	// 0~
@property (nonatomic, readonly) PvPicCropType cropType;
@property (nonatomic, readonly) int pendingPageAndCrop;
#ifdef _DEBUG
@property (nonatomic, assign) int arrayIdx;
#endif

- (void)handleDoubleTap:(UITapGestureRecognizer*)sender;
- (void)handleTwoFingerDoubleTap:(UITapGestureRecognizer*)sender;
- (void)handleOrientationChange;

- (void)setFinalPage;
- (void)setViewSize:(CGSize)viewSize;
//- (void)setLoadingMode;
- (void)setPendingPage:(int)pageSeq andCrop:(PvPicCropType)cropType;
- (void)setImageLoadFailed;
- (BOOL)setImageLoaded:(PvPicItem*)pic withCrop:(PvPicCropType)cropType;
- (CGRect)getVisibleRect;

@end
