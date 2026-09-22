
#import <UIKit/UIKit.h>

@interface GHLegacyRefreshControl : UIView

+ (instancetype)gh_attachToScrollView:(UIScrollView *)scrollView;

- (void)addTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents;

- (void)beginRefreshing;
- (void)endRefreshing;

@property (nonatomic, readonly, getter=isRefreshing) BOOL refreshing;

- (void)gh_scrollViewDidScroll;
- (void)gh_scrollViewDidEndDragging;

@end
