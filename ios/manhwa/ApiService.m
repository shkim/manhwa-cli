//
//  ApiService.m
//  manhwa
//
//  Created by shkim on 10/27/14.
//  Copyright (c) 2014 shkim. All rights reserved.
//

#import "ApiService.h"
#import "HttpMan.h"
#import "AppDelegate.h"
#import "AES256Cipher.h"
#import "util.h"


static NSString* API_BASEURL = @"http://comic.ogp.kr/a/";

@implementation API_VersionResult
@end
@implementation API_LoginResult
@end
@implementation API_TitleInfo
@end
@implementation API_VolumeInfo
@end
@implementation API_PageInfo
@end
@implementation API_DirFolder
@end
@implementation API_DirTitle
@end
@implementation API_DirListResult
@end


@interface NSDictionary (GetJsonString)
- (NSString*)stringForKey:(NSString*)key;
@end
@implementation NSDictionary (GetJsonString)
- (NSString*)stringForKey:(NSString*)key
{
	id val = [self objectForKey:key];
	return (val == nil || val == [NSNull null]) ? nil : val;
}
@end

@interface ApiService () <HttpQueryDelegate, UIAlertViewDelegate>
{
	NSString* m_sessKey;
	AES256Cipher* m_cipher;
}

@end

@implementation ApiService

- (id)init
{
	self = [super init];
	if (self)
	{
		m_cipher = [[AES256Cipher alloc]
			initWithKey:@"ED94C926FC4C9690CB889E4D6A24DDDA3C6D3B3292D37035F79E4FED9117CC69"
			andIV:@"AE456157ED8F2ED5524450CA9774643D"];
	}
	
	return self;
}

- (HttpQuerySpec*)getEmptySpec:(const char*)uri
{
	HttpQuerySpec* spec = [[HttpQuerySpec alloc] init];
	
	[spec setUrl:[NSString stringWithFormat:@"%@%s", API_BASEURL, uri]];
	spec.isPostMethod = YES;
	spec.resultType = HQRT_JSON;

	return spec;
}

- (HttpQuerySpec*)getSpecForPage:(int)pageId ofVolume:(int)volumeId
{
	HttpQuerySpec* spec = [[HttpQuerySpec alloc] init];

	spec.address = @"comic.ogp.kr";
	spec.path = [NSString stringWithFormat:@"/pic/%@/%d/%d", m_sessKey, volumeId, pageId];
	spec.resultType = HQRT_BINARY;
	spec.isNotifyOnNetThread = YES;
	
	NSTRACE(@"PicPath: %@", spec.path);
	return spec;
}

- (void)sendRequest:(HttpQuerySpec*)spec withJobID:(int)jobId delegate:(id<ApiResultDelegate>)resDelegate
{
	spec.userObj = resDelegate;
	[GetHttpMan() request:jobId forSpec:spec delegate:self];
}

static NSString* getDeviceName()
{
	return (GetAppDelegate().isIpad) ? @"iPad" : @"iPhone";
}

- (void)requestVersionInfo:(id<ApiResultDelegate>)resDelegate
{
	HttpQuerySpec* spec = [self getEmptySpec:"v1/version/ios"];
	[spec addValue:getDeviceName() forKey:@"dev"];
	[spec addValue:[[UIDevice currentDevice] systemVersion] forKey:@"ver"];

	[self sendRequest:spec withJobID:JOBID_VERSION_INFO delegate:resDelegate];
}

- (id)parseClientVersion:(NSDictionary*)json
{
	API_VersionResult* res = [API_VersionResult new];
	res.appVersion = [json objectForKey:@"app"];
	return res;
}

- (void)requestLoginEmail:(NSString*)email withFbObjId:(NSString*)fbId delegate:(id<ApiResultDelegate>)resDelegate
{
	NSData* dataEmail = [email dataUsingEncoding:NSUTF8StringEncoding];
	NSData* emailEnc = [m_cipher encrypt:dataEmail];
	NSString* emailHex = toHexString((Byte*)emailEnc.bytes, emailEnc.length);

	HttpQuerySpec* spec = [self getEmptySpec:"v1/user/login"];
	[spec addValue:emailHex forKey:@"email"];
	[spec addValue:fbId forKey:@"fbid"];

	[self sendRequest:spec withJobID:JOBID_LOGIN_FACEBOOK delegate:resDelegate];
}

- (id)parseLoginResult:(NSDictionary*)json
{
	API_LoginResult* res = [API_LoginResult new];
	res.sessKey = [json objectForKey:@"sess_key"];
	res.level = [[json objectForKey:@"level"] intValue];
	
	m_sessKey = res.sessKey;
	return res;
}

