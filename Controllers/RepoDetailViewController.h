#import <UIKit/UIKit.h>

@interface RepoDetailViewController : UITableViewController

@property (nonatomic, copy) NSString *ownerLogin;
@property (nonatomic, copy) NSString *repoName;

+ (BOOL)releaseListInfoFromURL:(NSURL *)url
                     ownerLogin:(NSString **)ownerLogin
                       repoName:(NSString **)repoName;

+ (BOOL)latestReleaseInfoFromURL:(NSURL *)url
                       ownerLogin:(NSString **)ownerLogin
                         repoName:(NSString **)repoName;

+ (void)pushLatestReleaseForOwnerLogin:(NSString *)ownerLogin
                                repoName:(NSString *)repoName
                      fromViewController:(UIViewController *)fromViewController;

+ (BOOL)releaseByTagInfoFromURL:(NSURL *)url
                      ownerLogin:(NSString **)ownerLogin
                        repoName:(NSString **)repoName
                             tag:(NSString **)tag;

+ (void)pushReleaseForOwnerLogin:(NSString *)ownerLogin
                          repoName:(NSString *)repoName
                               tag:(NSString *)tag
                fromViewController:(UIViewController *)fromViewController;

@end
