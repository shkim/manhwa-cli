//
// HttpMan.m - Created by shkim
// For WorldMetro since 2011-12-22: Created
// For TourZine since 2012-06-29: File download support
// For SleekApp since 2013-05-16: ARC support
// For Kartooncup since 2013-10-13: JSON lib change, QuerySpec.userVar added
//	2013-12-05 HttpFileDownloadResult added

#import "HttpMan.h"
#import "AppDelegate.h"
#import <Foundation/NSJSONSerialization.h>

@implementation HttpFileDownloadResult
@end

@interface HttpMan ()
{
	NSMutableSet* m_jobs;
	NSMutableDictionary* m_dicJobs;
	NSOperationQueue* m_opQueue;
}

- (void)addDownloadCompletedJob:(HttpQueryJob*)job;
- (void)decreaseNetworkJob:(HttpQueryJob*)job;

@end

@implementation HttpQuerySpec

- (void)setUrl:(NSString*)url
{
	NSRange r1 = [url rangeOfString:@"://"];
	if (r1.length == 0)
	{
		NSTRACE(@"Invalid http url: %@", url);
		return;
	}
	
	self.isSecure = ([url characterAtIndex:r1.location -1] == 's');
	
	NSRange rCore;
	rCore.location = r1.location+3;
	rCore.length = [url length] - rCore.location;
	
	NSRange rUri = [url rangeOfString:@"/" options:NSLiteralSearch range:rCore];
	if (rUri.length == 0)
	{
		// has no uri
		self.path = nil;
	}
	else
	{
		self.path = [url substringFromIndex:rUri.location];
		rCore.length = rUri.location - rCore.location;
	}
	
	NSRange rColon = [url rangeOfString:@":" options:NSLiteralSearch range:rCore];
	if (rColon.length == 0)
	{
		self.port = 0;	// default http port (80)
	}
	else
	{
		rColon.location += 1;
		rColon.length = (rCore.location + rCore.length) - rColon.location;
		self.port = [[url substringWithRange:rColon] intValue];
		
		rCore.length = rColon.location - rCore.location -1;
	}
	
	self.address = [url substringWithRange:rCore];
}

- (void)addValue:(NSString*)value forKey:(NSString*)key
{
	if (m_dicParams == nil)
	{
		m_dicParams = [[NSMutableDictionary alloc] init];
	}
	
	[m_dicParams setObject:value forKey:key]; 
}

- (NSDictionary*)getParams
{
	return m_dicParams;
}

- (NSString*)getParamForKey:(NSString*)key
{
	return [m_dicParams objectForKey:key];
}

- (void)addUserVar:(NSString*)value forKey:(NSString*)key
{
	if (m_dicUserVars == nil)
	{
		m_dicUserVars = [[NSMutableDictionary alloc] init];
	}
	
	[m_dicUserVars setObject:value forKey:key];
}

- (NSString*)getUserVarForKey:(NSString*)key
{
	return [m_dicUserVars objectForKey:key];
}

@end

#pragma mark --

@interface HttpQueryJob : NSOperation
{
	NSMutableData* m_receivedData;
	NSURLConnection* m_connection;
	NSInteger m_statusCode;
	int m_queryProgress;
	NSUInteger m_expectedContentLength;
	NSUInteger m_downSoFar;
	
	NSOutputStream* m_outFileStream;
	HttpFileDownloadResult* m_downJob;
	
	HttpQuerySpec* m_spec;
	HttpQueryResultType m_wantResultType;
	id<HttpQueryDelegate> m_delegate;
}

@property (nonatomic,readonly) int jobId;

- (HttpQueryJob*) initJob:(int)theJobId	forSpec:(HttpQuerySpec*)spec downloadPath:(NSString*)path delegate:(id<HttpQueryDelegate>)theDelegate;

@end

@implementation HttpQueryJob

@synthesize jobId = m_jobId;

NSString* urlEncode(NSString* srcStr)
{
	NSMutableString *output = [NSMutableString string];
	
	const unsigned char *source = (const unsigned char *)[srcStr UTF8String];
	int sourceLen = (int)strlen((const char *)source);
	for (int i = 0; i < sourceLen; ++i)
	{
		const unsigned char thisChar = source[i];
		if (thisChar == ' ')
		{
			[output appendString:@"+"];
		}
		else if (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' ||
			(thisChar >= 'a' && thisChar <= 'z') ||
			(thisChar >= 'A' && thisChar <= 'Z') ||
			(thisChar >= '0' && thisChar <= '9'))
		{
			[output appendFormat:@"%c", thisChar];
		}
		else
		{
			[output appendFormat:@"%%%02X", thisChar];
		}
	}

	return output;
}