- (void)requestRegisterUser:(NSString*)name withEmail:(NSString*)email andFbObjId:(NSString*)fbId andProfileUrl:(NSString*)profileUrl delegate:(id<ApiResultDelegate>)resDelegate
{
	if (profileUrl == nil)
		profileUrl = @"http://nil";

	NSData* dataEmail = [email dataUsingEncoding:NSUTF8StringEncoding];
	NSData* emailEnc = [m_cipher encrypt:dataEmail];
	NSString* emailHex = toHexString((Byte*)emailEnc.bytes, emailEnc.length);

	NSData* dataUrl = [profileUrl dataUsingEncoding:NSUTF8StringEncoding];
	NSData* urlEnc = [m_cipher encrypt:dataUrl];
	NSString* urlHex = toHexString((Byte*)urlEnc.bytes, urlEnc.length);

	HttpQuerySpec* spec = [self getEmptySpec:"v1/user/register"];
	[spec addValue:name forKey:@"name"];
	[spec addValue:emailHex forKey:@"email"];
	[spec addValue:fbId forKey:@"fbid"];
	[spec addValue:urlHex forKey:@"url"];

	[self sendRequest:spec withJobID:JOBID_REGISTER_FBUSER delegate:resDelegate];
}

- (void)requestDirectoryList:(int)folderId delegate:(id<ApiResultDelegate>)resDelegate
{
	HttpQuerySpec* spec = [self getEmptySpec:"v1/directory"];
	[spec addValue:[NSString stringWithFormat:@"%d", folderId] forKey:@"fid"];
	[spec addValue:m_sessKey forKey:@"sid"];
	
	[self sendRequest:spec withJobID:JOBID_DIRECTORY_LIST delegate:resDelegate];
}

- (id)parseDirectoryList:(NSDictionary*)json withSpec:(HttpQuerySpec*)spec
{
	API_DirListResult* res = [API_DirListResult new];
	res.folderId = [[spec getParamForKey:@"fid"] intValue];
	
	NSArray* dirs = [json objectForKey:@"dirs"];
	NSArray* titles = [json objectForKey:@"titles"];
	
	NSUInteger numDirs = dirs.count;
	if (numDirs > 0)
	{
		NSMutableArray* arrFolders = [[NSMutableArray alloc] initWithCapacity:numDirs];
		for (NSDictionary* dirJson in dirs)
		{
			API_DirFolder* fitem = [API_DirFolder new];
			fitem.folderId = [[dirJson objectForKey:@"_id"] intValue];
			fitem.name = [dirJson objectForKey:@"name"];
			
			[arrFolders addObject:fitem];
		}
		
		res.folders = arrFolders;
	}
	
	NSUInteger numTitles = titles.count;
	if (numTitles > 0)
	{
		NSMutableArray* arrTitles = [[NSMutableArray alloc] initWithCapacity:numTitles];
		for (NSDictionary* titleJson in titles)
		{
			API_DirTitle* titem = [API_DirTitle new];
			titem.titleId = [[titleJson objectForKey:@"title_id"] intValue];
			titem.nameKor = [titleJson objectForKey:@"name_kor"];
			titem.completed = [[titleJson objectForKey:@"completed"] intValue] != 0;
			titem.authorName = [titleJson stringForKey:@"author_name"];
			[arrTitles addObject:titem];
		}
		
		res.titles = arrTitles;
	}
	
	return res;
}

- (void)requestTitleInfo:(int)titleId delegate:(id<ApiResultDelegate>)resDelegate
{
	HttpQuerySpec* spec = [self getEmptySpec:"v1/title"];
	[spec addValue:[NSString stringWithFormat:@"%d", titleId] forKey:@"tid"];
	[spec addValue:m_sessKey forKey:@"sid"];

	[self sendRequest:spec withJobID:JOBID_TITLE_INFO delegate:resDelegate];
}

- (id)parseTitleInfo:(NSDictionary*)json withSpec:(HttpQuerySpec*)spec
{
	API_TitleInfo* res = [API_TitleInfo new];
	res.titleId = [[spec getParamForKey:@"tid"] intValue];
	
	NSDictionary* info = [json objectForKey:@"info"];
	res.nameKor = [info objectForKey:@"name_kor"];
	res.nameOrig = [info objectForKey:@"name_orig"];
	res.completed = [[info objectForKey:@"completed"] intValue] != 0;
	res.authorName = [info stringForKey:@"author_name"];
	res.authorId = [[info stringForKey:@"author_id"] intValue];
	
	NSString* strVols =[json objectForKey:@"volumes"];
	NSArray* arr = [strVols componentsSeparatedByString:@" "];
	NSMutableArray* marr = [[NSMutableArray alloc] initWithCapacity:[arr count]];
	for (NSString* vol in arr)
	{
		NSArray* comp = [vol componentsSeparatedByString:@":"];
		API_VolumeInfo* vi = [API_VolumeInfo new];
		vi.seqNum = [[comp objectAtIndex:0] intValue];
		vi.volumeId = [[comp objectAtIndex:1] intValue];
		[marr addObject:vi];
	}
	res.volumes = marr;
	
	return res;
}

- (void)requestVolumeInfo:(int)volumeId delegate:(id<ApiResultDelegate>)resDelegate
{
	HttpQuerySpec* spec = [self getEmptySpec:"v1/volume"];
	[spec addValue:[NSString stringWithFormat:@"%d", volumeId] forKey:@"vid"];
	[spec addValue:m_sessKey forKey:@"sid"];

	[self sendRequest:spec withJobID:JOBID_VOLUME_INFO delegate:resDelegate];
}

