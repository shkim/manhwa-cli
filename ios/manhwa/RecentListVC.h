//
//  RecentListVC.h
//  manhwa
//
//  Created by shkim on 11/2/14.
//  Copyright (c) 2014 shkim. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RecentListVC : UITableViewController

- (BOOL)isRecentEmpty;
- (void)loadRecentList:(NSUserDefaults*)ud;
- (void)saveRecentList:(NSUserDefaults*)ud;
- (void)logRecentTitleId:(int)titleId andName:(NSString*)titleName atPage:(int)pageSeq ofVolume:(int)volumeIdx;

@end
