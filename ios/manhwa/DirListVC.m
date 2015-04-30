//
//  DirListVC.m
//  manhwa
//
//  Created by shkim on 10/26/14.
//  Copyright (c) 2014 shkim. All rights reserved.
//

#import "DirListVC.h"
#import "SliderFrameVC.h"
#import "AppDelegate.h"
#import "ApiService.h"

#import "MBProgressHUD.h"

@interface DirListVC () <ApiResultDelegate>
{
	MBProgressHUD* m_hud;
	API_DirListResult* m_items;
}

@end

@implementation DirListVC

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
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
	
	if (self.folderId == 0)
	{
		self.title = GetLocalizedString(@"tab_dir");
	}
	
	m_hud = [GetAppDelegate() createHUD];
	m_hud.labelText = GetLocalizedString(@"wait_getlist");
	[m_hud show:YES];
	
#if 0//def DEV_QUICK
	[GetApiService() requestTitleInfo:1 delegate:self];
	return;
#endif

	[GetApiService() requestDirectoryList:self.folderId delegate:self];
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
	
	if (jobId == JOBID_DIRECTORY_LIST)
	{
		API_DirListResult* res = (API_DirListResult*)_param;
		m_items = res;
		
		[self.tableView reloadData];
	}
	else if (jobId == JOBID_TITLE_INFO)
	{
		API_TitleInfo* res = (API_TitleInfo*)_param;
		
		SliderFrameVC* vc = [[SliderFrameVC alloc] init];
		vc.titleInfo = res;
		
		self.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:vc animated:YES];
	}
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return (m_items.folders.count + m_items.titles.count);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString* cellId = @"DirListCell";
	
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
	if (cell == nil)
	{
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
	}
    
	if (indexPath.row < m_items.folders.count)
	{
		API_DirFolder* folder = [m_items.folders objectAtIndex:indexPath.row];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.textLabel.text = folder.name;
		cell.detailTextLabel.text = nil;
	}
	else
	{
		API_DirTitle* title = [m_items.titles objectAtIndex:(indexPath.row - m_items.folders.count)];
		cell.accessoryType = UITableViewCellAccessoryNone;
		cell.textLabel.text = title.nameKor;
		cell.detailTextLabel.text = title.authorName;
	}
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.row < m_items.folders.count)
	{
		API_DirFolder* folder = [m_items.folders objectAtIndex:indexPath.row];
		
		DirListVC* vc = [[DirListVC alloc] init];
		vc.folderId = folder.folderId;
		vc.title = folder.name;
		
		[self.navigationController pushViewController:vc animated:YES];
	}
	else
	{
		API_DirTitle* title = [m_items.titles objectAtIndex:(indexPath.row - m_items.folders.count)];
		
		m_hud = [GetAppDelegate() createHUD];
		m_hud.labelText = GetLocalizedString(@"wait_gettitle");
		[m_hud show:YES];
		
		[GetApiService() requestTitleInfo:title.titleId delegate:self];
	}
}

@end
