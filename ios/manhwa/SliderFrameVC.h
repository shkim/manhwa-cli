//
//  SliderFrameVC.h
//  manhwa
//
//  Created by shkim on 10/29/14.
//  Copyright (c) 2014 shkim. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol SliderFrameDelegate <NSObject>

- (void)onTapScreenSide:(BOOL)isLeft forDirection:(BOOL)isForward;
- (void)onSliderChanged:(float)rate;

//- (void)onOrientationChanged:(CGSize)viewSize;
//- (NSString*)getCurrentPageId;

@end

@class API_TitleInfo;

@interface SliderFrameVC : UIViewController

@property (weak, nonatomic) IBOutlet UIView *vwContainer;
@property (weak, nonatomic) IBOutlet UIView *vwBtmBar;
@property (weak, nonatomic) IBOutlet UINavigationBar *navBar;
@property (weak, nonatomic) IBOutlet UILabel *lbProgress;
@property (weak, nonatomic) IBOutlet UISlider *pageSlider;

@property (nonatomic, strong) API_TitleInfo* titleInfo;
@property (nonatomic, assign) int resumeVolumeIdx;
@property (nonatomic, assign) int resumePageSeq;

- (IBAction)onBackButtonClick:(UIBarButtonItem *)sender;
- (IBAction)onMoreButtonClick:(UIBarButtonItem *)sender;
- (IBAction)onSliderChange:(UISlider *)sender;
- (IBAction)onSliderTouchUp:(UISlider *)sender;

- (void)logRecentState;	// called by AppDelegate
- (void)setPageProgress:(float)rate withLabel:(NSString*)lb;
- (void)showPageEndPopup;

@end

@interface UIViewController (SliderFrame)

- (SliderFrameVC*)getSliderFrameVC;

@end
