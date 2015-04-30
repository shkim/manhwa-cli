#import <Foundation/Foundation.h>

@interface AES256Cipher : NSObject

- (id)initWithKey:(NSString*)key andIV:(NSString*)iv;
- (NSData*)encrypt:(NSData*)inputRaw;

@end

NSData* fromHexString(NSString* hexStr);
NSString* toHexString(Byte* p, NSUInteger len);