- (HttpQueryJob*) initJob:(int)theJobId	forSpec:(HttpQuerySpec*)spec downloadPath:(NSString*)downpath delegate:(id<HttpQueryDelegate>)theDelegate
{
	if (self = [super init])
	{
		NSString* formDataStr;
		NSDictionary* params = [spec getParams];
		if (params != nil)
		{
			NSMutableArray* arrVars = [[NSMutableArray alloc] initWithCapacity:[params count]];
			for(id key in params.allKeys)
			{
				NSString* value = [params objectForKey:key];
				//NSString* encoded_value = [value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
				NSString* kv = [NSString stringWithFormat:@"%@=%@", key, urlEncode(value)];
				[arrVars addObject:kv];
			}

			formDataStr = [arrVars componentsJoinedByString:@"&"];
			//TRACE(@"queryFormData: %@", formDataStr);
		}
		else
		{
			formDataStr = nil;
		}
			
		NSString* strPort = spec.port == 0 ? @"" : [NSString stringWithFormat:@":%d", spec.port];
		NSString* strUrl = [NSString stringWithFormat:@"http%@://%@%@%@",
			(spec.isSecure ? @"s" : @""), spec.address, strPort, spec.path];

		if (formDataStr != nil && !spec.isPostMethod)
		{
			strUrl = [NSString stringWithFormat:@"%@?%@", strUrl, formDataStr];
		}
		
		NSMutableURLRequest* request;
		if (spec.isIgnoreCache)
		{
			request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:strUrl]
				cachePolicy:NSURLRequestReloadIgnoringCacheData
				timeoutInterval:10.0];
		}
		else
		{
			request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:strUrl]];
		}
		  
		[request setHTTPMethod:(spec.isPostMethod ? @"POST":@"GET")];	
		
		if (spec.isPostMethod && formDataStr != nil)
		{
			[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
			NSData* formData = [formDataStr dataUsingEncoding:NSUTF8StringEncoding];
			[request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[formData length]] forHTTPHeaderField:@"Content-Length"];
			[request setHTTPBody:formData];
		}

		if (downpath != nil)
		{
			ASSERT(spec.resultType == HQRT_FILE_WITH_PROGRESS);
			m_downJob = [HttpFileDownloadResult new];
			m_downJob.pathname = downpath;
			m_outFileStream = [NSOutputStream outputStreamToFileAtPath:downpath append:NO];
			[m_outFileStream open];
		}
		else ASSERT(m_outFileStream == nil && m_downJob == nil);
		
		m_connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
		if (m_connection)
		{
			m_jobId = theJobId;
			m_spec = spec;
			m_delegate = theDelegate;
			
			m_receivedData = [NSMutableData data];
			//m_queryProgress = QP_HTTP_REQUESTED;
						
			return self;
		}
	}
		
	return nil;
}

- (NSCachedURLResponse*)connection:(NSURLConnection*)connection willCacheResponse:(NSCachedURLResponse*)cachedResponse
{
	return (m_spec.isIgnoreCache) ?	nil : cachedResponse;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)aResponse
{
	NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)aResponse;
	m_statusCode = [httpResponse statusCode];

	m_expectedContentLength = (NSUInteger) [aResponse expectedContentLength];
	m_downSoFar = 0;
	
	[m_receivedData setLength:0]; 
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	if (m_spec.resultType == HQRT_FILE_WITH_PROGRESS)
	{
		ASSERT(m_outFileStream != nil);
		NSInteger written = [m_outFileStream write:[data bytes] maxLength:[data length]];
		if (written != [data length] || [m_outFileStream hasSpaceAvailable] == NO)
		{
			[m_connection cancel];
			m_statusCode = -9;
			[self connection:m_connection didFailWithError:nil];
			return;
		}
			
		m_downSoFar += [data length];		
		[m_delegate httpQueryJob:m_jobId progressSoFar:m_downSoFar progressTotal:m_expectedContentLength forSpec:m_spec];
	}
	else
	{
		[m_receivedData appendData:data];
	
		if (m_spec.resultType == HQRT_BINARY_WITH_PROGRESS)
		{
			m_downSoFar += [data length];
			[m_delegate httpQueryJob:m_jobId progressSoFar:m_downSoFar progressTotal:m_expectedContentLength forSpec:m_spec];
		}
	}
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	NSTRACE(@"didFailWithError: %@", error);
	[GetHttpMan() decreaseNetworkJob:self];
	//NSLog(@"ServerQueryJob Error : ", [error localizedDescription]);
	if (m_statusCode == 0)
		m_statusCode = error.code;
		
	[m_delegate httpQueryJob:m_jobId didFailWithStatus:m_statusCode forSpec:m_spec];
//	[self release];
}

- (void)cancel
{
	[m_connection cancel];
	
	m_statusCode = -1;
	[self connection:m_connection didFailWithError:nil];//[NSError errorWithDomain:@"user" code:-1 userInfo:nil]];
}

