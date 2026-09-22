#import "RepoDetailViewController.h"
#import "GHCompat.h"
#import "GHLegacyRefreshControl.h"
#import "GHAPIClient.h"
#import "ReleaseDetailViewController.h"
#import "GHThemeManager.h"
#import "GHLocalization.h"

@interface RepoDetailViewController ()
@property (nonatomic, strong) NSMutableArray *releases;
@end

@interface RepoDetailViewController (GHReleaseRouting)
+ (void)pushTopOfReleasesListForOwnerLogin:(NSString *)ownerLogin
                                   repoName:(NSString *)repoName
                         fromViewController:(UIViewController *)fromViewController;
+ (void)pushReleaseDetailForRelease:(NSDictionary *)release
                          ownerLogin:(NSString *)ownerLogin
                            repoName:(NSString *)repoName
                  fromViewController:(UIViewController *)fromViewController;
@end

@implementation RepoDetailViewController

+ (BOOL)releaseListInfoFromURL:(NSURL *)url
                     ownerLogin:(NSString **)ownerLogin
                       repoName:(NSString **)repoName {
    if (url == nil) return NO;
    static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:
            @"^https?://github\\.com/([^/]+)/([^/]+)/releases(?:[/?#].*)?$"
                                                            options:NSRegularExpressionCaseInsensitive
                                                              error:nil];
    });
    NSString *urlString = url.absoluteString;
    NSTextCheckingResult *match = [regex firstMatchInString:urlString options:0 range:NSMakeRange(0, urlString.length)];
    if (match == nil) return NO;

    if (ownerLogin != NULL) *ownerLogin = [urlString substringWithRange:[match rangeAtIndex:1]];
    if (repoName != NULL) *repoName = [urlString substringWithRange:[match rangeAtIndex:2]];
    return YES;
}

- (id)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _releases = [NSMutableArray array];

        self.title = GHL(@"Релизы");
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (GHPullToRefreshAvailable()) {
        self.refreshControl = [[UIRefreshControl alloc] init];
        [self.refreshControl addTarget:self action:@selector(loadReleases) forControlEvents:UIControlEventValueChanged];
    } else {
        self.gh_legacyRefreshControl = [GHLegacyRefreshControl gh_attachToScrollView:self.tableView];
        [self.gh_legacyRefreshControl addTarget:self action:@selector(loadReleases) forControlEvents:UIControlEventValueChanged];
    }

    [self loadReleases];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(applyTheme)
                                                  name:kGHThemeDidChangeNotification
                                                object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(handleLanguageDidChange)
                                                  name:kGHLanguageDidChangeNotification
                                                object:nil];
    [self applyTheme];
}