- (id)parseVolumeInfo:(NSDictionary*)json withSpec:(HttpQuerySpec*)spec
{
	API_VolumeInfo* res = [API_VolumeInfo new];
	res.volumeId = [[spec getParamForKey:@"vid"] intValue];
	res.isReverseDir = [[json objectForKey:@"reverse_dir"] intValue] != 0;
	res.isTwoPaged = [[json objectForKey:@"two_paged"] intValue] != 0;
	
	NSString* strPages =[json objectForKey:@"pages"];
	NSArray* arr = [strPages componentsSeparatedByString:@" "];
	NSMutableArray* marr = [[NSMutableArray alloc] initWithCapacity:[arr count]];
	for (NSString* page in arr)
	{
		NSArray* comp = [page componentsSeparatedByString:@":"];
		API_PageInfo* pi = [API_PageInfo new];
		pi.pageId = [[comp objectAtIndex:0] intValue];
		pi.fileFormat = (char) [[comp objectAtIndex:1] characterAtIndex:0];
		[marr addObject:pi];
	}
	res.pages = marr;
	
	return res;
}

- (void)notifyJob:(int)jobId failureCode:(NSString*)errCode andMessage:(NSString*)errMsg delegate:(id<ApiResultDelegate>)resDelegate
{
	if (resDelegate == nil)
		return;
		
	BOOL handled;
	if ([resDelegate respondsToSelector:@selector(onApi:failedWithErrorCode:andMessage:)])
	{
		handled = [resDelegate onApi:jobId failedWithErrorCode:errCode andMessage:errMsg];
	}
	else
	{
		handled = NO;
	}
	
	if (!handled)
	{
		if ([errCode isEqualToString:@"INVALID_SESSION"])
		{
			[GetAppDelegate() onSessionInvalidated];
			return;
		}
		
		if ([errCode isEqualToString:@"NETWORK_ERROR"])
		{
			errMsg = @"인터넷에 연결할 수 없습니다.";
		}
		
		UIAlertView* alert = [[UIAlertView alloc] initWithTitle:errCode
			message:errMsg delegate:nil cancelButtonTitle:GetLocalizedString(@"ok") otherButtonTitles:nil];
		[alert show];
	}
}

- (void)httpQueryJob:(int)jobId didFailWithStatus:(NSInteger)status forSpec:(HttpQuerySpec*)spec
{
	NSTRACE(@"ApiSvc: job#%d didFailWithStatus %d", jobId, (int)status);
	
	NSString *errCode, *errMsg;
	if (status < 0)
	{
		errCode = @"NETWORK_ERROR";
	}
	else
	{
		errCode = @"API Query Failure";
	}
	
	errMsg = [NSString stringWithFormat:@"%d", (int)status];

	[self notifyJob:jobId failureCode:errCode andMessage:errMsg delegate:(id<ApiResultDelegate>)spec.userObj];
}

- (void)httpQueryJob:(int)jobId didSucceedWithResult:(id)result forSpec:(HttpQuerySpec*)spec
{
//	NSTRACE(@"ApiSvc: job#%d didSucceedWithResult %@", jobId, result);

	if (spec.resultType != HQRT_JSON)
	{
		[self notifyJob:(int)jobId failureCode:@"NoJSON" andMessage:@"Invalid protocol" delegate:(id<ApiResultDelegate>)spec.userObj];
		return;
	}

	NSDictionary* dicJson = (NSDictionary*)result;
	NSString* res = [dicJson objectForKey:@"result"];
	if (![res isEqualToString:@"OK"])
	{
		NSString* errMsg = [dicJson objectForKey:@"error"];
		[self notifyJob:jobId failureCode:res andMessage:errMsg delegate:(id<ApiResultDelegate>)spec.userObj];
		return;
	}

	id<ApiResultDelegate> delegate = (id<ApiResultDelegate>) spec.userObj;
	if (delegate == nil)
	{
		NSTRACE(@"Succeeded Job #%d, lsnr is nil", jobId);
		return;
	}

	dicJson = [dicJson objectForKey:@"data"];
	switch (jobId)
	{
	case JOBID_VERSION_INFO:
		[delegate onApi:jobId result:[self parseClientVersion:dicJson]];
		return;
		
	case JOBID_DIRECTORY_LIST:
		[delegate onApi:jobId result:[self parseDirectoryList:dicJson withSpec:spec]];
		return;

	case JOBID_TITLE_INFO:
		[delegate onApi:jobId result:[self parseTitleInfo:dicJson withSpec:spec]];
		return;

	case JOBID_VOLUME_INFO:
		[delegate onApi:jobId result:[self parseVolumeInfo:dicJson withSpec:spec]];
		return;
		
	case JOBID_LOGIN_FACEBOOK:
	case JOBID_REGISTER_FBUSER:
		[delegate onApi:jobId result:[self parseLoginResult:dicJson]];
		return;

	default:
		[self notifyJob:jobId failureCode:@"UNKNOWN" andMessage:[NSString stringWithFormat:@"Unknown JobID %d", jobId] delegate:(id<ApiResultDelegate>)spec.userObj];
		break;
	}
}


@end