- (void)notifyResult
{
	id result = nil;
			
	switch(m_spec.resultType)
	{
	case HQRT_TEXT:
		result = [[NSString alloc] initWithData:m_receivedData encoding:NSUTF8StringEncoding];
		break;
	case HQRT_BINARY:
	case HQRT_BINARY_WITH_PROGRESS:
		result = m_receivedData;
		break;
	case HQRT_FILE_WITH_PROGRESS:
		[m_outFileStream close];
		m_downJob.length = m_downSoFar;
		result = m_downJob;
		break;
		
	default:
		break;
	}
	
	[m_delegate httpQueryJob:m_jobId didSucceedWithResult:result forSpec:m_spec];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	[GetHttpMan() decreaseNetworkJob:self];
	
	if (m_statusCode >= 400)
	{
		[m_delegate httpQueryJob:m_jobId didFailWithStatus:m_statusCode forSpec:m_spec];
		return;
	}

	if (m_spec.resultType != HQRT_IGNORE)
	{
		if (m_spec.resultType == HQRT_JSON || m_spec.isNotifyOnNetThread)
		{
			[GetHttpMan() addDownloadCompletedJob:self];
		}
		else
		{
			[self notifyResult];
		}
	}
	
	//[self release];
}

- (void)handleJsonComplete:(id)json
{
	if (json == nil)
	{
		[m_delegate httpQueryJob:m_jobId didFailWithStatus:0 forSpec:m_spec];
	}
	else
	{
		[m_delegate httpQueryJob:m_jobId didSucceedWithResult:json forSpec:m_spec];		
	}
}

- (void)main
{	
	if (m_spec.resultType == HQRT_JSON)
	{
		id json = [NSJSONSerialization JSONObjectWithData:m_receivedData options:0 error:nil];
		
		if (m_spec.isNotifyOnNetThread)
		{
			[m_delegate httpQueryJob:m_jobId didSucceedWithResult:json forSpec:m_spec];
		}
		else
		{
			[self performSelectorOnMainThread:@selector(handleJsonComplete:) withObject:json waitUntilDone:NO];
		}
	}
	else
	{
		// at this point, non-JSON job is all isNotifyOnNetThread is YES.
		ASSERT(m_spec.isNotifyOnNetThread == YES);
		[self notifyResult];
	}
}

@end

#pragma mark --

@implementation HttpMan

- (id)init
{
	self = [super init];
	if (self != nil)
	{
		m_jobs = [[NSMutableSet alloc] init];
		m_dicJobs = [[NSMutableDictionary alloc] init];
		m_opQueue = [NSOperationQueue new];
	}
	
	return self;
}
/*
- (void)dealloc
{
	[m_jobs release];
	[m_dicJobs release];
	[m_opQueue release];
	
	[super dealloc];
}
*/
- (void)request:(int)theJobId forSpec:(HttpQuerySpec*)theSpec delegate:(id<HttpQueryDelegate>)theDelegate
{
	HttpQueryJob* job = [[HttpQueryJob alloc] initJob:theJobId forSpec:theSpec downloadPath:nil delegate:theDelegate];
	if (job == nil)
		return;
		
	[m_jobs addObject:job];
	[m_dicJobs setObject:job forKey:[NSNumber numberWithInt:theJobId]];
	//TRACE(@"add job %p(id=%x) now %d", job, job.jobId, [m_jobs count]);
	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)download:(int)theJobId atPath:(NSString*)path forSpec:(HttpQuerySpec*)theSpec delegate:(id<HttpQueryDelegate>)theDelegate
{
	ASSERT(theSpec.resultType == HQRT_FILE_WITH_PROGRESS);
	HttpQueryJob* job = [[HttpQueryJob alloc] initJob:theJobId forSpec:theSpec downloadPath:path delegate:theDelegate];
	if (job == nil)
		return;
		
	[m_jobs addObject:job];
	[m_dicJobs setObject:job forKey:[NSNumber numberWithInt:theJobId]];
	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)cancelJob:(int)jobId
{
	NSNumber* key = [NSNumber numberWithInt:jobId];
	HttpQueryJob* job = [m_dicJobs objectForKey:key];
	if (job != nil)
	{
		NSTRACE(@"Cancel httpQueryJob %d", job.jobId);
		[job cancel];
	}
}

- (void)decreaseNetworkJob:(HttpQueryJob*)job
{
	[m_dicJobs removeObjectForKey:[NSNumber numberWithInt:job.jobId]];	
	[m_jobs removeObject:job];
	//TRACE(@"decreaseNetworkJob %p(id=%x) now %d", job, job.jobId, [m_jobs count]);
	
	if ([m_jobs count] <= 0)
	{
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	}
}

- (void)addDownloadCompletedJob:(HttpQueryJob*)job
{
	[m_opQueue addOperation:job];	
}

@end