- (void)handleLanguageDidChange {
    self.title = GHL(@"Релизы");
    [self.tableView reloadData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applyTheme {
    self.tableView.backgroundColor = GHBackgroundColor();

    self.tableView.backgroundView = nil;
    self.tableView.separatorColor = GHSeparatorColor();
    [self.tableView reloadData];
}

- (void)loadReleases {
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [spinner startAnimating];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:spinner];

    __weak typeof(self) weakSelf = self;
    [[GHAPIClient sharedClient] releasesForOwner:self.ownerLogin repo:self.repoName completion:^(id jsonObject, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.navigationItem.rightBarButtonItem = nil;
        if (GHPullToRefreshAvailable()) { [strongSelf.refreshControl endRefreshing]; } else { [strongSelf.gh_legacyRefreshControl endRefreshing]; }

        if (error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:GHL(@"Ошибка")
                                                             message:error.localizedDescription
                                                            delegate:nil
                                                   cancelButtonTitle:@"OK"
                                                   otherButtonTitles:nil];
            [alert show];
            return;
        }

        if ([jsonObject isKindOfClass:[NSArray class]]) {
            [strongSelf.releases removeAllObjects];
            [strongSelf.releases addObjectsFromArray:jsonObject];
        }
        [strongSelf.tableView reloadData];
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.releases.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ReleaseCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ReleaseCell"];
    }
    cell.backgroundColor = GHCellBackgroundColor();
    NSDictionary *release = self.releases[indexPath.row];

    id nameValue = release[@"name"];
    id tagValue = release[@"tag_name"];
    NSString *releaseName = [nameValue isKindOfClass:[NSString class]] ? nameValue : nil;
    NSString *tagName = [tagValue isKindOfClass:[NSString class]] ? tagValue : nil;

    cell.textLabel.text = releaseName.length > 0 ? releaseName : (tagName ?: GHL(@"Без названия"));
    cell.textLabel.textColor = GHPrimaryTextColor();
    NSArray *assets = [release[@"assets"] isKindOfClass:[NSArray class]] ? release[@"assets"] : @[];

    long long totalBytes = 0;
    for (NSDictionary *asset in assets) {
        if (![asset isKindOfClass:[NSDictionary class]]) continue;
        NSNumber *size = asset[@"size"];
        if ([size isKindOfClass:[NSNumber class]]) totalBytes += size.longLongValue;
    }
    if (totalBytes > 0) {
        double totalMB = (double)totalBytes / (1024.0 * 1024.0);
        cell.detailTextLabel.text = [NSString stringWithFormat:GHL(@"%lu файл(ов) · %.2f МБ"),
                                                                 (unsigned long)assets.count, totalMB];
    } else {

        cell.detailTextLabel.text = [NSString stringWithFormat:GHL(@"%lu файл(ов)"), (unsigned long)assets.count];
    }
    cell.detailTextLabel.textColor = GHSecondaryTextColor();
    GHApplyDisclosureIndicator(cell);

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *release = self.releases[indexPath.row];
    id tagValue = release[@"tag_name"];

    ReleaseDetailViewController *detailVC = [[ReleaseDetailViewController alloc] init];
    detailVC.releaseInfo = release;
    detailVC.ownerLogin = self.ownerLogin;
    detailVC.repoName = self.repoName;
    detailVC.title = [tagValue isKindOfClass:[NSString class]] ? tagValue : GHL(@"Релиз");

    [self.navigationController pushViewController:detailVC animated:YES];
}

+ (BOOL)latestReleaseInfoFromURL:(NSURL *)url
                       ownerLogin:(NSString **)ownerLogin
                         repoName:(NSString **)repoName {
    if (url == nil) return NO;
    static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:
            @"^https?://github\\.com/([^/]+)/([^/]+)/releases/latest/?(?:[?#].*)?$"
                                                            options:NSRegularExpressionCaseInsensitive
                                                              error:nil];
    });
    NSString *urlString = url.absoluteString;
    NSTextCheckingResult *match = [regex firstMatchInString:urlString options:0 range:NSMakeRange(0, urlString.length)];
    if (match == nil) return NO;

    if (ownerLogin != NULL) *ownerLogin = [urlString substringWithRange:[match rangeAtIndex:1]];
    if (repoName != NULL) *repoName = [urlString substringWithRange:[match rangeAtIndex:2]];
    return YES;
}

+ (void)pushLatestReleaseForOwnerLogin:(NSString *)ownerLogin
                                repoName:(NSString *)repoName
                      fromViewController:(UIViewController *)fromViewController {
    __weak UIViewController *weakFromVC = fromViewController;

    [[GHAPIClient sharedClient] latestReleaseForOwner:ownerLogin
                                                   repo:repoName
                                             completion:^(id jsonObject, NSError *error) {
        __strong UIViewController *strongFromVC = weakFromVC;
        if (!strongFromVC) return;

        NSDictionary *release = [jsonObject isKindOfClass:[NSDictionary class]] ? jsonObject : nil;
        if (error || release == nil) {
            [self pushTopOfReleasesListForOwnerLogin:ownerLogin repoName:repoName fromViewController:strongFromVC];
            return;
        }

        [self pushReleaseDetailForRelease:release ownerLogin:ownerLogin repoName:repoName fromViewController:strongFromVC];
    }];
}

