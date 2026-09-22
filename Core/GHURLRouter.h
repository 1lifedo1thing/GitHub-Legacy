
#import <Foundation/Foundation.h>

@interface GHURLRouter : NSObject

+ (BOOL)routeGitHubURL:(NSURL *)url fromViewController:(UIViewController *)viewController;

+ (NSURL *)gitHubURLFromAppURL:(NSURL *)appURL;

+ (BOOL)userProfileInfoFromURL:(NSURL *)url login:(NSString **)login;

@end
