//
//  AES256Cipher.m
//
//  Created by shkim on 3/18/14.
//  Copyright (c) 2014 shkim. All rights reserved.
//

#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonKeyDerivation.h>
#import <CommonCrypto/CommonDigest.h>

#import "AES256Cipher.h"

@interface AES256Cipher ()
{
	NSData* m_key;
	NSData* m_iv;
}

@end

int charToHex(int ch)
{
	if (ch >= '0' && ch <= '9')
	{
		return (ch - '0');
	}
	
	if (ch >= 'a' && ch <= 'f')
	{
		return (ch - 'a') + 0xA;
	}
	
	if (ch >= 'A' && ch <= 'F')
	{
		return (ch - 'A') + 0xA;
	}
	
	NSTRACE(@"Invalid hex char: %c (code=%d)", ch, ch);
	return 0;
}

NSData* fromHexString(NSString* hexStr)
{
	NSUInteger len = [hexStr length] / 2;
	
	NSMutableData* ret = [NSMutableData dataWithLength:len];
	Byte* buf = (Byte*)ret.mutableBytes;
	
	for (NSUInteger i=0; i<len; i++)
	{
		int hi4 = [hexStr characterAtIndex:(i*2)];
		int lo4 = [hexStr characterAtIndex:(i*2)+1];
		
		buf[i] = (charToHex(hi4) << 4) | charToHex(lo4);
	}
	
	return ret;
}

NSString* toHexString(Byte* p, NSUInteger len)
{
	NSMutableString *output = [NSMutableString stringWithCapacity:len * 2];

	for(NSUInteger i=0; i<len; i++)
		[output appendFormat:@"%02x", p[i]];
 
	return output;
}

NSString* digestMD5(NSString* rawPassword)
{
	NSString* input = [NSString stringWithFormat:@"shzhem%@", rawPassword];
	const char* pszInput = [input UTF8String];

	unsigned char digest[CC_MD5_DIGEST_LENGTH];
	CC_MD5(pszInput, (int)strlen(pszInput), digest);
	
	return toHexString(digest, CC_MD5_DIGEST_LENGTH);
}

@implementation AES256Cipher

- (id)initWithKey:(NSString*)key andIV:(NSString*)iv
{
	self = [super init];
	if (self)
	{
		m_key = fromHexString(key);
		m_iv = fromHexString(iv);
	}
	
	return self;
}

- (NSData*)encrypt:(NSData*)inputRaw
{
	size_t outLength;
	NSMutableData* outBuf = [NSMutableData dataWithLength:inputRaw.length + kCCBlockSizeAES128 + 16];
	
	CCCryptorStatus result = CCCrypt(kCCEncrypt,
		kCCAlgorithmAES128, kCCOptionPKCS7Padding,
		m_key.bytes, m_key.length, // keylen=32
		m_iv.bytes, // initialization vector (len=16)
		inputRaw.bytes, inputRaw.length,
		outBuf.mutableBytes, outBuf.length,
		&outLength);

	if (result == kCCSuccess)
	{
		outBuf.length = outLength;
		return outBuf;
	}
	else
	{
		NSTRACE(@"CCCrypt failed: %d", result);
		return nil;
	}
}

@end
