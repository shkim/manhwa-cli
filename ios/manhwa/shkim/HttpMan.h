//
//  HttpMan.h
//  Created by shkim
//

#import <Foundation/Foundation.h>

typedef enum
{
	HQRT_IGNORE,
	HQRT_TEXT,
	HQRT_JSON,
	HQRT_BINARY,
	HQRT_BINARY_WITH_PROGRESS,
	HQRT_FILE_WITH_PROGRESS
} HttpQueryResultType;

@interface HttpQuerySpec : NSObject
{
	NSMutableDictionary* m_dicParams;
	NSMutableDictionary* m_dicUserVars;
}

@property (nonatomic, assign) int port;		// can be 0 if 80
@property (nonatomic, assign) BOOL isSecure;	// YES if HTTPS
@property (nonatomic, assign) BOOL isPostMethod;
@property (nonatomic, assign) BOOL isNotifyOnNetThread;
@property (nonatomic, assign) BOOL isIgnoreCache;
@property (nonatomic, assign) HttpQueryResultType resultType;

@property (nonatomic, strong) NSString* address;
@property (nonatomic, strong) NSString* path;
@property (nonatomic, strong) NSObject* userObj;

- (void)setUrl:(NSString*)url;
- (void)addValue:(NSString*)value forKey:(NSString*)key;	// TODO: addValue --> addParam
- (NSDictionary*)getParams;
- (NSString*)getParamForKey:(NSString*)key;

- (void)addUserVar:(NSString*)value forKey:(NSString*)key;
- (NSString*)getUserVarForKey:(NSString*)key;

@end

@interface HttpFileDownloadResult : NSObject
@property (nonatomic, assign) NSUInteger length;
@property (nonatomic, strong) NSString* pathname;
@end

@protocol HttpQueryDelegate <NSObject>

- (void)httpQueryJob:(int)jobId didFailWithStatus:(NSInteger)status forSpec:(HttpQuerySpec*)spec;
- (void)httpQueryJob:(int)jobId didSucceedWithResult:(id)result forSpec:(HttpQuerySpec*)spec;

@optional
- (void)httpQueryJob:(int)jobId progressSoFar:(NSUInteger)current progressTotal:(NSUInteger)total forSpec:(HttpQuerySpec*)spec;

@end

@class HttpQueryJob;

@interface HttpMan : NSObject

//- (void)postSignal:(int)jobId withObject:(id)userObj notifyOnNetThread:(BOOL)notifyOnNT delegate:(id<HttpQueryDelegate>)theDelegate;
- (void)request:(int)jobId forSpec:(HttpQuerySpec*)theSpec delegate:(id<HttpQueryDelegate>)theDelegate;
- (void)download:(int)jobId atPath:(NSString*)path forSpec:(HttpQuerySpec*)theSpec delegate:(id<HttpQueryDelegate>)theDelegate;
- (void)cancelJob:(int)jobId;

@end
