//
//  SettingsVC.m
//  manhwa
//
//  Created by shkim on 11/1/14.
//  Copyright (c) 2014 shkim. All rights reserved.
//

#import "SettingsVC.h"
#import "AppDelegate.h"
#import "util.h"

@interface SettingsVC ()

@end

@implementation SettingsVC

- (id)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
	self.title = GetLocalizedString(@"tab_config");
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	switch (section)
	{
	case 0:
		return 2;
		
	default:
		return 0;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section == 0)
	{
		return GetLocalizedString(@"sect_pagefx");
	}
	
	return nil;
}

static NSString* s_aSection1[] = { @"fx_curl", @"fx_scroll" };

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString* _cellId = @"ConfCell";
	
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:_cellId];
	if (cell == nil)
	{
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:_cellId];
	}
    
	switch (indexPath.section)
	{
	case 0:
		cell.textLabel.text = GetLocalizedString(s_aSection1[indexPath.row]);
		cell.accessoryType = (indexPath.row == GetAppDelegate().pref_PageFx) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
		break;
	}
	    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	switch (indexPath.section)
	{
	case 0:
		if (indexPath.row != GetAppDelegate().pref_PageFx)
		{
			if (indexPath.row == 1 && GetAppDelegate().isIOS5)
			{
				// iOS 5.x does not support Scroll FX
				alertSimpleMessage(GetLocalizedString(@"a_noscrfx"));
				return;
			}
			
			[GetAppDelegate() setPref_PageFx:(int)indexPath.row];
			[tableView reloadData];
		}
		break;
	}
}

@end