+ (void)pushTopOfReleasesListForOwnerLogin:(NSString *)ownerLogin
                                   repoName:(NSString *)repoName
                         fromViewController:(UIViewController *)fromViewController {
    __weak UIViewController *weakFromVC = fromViewController;

    [[GHAPIClient sharedClient] releasesForOwner:ownerLogin
                                             repo:repoName
                                       completion:^(id jsonObject, NSError *error) {
        __strong UIViewController *strongFromVC = weakFromVC;
        if (!strongFromVC) return;

        NSArray *releases = [jsonObject isKindOfClass:[NSArray class]] ? jsonObject : nil;
        NSDictionary *topRelease = releases.count > 0 && [releases[0] isKindOfClass:[NSDictionary class]] ? releases[0] : nil;

        if (topRelease == nil) {
            RepoDetailViewController *listVC = [[RepoDetailViewController alloc] init];
            listVC.ownerLogin = ownerLogin;
            listVC.repoName = repoName;
            listVC.title = GHL(@"Релизы");
            [strongFromVC.navigationController pushViewController:listVC animated:YES];
            return;
        }

        [self pushReleaseDetailForRelease:topRelease ownerLogin:ownerLogin repoName:repoName fromViewController:strongFromVC];
    }];
}

+ (void)pushReleaseDetailForRelease:(NSDictionary *)release
                          ownerLogin:(NSString *)ownerLogin
                            repoName:(NSString *)repoName
                  fromViewController:(UIViewController *)fromViewController {
    id tagValue = release[@"tag_name"];
    ReleaseDetailViewController *detailVC = [[ReleaseDetailViewController alloc] init];
    detailVC.releaseInfo = release;
    detailVC.ownerLogin = ownerLogin;
    detailVC.repoName = repoName;
    detailVC.title = [tagValue isKindOfClass:[NSString class]] ? tagValue : GHL(@"Релиз");
    [fromViewController.navigationController pushViewController:detailVC animated:YES];
}

+ (BOOL)releaseByTagInfoFromURL:(NSURL *)url
                      ownerLogin:(NSString **)ownerLogin
                        repoName:(NSString **)repoName
                             tag:(NSString **)tag {
    if (url == nil) return NO;
    static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:
            @"^https?://github\\.com/([^/]+)/([^/]+)/releases/tag/([^/?#]+)/?(?:[?#].*)?$"
                                                            options:NSRegularExpressionCaseInsensitive
                                                              error:nil];
    });
    NSString *urlString = url.absoluteString;
    NSTextCheckingResult *match = [regex firstMatchInString:urlString options:0 range:NSMakeRange(0, urlString.length)];
    if (match == nil) return NO;

    if (ownerLogin != NULL) *ownerLogin = [urlString substringWithRange:[match rangeAtIndex:1]];
    if (repoName != NULL) *repoName = [urlString substringWithRange:[match rangeAtIndex:2]];
    if (tag != NULL) {
        NSString *rawTag = [urlString substringWithRange:[match rangeAtIndex:3]];
        *tag = [rawTag stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] ?: rawTag;
    }
    return YES;
}

+ (void)pushReleaseForOwnerLogin:(NSString *)ownerLogin
                          repoName:(NSString *)repoName
                               tag:(NSString *)tag
                fromViewController:(UIViewController *)fromViewController {
    __weak UIViewController *weakFromVC = fromViewController;

    [[GHAPIClient sharedClient] releaseForOwner:ownerLogin
                                            repo:repoName
                                             tag:tag
                                      completion:^(id jsonObject, NSError *error) {
        __strong UIViewController *strongFromVC = weakFromVC;
        if (!strongFromVC) return;

        NSDictionary *release = [jsonObject isKindOfClass:[NSDictionary class]] ? jsonObject : nil;
        if (error || release == nil) {
            RepoDetailViewController *listVC = [[RepoDetailViewController alloc] init];
            listVC.ownerLogin = ownerLogin;
            listVC.repoName = repoName;
            listVC.title = GHL(@"Релизы");
            [strongFromVC.navigationController pushViewController:listVC animated:YES];
            return;
        }

        ReleaseDetailViewController *detailVC = [[ReleaseDetailViewController alloc] init];
        detailVC.releaseInfo = release;
        detailVC.ownerLogin = ownerLogin;
        detailVC.repoName = repoName;
        detailVC.title = tag;
        [strongFromVC.navigationController pushViewController:detailVC animated:YES];
    }];
}

@end
