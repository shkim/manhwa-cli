//
//  ApiService.h
//  manhwa
//
//  Created by shkim on 10/27/14.
//  Copyright (c) 2014 shkim. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface API_VersionResult : NSObject
@property (nonatomic, strong) NSString* appVersion;
//@property (nonatomic, strong) NSString* apiVersion;
@end

@interface API_LoginResult : NSObject
@property (nonatomic, strong) NSString* sessKey;
@property (nonatomic, assign) int level;
@end

@interface API_PageInfo : NSObject
@property (nonatomic, assign) int pageId;
@property (nonatomic, assign) char fileFormat;	// 'J':JPG
@end

@interface API_VolumeInfo : NSObject
@property (nonatomic, assign) int seqNum;
@property (nonatomic, assign) int volumeId;

@property (nonatomic, assign) BOOL isReverseDir;
@property (nonatomic, assign) BOOL isTwoPaged;
@property (nonatomic, strong) NSArray* pages; // array of API_PageInfo
@end

@interface API_TitleInfo : NSObject
@property (nonatomic, assign) int titleId;
@property (nonatomic, strong) NSString* nameKor;
@property (nonatomic, strong) NSString* nameOrig;
@property (nonatomic, strong) NSString* authorName;
@property (nonatomic, assign) int authorId;
@property (nonatomic, assign) BOOL completed;
@property (nonatomic, strong) NSArray* volumes;	// array of API_VolumeInfo (only seqNum, volumeId)
@end

@interface API_DirFolder : NSObject
@property (nonatomic, assign) int folderId;
@property (nonatomic, strong) NSString* name;
@end

@interface API_DirTitle : NSObject
@property (nonatomic, assign) int titleId;
@property (nonatomic, strong) NSString* nameKor;
@property (nonatomic, assign) BOOL completed;
@property (nonatomic, strong) NSString* authorName;
@end

@interface API_DirListResult : NSObject
@property (nonatomic, assign) int folderId;		// id of this directory
@property (nonatomic, strong) NSArray* folders;	// array of API_DirFolder
@property (nonatomic, strong) NSArray* titles;	// array of API_DirTitle
@end

// HTTP Job IDs -->
#define JOBID_VERSION_INFO				1
#define JOBID_LOGIN_FACEBOOK			2
#define JOBID_REGISTER_FBUSER			3

#define JOBID_DIRECTORY_LIST			11
#define JOBID_TITLE_INFO				12
#define JOBID_VOLUME_INFO				13

#define JOBID_GET_IMAGE					100

@protocol ApiResultDelegate <NSObject>

@optional
- (BOOL)onApi:(int)jobId failedWithErrorCode:(NSString*)errCode andMessage:(NSString*)errMsg;
@required
- (void)onApi:(int)jobId result:(id)_param;

@end

@class HttpQuerySpec;

@interface ApiService : NSObject

//- (void)setApnsToken:(NSString*)token;
- (HttpQuerySpec*)getSpecForPage:(int)pageId ofVolume:(int)volumeId;

- (void)requestVersionInfo:(id<ApiResultDelegate>)resDelegate;
- (void)requestLoginEmail:(NSString*)email withFbObjId:(NSString*)fbId delegate:(id<ApiResultDelegate>)resDelegate;
- (void)requestRegisterUser:(NSString*)name withEmail:(NSString*)email andFbObjId:(NSString*)fbId andProfileUrl:(NSString*)profileUrl delegate:(id<ApiResultDelegate>)resDelegate;
- (void)requestDirectoryList:(int)folderId delegate:(id<ApiResultDelegate>)resDelegate;
- (void)requestTitleInfo:(int)titleId delegate:(id<ApiResultDelegate>)resDelegate;
- (void)requestVolumeInfo:(int)volumeId delegate:(id<ApiResultDelegate>)resDelegate;

@end
