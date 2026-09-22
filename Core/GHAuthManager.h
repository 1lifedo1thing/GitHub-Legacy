#import <Foundation/Foundation.h>

@interface GHAuthManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic, readonly) NSString *accessToken;
@property (nonatomic, readonly) BOOL isAuthenticated;
@property (nonatomic, copy) NSString *currentUserLogin;

- (void)setAccessToken:(NSString *)token;
- (void)logout;

@end
