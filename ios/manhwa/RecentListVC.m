//
//  RecentListVC.m
//  manhwa
//
//  Created by shkim on 11/2/14.
//  Copyright (c) 2014 shkim. All rights reserved.
//

#import "RecentListVC.h"
#import "SliderFrameVC.h"
#import "ApiService.h"
#import "AppDelegate.h"
#import "util.h"

#import "MBProgressHUD.h"

static NSString* const KEY_RecentItems = @"RiAR";
static NSString* const KEY_RecentTitleName = @"RiTN";
static NSString* const KEY_RecentTitleId = @"RiTI";
static NSString* const KEY_RecentVolumeIdx = @"RiVI";
static NSString* const KEY_RecentPageSeq = @"RiPS";

@interface RecentItem : NSObject
@property (nonatomic, assign) int titleId;
@property (nonatomic, assign) int volumeIdx;	// not id, from 0~
@property (nonatomic, assign) int pageSeq; // from 0~
@property (nonatomic, strong) NSString* titleName;
@end

@implementation RecentItem
@end

@interface RecentListVC () <ApiResultDelegate>
{
	NSMutableArray* m_items;
	MBProgressHUD* m_hud;
	__weak RecentItem* m_curRequestItem;
	
	BOOL m_needRefresh;
}

@end

@implementation RecentListVC

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

	self.title = GetLocalizedString(@"tab_recent");
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	self.hidesBottomBarWhenPushed = NO;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	if (m_needRefresh)
	{
		m_needRefresh = NO;
		[self.tableView reloadData];
	}
}

- (void)loadRecentList:(NSUserDefaults*)ud
{
	NSArray* arr = [ud arrayForKey:KEY_RecentItems];
	if (arr == nil)
	{
		// no history
		m_items = [[NSMutableArray alloc] init];
	}
	else
	{
		m_items = [[NSMutableArray alloc] initWithCapacity:arr.count];
		
		for (NSDictionary* rdic in arr)
		{
			RecentItem* item = [RecentItem alloc];
			item.titleName = [rdic objectForKey:KEY_RecentTitleName];
			item.titleId = [[rdic objectForKey:KEY_RecentTitleId] intValue];
			item.volumeIdx = [[rdic objectForKey:KEY_RecentVolumeIdx] intValue];
			item.pageSeq = [[rdic objectForKey:KEY_RecentPageSeq] intValue];
			[m_items addObject:item];
		}
	}
}

- (void)saveRecentList:(NSUserDefaults*)ud
{
	if (m_items.count == 0)
	{
		[ud removeObjectForKey:KEY_RecentItems];
	}
	else
	{
		NSMutableArray* arrSave = [[NSMutableArray alloc] initWithCapacity:m_items.count];
		for (RecentItem* item in m_items)
		{
			NSMutableDictionary* rdic = [[NSMutableDictionary alloc] initWithCapacity:4];
			[rdic setValue:item.titleName forKey:KEY_RecentTitleName];
			[rdic setValue:[NSNumber numberWithInt:item.titleId] forKey:KEY_RecentTitleId];
			[rdic setValue:[NSNumber numberWithInt:item.volumeIdx] forKey:KEY_RecentVolumeIdx];
			[rdic setValue:[NSNumber numberWithInt:item.pageSeq] forKey:KEY_RecentPageSeq];
			[arrSave addObject:rdic];
		}
		
		[ud setObject:arrSave forKey:KEY_RecentItems];
	}
}

- (void)logRecentTitleId:(int)titleId andName:(NSString*)titleName atPage:(int)pageSeq ofVolume:(int)volumeIdx
{
	m_needRefresh = YES;

	for (int i=0; i<m_items.count; i++)
	{
		RecentItem* item = [m_items objectAtIndex:i];
		
		if (item.titleId == titleId)
		{
			item.pageSeq = pageSeq;
			item.volumeIdx = volumeIdx;
			
			[m_items removeObjectAtIndex:i];
			[m_items insertObject:item atIndex:0];
			return;
		}
	}
	
	// new item
	RecentItem* item = [RecentItem new];
	item.titleId = titleId;
	item.titleName = titleName;
	item.volumeIdx = volumeIdx;
	item.pageSeq = pageSeq;
	[m_items insertObject:item atIndex:0];
	
	if (m_items.count > 50)
	{
		[m_items removeLastObject];
	}
}


- (BOOL)onApi:(int)jobId failedWithErrorCode:(NSString*)errCode andMessage:(NSString*)errMsg
{
	[m_hud hide:YES];
	m_hud = nil;

	return NO;
}

- (void)onApi:(int)jobId result:(id)_param
{
	[m_hud hide:YES];
	m_hud = nil;
	
	if (jobId == JOBID_TITLE_INFO)
	{
		API_TitleInfo* res = (API_TitleInfo*)_param;
		if (res.titleId == m_curRequestItem.titleId)
		{
			SliderFrameVC* vc = [[SliderFrameVC alloc] init];
			vc.titleInfo = res;
			vc.resumeVolumeIdx = m_curRequestItem.volumeIdx;
			vc.resumePageSeq = m_curRequestItem.pageSeq;
		
			self.hidesBottomBarWhenPushed = YES;
			[self.navigationController pushViewController:vc animated:YES];
		}
	}
}

- (BOOL)isRecentEmpty
{
	return (m_items.count == 0);
}

#pragma mark - Table view data source

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	m_hud = [GetAppDelegate() createHUD];
	m_hud.labelText = GetLocalizedString(@"wait_gettitle");
	[m_hud show:YES];

	m_curRequestItem = [m_items objectAtIndex:indexPath.row];
	[GetApiService() requestTitleInfo:m_curRequestItem.titleId delegate:self];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return m_items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString* cellId = @"RecentCell";
	
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
	if (cell == nil)
	{
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
	}
    
	RecentItem* item = [m_items objectAtIndex:indexPath.row];
	cell.textLabel.text = item.titleName;
	cell.detailTextLabel.text = [NSString stringWithFormat:@"%d권 %d페이지", item.volumeIdx +1, item.pageSeq +1];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete)
	{
        // Delete the row from the data source
		[m_items removeObjectAtIndex:indexPath.row];
		[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
	}
	else if (editingStyle == UITableViewCellEditingStyleInsert)
	{
		// Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
		NSTRACE(@"Insert what?");
	}
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
	NSTRACE(@"moveRow from=%d, to=%d", (int)fromIndexPath.row, (int)toIndexPath.row);
	RecentItem* item = [m_items objectAtIndex:fromIndexPath.row];
	NSInteger toRow = toIndexPath.row;
	if (toRow > fromIndexPath.row)
		--toRow;
		
	[m_items removeObjectAtIndex:fromIndexPath.row];
	[m_items insertObject:item atIndex:toRow];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

@end
