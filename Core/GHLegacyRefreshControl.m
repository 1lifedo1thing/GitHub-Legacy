
#import "GHLegacyRefreshControl.h"
#import "GHLocalization.h"

static const CGFloat kGHRefreshControlHeight = 56.0;

@interface GHLegacyRefreshControl ()
@property (nonatomic, unsafe_unretained) UIScrollView *scrollView;
@property (nonatomic, assign) UIEdgeInsets originalContentInset;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, assign) BOOL pastThreshold;
@property (nonatomic, readwrite, getter=isRefreshing) BOOL refreshing;
@property (nonatomic, unsafe_unretained) id targetForAction;
@property (nonatomic, assign) SEL action;
@end

@implementation GHLegacyRefreshControl

+ (instancetype)gh_attachToScrollView:(UIScrollView *)scrollView {
    CGRect frame = CGRectMake(0, -kGHRefreshControlHeight,
                              scrollView.bounds.size.width, kGHRefreshControlHeight);
    GHLegacyRefreshControl *control = [[self alloc] initWithFrame:frame];
    control.scrollView = scrollView;
    control.originalContentInset = scrollView.contentInset;
    [scrollView addSubview:control];
    return control;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;

        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _spinner.hidesWhenStopped = YES;
        [self addSubview:_spinner];

        _statusLabel = [[UILabel alloc] init];
        _statusLabel.backgroundColor = [UIColor clearColor];
        _statusLabel.font = [UIFont systemFontOfSize:13];
        _statusLabel.textColor = [UIColor grayColor];
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        _statusLabel.text = GHL(@"Потяните, чтобы обновить");
        [self addSubview:_statusLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat midX = self.bounds.size.width / 2.0;
    CGFloat midY = self.bounds.size.height / 2.0;
    _statusLabel.frame = self.bounds;
    _spinner.center = CGPointMake(midX, midY);
}

- (void)addTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents {

    self.targetForAction = target;
    self.action = action;
}

#pragma mark - Scroll tracking

- (void)gh_scrollViewDidScroll {
    if (self.isRefreshing) return;

    UIScrollView *scrollView = self.scrollView;
    if (scrollView == nil) return;

    CGFloat pulled = -(scrollView.contentOffset.y + self.originalContentInset.top);
    if (pulled >= kGHRefreshControlHeight) {
        if (!self.pastThreshold) {
            self.pastThreshold = YES;
            self.statusLabel.text = GHL(@"Отпустите, чтобы обновить");
        }
    } else if (self.pastThreshold) {
        self.pastThreshold = NO;
        self.statusLabel.text = GHL(@"Потяните, чтобы обновить");
    }
}

- (void)gh_scrollViewDidEndDragging {
    if (self.isRefreshing || !self.pastThreshold) return;
    [self beginRefreshing];
    [self gh_sendAction];
}

- (void)gh_sendAction {
    id target = self.targetForAction;
    SEL action = self.action;
    if (target == nil || action == NULL || ![target respondsToSelector:action]) return;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [target performSelector:action];
#pragma clang diagnostic pop
}

#pragma mark - Public

- (void)beginRefreshing {
    if (self.isRefreshing) return;
    self.refreshing = YES;
    self.pastThreshold = NO;
    [self.spinner startAnimating];
    self.statusLabel.text = GHL(@"Обновление…");

    UIScrollView *scrollView = self.scrollView;
    if (scrollView == nil) return;

    UIEdgeInsets inset = self.originalContentInset;
    inset.top += kGHRefreshControlHeight;
    [UIView animateWithDuration:0.25 animations:^{
        scrollView.contentInset = inset;
    }];
}

- (void)endRefreshing {
    if (!self.isRefreshing) return;
    self.refreshing = NO;
    [self.spinner stopAnimating];
    self.statusLabel.text = GHL(@"Потяните, чтобы обновить");

    UIScrollView *scrollView = self.scrollView;
    if (scrollView == nil) return;

    UIEdgeInsets original = self.originalContentInset;
    [UIView animateWithDuration:0.25 animations:^{
        scrollView.contentInset = original;
    }];
}

@end
