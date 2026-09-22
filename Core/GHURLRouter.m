
#import "GHURLRouter.h"

#import "CommitDetailViewController.h"
#import "IssueDetailViewController.h"
#import "IssueListViewController.h"
#import "PullRequestDetailViewController.h"
#import "PullRequestListViewController.h"
#import "RepoDetailViewController.h"
#import "RepoOverviewViewController.h"
#import "CommitHistoryViewController.h"
#import "ForkListViewController.h"
#import "ReadmeViewController.h"
#import "PublicProfileViewController.h"
#import "GHLocalization.h"

@implementation GHURLRouter

+ (BOOL)isGitHubURL:(NSURL *)url {
    if (url == nil) return NO;
    NSString *scheme = url.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) return NO;

    NSString *host = url.host.lowercaseString;
    return [host isEqualToString:@"github.com"] || [host isEqualToString:@"www.github.com"];
}

+ (NSURL *)gitHubURLFromAppURL:(NSURL *)appURL {
    if (appURL == nil) return nil;

    NSString *scheme = appURL.scheme.lowercaseString;
    if (![scheme isEqualToString:@"githublegacy"]) return nil;

    NSString *urlString = appURL.absoluteString;
    NSString *schemePrefix = [NSString stringWithFormat:@"%@://", appURL.scheme];
    if (![urlString hasPrefix:schemePrefix]) return nil;

    NSString *rest = [urlString substringFromIndex:schemePrefix.length];

    NSString *pathPart = rest;
    NSString *queryPart = nil;
    NSRange queryRange = [rest rangeOfString:@"?"];
    if (queryRange.location != NSNotFound) {
        pathPart = [rest substringToIndex:queryRange.location];
        queryPart = [rest substringFromIndex:queryRange.location + 1];
    }

    NSMutableArray *segments = [NSMutableArray array];
    for (NSString *rawSegment in [pathPart componentsSeparatedByString:@"/"]) {
        NSString *decoded = [rawSegment stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if (decoded.length > 0) [segments addObject:decoded];
    }
    if (segments.count == 0) return nil;

    NSString *host = [segments[0] lowercaseString];
    NSArray *components = [segments subarrayWithRange:NSMakeRange(1, segments.count - 1)];

    if ([host isEqualToString:@"open"]) {
        if (queryPart.length == 0) return nil;

        for (NSString *pair in [queryPart componentsSeparatedByString:@"&"]) {
            NSArray *parts = [pair componentsSeparatedByString:@"="];
            if (parts.count != 2) continue;
            if (![parts[0] isEqualToString:@"url"]) continue;

            NSString *decoded = [parts[1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            NSURL *githubURL = [NSURL URLWithString:decoded];
            return [self isGitHubURL:githubURL] ? githubURL : nil;
        }
        return nil;
    }

    if ([host isEqualToString:@"user"] && components.count >= 1) {
        return [self gitHubURLWithPathComponents:@[components[0]]];
    }

    if ([host isEqualToString:@"repo"] && components.count >= 2) {
        return [self gitHubURLWithPathComponents:@[components[0], components[1]]];
    }

    if ([host isEqualToString:@"issue"] && components.count >= 3) {
        return [self gitHubURLWithPathComponents:@[components[0], components[1], @"issues", components[2]]];
    }

    if ([host isEqualToString:@"pr"] && components.count >= 3) {
        return [self gitHubURLWithPathComponents:@[components[0], components[1], @"pull", components[2]]];
    }

    if ([host isEqualToString:@"commit"] && components.count >= 3) {
        return [self gitHubURLWithPathComponents:@[components[0], components[1], @"commit", components[2]]];
    }

    if ([host isEqualToString:@"releases"] && components.count >= 2) {
        return [self gitHubURLWithPathComponents:@[components[0], components[1], @"releases"]];
    }

    if ([host isEqualToString:@"release"] && components.count >= 3) {
        NSString *tagOrLatest = components[2];
        if ([tagOrLatest.lowercaseString isEqualToString:@"latest"]) {
            return [self gitHubURLWithPathComponents:@[components[0], components[1], @"releases", @"latest"]];
        }
        return [self gitHubURLWithPathComponents:@[components[0], components[1], @"releases", @"tag", tagOrLatest]];
    }

    return nil;
}

+ (NSURL *)gitHubURLWithPathComponents:(NSArray *)components {
    NSMutableArray *encoded = [NSMutableArray arrayWithCapacity:components.count];
    for (NSString *component in components) {
        [encoded addObject:[component stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    }
    NSString *urlString = [NSString stringWithFormat:@"https://github.com/%@", [encoded componentsJoinedByString:@"/"]];
    return [NSURL URLWithString:urlString];
}

+ (BOOL)userProfileInfoFromURL:(NSURL *)url login:(NSString **)login {
    if (url == nil) return NO;
    static NSRegularExpression *regex = nil;
    static NSSet *reservedTopLevelPaths = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:
            @"^https?://(?:www\\.)?github\\.com/([^/]+)/?(?:[?#].*)?$"
                                                            options:NSRegularExpressionCaseInsensitive
                                                              error:nil];
        reservedTopLevelPaths = [NSSet setWithObjects:@"settings", @"notifications", @"marketplace",
                                  @"explore", @"topics", @"trending", @"collections", @"events",
                                  @"sponsors", @"issues", @"pulls", @"login", @"join", @"about",
                                  @"pricing", @"features", @"apps", @"orgs", @"new", nil];
    });

    NSString *urlString = url.absoluteString;
    NSTextCheckingResult *match = [regex firstMatchInString:urlString options:0 range:NSMakeRange(0, urlString.length)];
    if (match == nil) return NO;

    NSString *candidate = [urlString substringWithRange:[match rangeAtIndex:1]];
    if ([reservedTopLevelPaths containsObject:candidate.lowercaseString]) return NO;

    if (login != NULL) *login = candidate;
    return YES;
}

+ (BOOL)routeGitHubURL:(NSURL *)url fromViewController:(UIViewController *)viewController {
    if (![self isGitHubURL:url] || viewController == nil) return NO;

    NSString *fileOwner, *fileRepo, *filePath;
    if ([ReadmeViewController repoTextFileInfoFromURL:url ownerLogin:&fileOwner repoName:&fileRepo path:&filePath]) {
        [ReadmeViewController openRepoFileAtPath:filePath
                                        ownerLogin:fileOwner
                                          repoName:fileRepo
                                fromViewController:viewController
                                       fallbackURL:url];
        return YES;
    }

    NSString *commitOwner, *commitRepo, *commitSha;
    if ([CommitDetailViewController commitInfoFromURL:url ownerLogin:&commitOwner repoName:&commitRepo sha:&commitSha]) {
        CommitDetailViewController *commitVC = [[CommitDetailViewController alloc] init];
        commitVC.ownerLogin = commitOwner;
        commitVC.repoName = commitRepo;
        commitVC.sha = commitSha;
        [viewController.navigationController pushViewController:commitVC animated:YES];
        return YES;
    }

    NSString *issueOwner, *issueRepo;
    NSInteger issueNumber = 0;
    if ([IssueListViewController issueNumberFromURL:url ownerLogin:&issueOwner repoName:&issueRepo number:&issueNumber]) {
        [IssueDetailViewController pushIssueNumber:issueNumber ownerLogin:issueOwner repoName:issueRepo fromViewController:viewController];
        return YES;
    }

    NSString *issueListOwner, *issueListRepo;
    if ([IssueListViewController issueListInfoFromURL:url ownerLogin:&issueListOwner repoName:&issueListRepo]) {
        IssueListViewController *issueListVC = [[IssueListViewController alloc] init];
        issueListVC.ownerLogin = issueListOwner;
        issueListVC.repoName = issueListRepo;
        [viewController.navigationController pushViewController:issueListVC animated:YES];
        return YES;
    }

    NSString *latestOwner, *latestRepo;
    if ([RepoDetailViewController latestReleaseInfoFromURL:url ownerLogin:&latestOwner repoName:&latestRepo]) {
        [RepoDetailViewController pushLatestReleaseForOwnerLogin:latestOwner repoName:latestRepo fromViewController:viewController];
        return YES;
    }

    NSString *tagOwner, *tagRepo, *tagName;
    if ([RepoDetailViewController releaseByTagInfoFromURL:url ownerLogin:&tagOwner repoName:&tagRepo tag:&tagName]) {
        [RepoDetailViewController pushReleaseForOwnerLogin:tagOwner repoName:tagRepo tag:tagName fromViewController:viewController];
        return YES;
    }

    NSString *releaseOwner, *releaseRepo;
    if ([RepoDetailViewController releaseListInfoFromURL:url ownerLogin:&releaseOwner repoName:&releaseRepo]) {
        RepoDetailViewController *releasesVC = [[RepoDetailViewController alloc] init];
        releasesVC.ownerLogin = releaseOwner;
        releasesVC.repoName = releaseRepo;
        releasesVC.title = GHL(@"Релизы");
        [viewController.navigationController pushViewController:releasesVC animated:YES];
        return YES;
    }

    NSString *pullOwner, *pullRepo;
    NSInteger pullNumber = 0;
    if ([PullRequestDetailViewController pullRequestNumberFromURL:url ownerLogin:&pullOwner repoName:&pullRepo number:&pullNumber]) {
        [PullRequestDetailViewController pushPullRequestNumber:pullNumber ownerLogin:pullOwner repoName:pullRepo fromViewController:viewController];
        return YES;
    }

    NSString *pullListOwner, *pullListRepo;
    if ([PullRequestListViewController pullRequestListInfoFromURL:url ownerLogin:&pullListOwner repoName:&pullListRepo]) {
        PullRequestListViewController *pullListVC = [[PullRequestListViewController alloc] init];
        pullListVC.ownerLogin = pullListOwner;
        pullListVC.repoName = pullListRepo;
        [viewController.navigationController pushViewController:pullListVC animated:YES];
        return YES;
    }

    NSString *commitsOwner, *commitsRepo;
    if ([CommitHistoryViewController commitHistoryInfoFromURL:url ownerLogin:&commitsOwner repoName:&commitsRepo]) {
        CommitHistoryViewController *historyVC = [[CommitHistoryViewController alloc] init];
        historyVC.ownerLogin = commitsOwner;
        historyVC.repoName = commitsRepo;
        [viewController.navigationController pushViewController:historyVC animated:YES];
        return YES;
    }

    NSString *forksOwner, *forksRepo;
    if ([ForkListViewController forkListInfoFromURL:url ownerLogin:&forksOwner repoName:&forksRepo]) {
        ForkListViewController *forksVC = [[ForkListViewController alloc] init];
        forksVC.ownerLogin = forksOwner;
        forksVC.repoName = forksRepo;
        [viewController.navigationController pushViewController:forksVC animated:YES];
        return YES;
    }

    NSString *repoOwner, *repoName;
    if ([RepoOverviewViewController repoOverviewInfoFromURL:url ownerLogin:&repoOwner repoName:&repoName]) {
        [RepoOverviewViewController pushRepoOverviewForOwnerLogin:repoOwner repoName:repoName fromViewController:viewController];
        return YES;
    }

    NSString *login;
    if ([self userProfileInfoFromURL:url login:&login]) {
        PublicProfileViewController *profileVC = [[PublicProfileViewController alloc] init];
        profileVC.login = login;
        [viewController.navigationController pushViewController:profileVC animated:YES];
        return YES;
    }

    return NO;
}

@end
