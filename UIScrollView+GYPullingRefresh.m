//
//  UIScrollView+GYPullingRefresh.m
//  GYRefresh
//
//  Created by brad.gy on 2017/12/8.
//  Copyright © 2017年 brad.gy. All rights reserved.
//

#import "UIScrollView+GYPullingRefresh.h"
#import <objc/runtime.h>

#pragma mark - GYScrollViewTracker

typedef NS_ENUM(NSUInteger, GYScrollViewTrackerType) {
    GYScrollViewTrackerTypeHeader,
    GYScrollViewTrackerTypeFooter
};

@interface GYScrollViewTracker : NSObject

@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, assign) CGFloat triggerPositionY;
@property (nonatomic, assign) GYScrollViewTrackerType type;

- (id)initWithScrollView:(UIScrollView *)scrollView;

@end

@implementation GYScrollViewTracker

- (id)initWithScrollView:(UIScrollView *)scrollView {
    if(!scrollView) { return nil; }
    self = [super init];
    if(self) {
        self.scrollView = scrollView;
        self.type = GYScrollViewTrackerTypeHeader;
    }
    return self;
}

- (void)setScrollView:(UIScrollView *)scrollView {
    [scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
    [scrollView addObserver:self forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:nil];
    _scrollView = scrollView;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if([keyPath isEqualToString:@"contentSize"] &&
       _type == GYScrollViewTrackerTypeFooter) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        [_scrollView performSelector:@selector(refreshFooterContentSizeChanaged)];
    }
    else if([keyPath isEqualToString:@"contentOffset"]) {
        if(_type == GYScrollViewTrackerTypeHeader) {
            if(_scrollView.isHeaderRefreshing) { return; }
            [_scrollView performSelector:@selector(refreshHeaderContentOffsetChanged)];
        }
        else if(_type == GYScrollViewTrackerTypeFooter){
            if(_scrollView.isFooterRefreshing) { return; }
            [_scrollView performSelector:@selector(refreshFooterContentOffsetChanged)];
        }
        float value = [[change objectForKey:NSKeyValueChangeNewKey] CGPointValue].y;
        NSLog(@"contentOffSetY: %lf",value);
        if(_type == GYScrollViewTrackerTypeHeader && _scrollView.decelerating) {
            if(value < -_triggerPositionY) {
                [_scrollView performSelector:@selector(setIsHeaderRefreshing:) withObject:@(YES)];
                [_scrollView startHeaderRefresh];
            }
        }
        else if(_type == GYScrollViewTrackerTypeFooter) {
            BOOL autoRefresh = [_scrollView performSelector:@selector(autoRefresh)];
            float bottomToY = [_scrollView autoRefreshYToBottom];
            if(autoRefresh && value > _scrollView.contentSize.height - MIN(_scrollView.contentSize.height, _scrollView.frame.size.height) - bottomToY) {
                [_scrollView performSelector:@selector(setIsFooterRefreshing:) withObject:@(YES)];
                [_scrollView startFooterRefresh];
            }
            else if(!autoRefresh && _scrollView.decelerating && value > _scrollView.contentSize.height - MIN(_scrollView.contentSize.height, _scrollView.frame.size.height) + _triggerPositionY){
                [_scrollView performSelector:@selector(setIsFooterRefreshing:) withObject:@(YES)];
                [_scrollView startFooterRefresh];
            }
        }
#pragma clang diagnostic pop
    }
}

- (void)dealloc {
    [_scrollView removeObserver:self forKeyPath:@"contentSize"];
    [_scrollView removeObserver:self forKeyPath:@"contentOffset"];
}

@end

static NSString *const GYPollingRefreshHeaderViewDemoLoadingMessage = @"加载中...";
static NSString *const GYPollingRefreshHeaderViewDemoPullingMessage = @"下拉刷新";
static NSString *const GYPollingRefreshHeaderViewDemoReleaseMessage = @"松手加载";

#pragma mark - GYPollingRefreshHeaderViewDemo

@interface GYPollingRefreshHeaderViewDemo : UIView<GYPollingRefreshViewProtocol>
{
    UILabel *_pollingMessage;
}
@end

@implementation GYPollingRefreshHeaderViewDemo

- (id)init {
    self = [super init];
    if(self) {
        _pollingMessage = [[UILabel alloc] init];
        _pollingMessage.text = GYPollingRefreshHeaderViewDemoPullingMessage;
        [_pollingMessage sizeToFit];
        [self addSubview:_pollingMessage];
    }
    return self;
}

- (void)layoutSubviews {
    _pollingMessage.frame = CGRectMake((self.frame.size.width - _pollingMessage.frame.size.width)/2,
                                       (self.frame.size.height - _pollingMessage.frame.size.height)/2,
                                       _pollingMessage.frame.size.width,
                                       _pollingMessage.frame.size.height);
    
}

- (float)viewHeight {
    return 64;
}

- (void)startAnimate {
    _pollingMessage.text = GYPollingRefreshHeaderViewDemoLoadingMessage;
    [_pollingMessage sizeToFit];
    [self setNeedsLayout];
}

- (void)endAnimate {
    _pollingMessage.text = GYPollingRefreshHeaderViewDemoPullingMessage;
    [_pollingMessage sizeToFit];
    [self setNeedsLayout];
}

- (void)updatePullingY:(CGFloat)y {
    static BOOL lastPullingIsOverViewHeight = NO;
    if(y < -[self viewHeight] && !lastPullingIsOverViewHeight) {
        _pollingMessage.text = GYPollingRefreshHeaderViewDemoReleaseMessage;
        [_pollingMessage sizeToFit];
        [self setNeedsLayout];
        lastPullingIsOverViewHeight = YES;
    }
    else if(y >= -[self viewHeight] && lastPullingIsOverViewHeight) {
        _pollingMessage.text = GYPollingRefreshHeaderViewDemoPullingMessage;
        [_pollingMessage sizeToFit];
        [self setNeedsLayout];
        lastPullingIsOverViewHeight = NO;
    }
}

@end

#pragma mark - GYPollingRefreshFooterViewDemo

static NSString *const GYPollingRefreshFooterViewDemoLoadingMessage = @"加载中...";
static NSString *const GYPollingRefreshFooterViewDemoPullingMessage = @"上拉加载更多";
static NSString *const GYPollingRefreshFooterViewDemoReleaseMessage = @"松手加载更多";

@interface GYPollingRefreshFooterViewDemo : UIView<GYPollingRefreshViewProtocol>

@property (nonatomic, strong) UILabel *footerMessageLabel;

@end

@implementation GYPollingRefreshFooterViewDemo

- (id)init {
    self = [super init];
    if(self) {
        _footerMessageLabel = [[UILabel alloc] init];
        _footerMessageLabel.text = GYPollingRefreshFooterViewDemoPullingMessage;
        [_footerMessageLabel sizeToFit];
        [self addSubview:_footerMessageLabel];
    }
    return self;
}

- (void)startAnimate {
    _footerMessageLabel.text = GYPollingRefreshFooterViewDemoLoadingMessage;
    [_footerMessageLabel sizeToFit];
    [self setNeedsLayout];
}

- (void)endAnimate {
    _footerMessageLabel.text = GYPollingRefreshFooterViewDemoPullingMessage;
    [_footerMessageLabel sizeToFit];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    _footerMessageLabel.frame = CGRectMake((self.frame.size.width - _footerMessageLabel.frame.size.width)/2,
                                           (self.frame.size.height - _footerMessageLabel.frame.size.height)/2,
                                           _footerMessageLabel.frame.size.width,
                                           _footerMessageLabel.frame.size.height);
}

- (void)updatePullingY:(CGFloat)y {
    
}

- (float)viewHeight {
    return 44;
}

@end

#pragma mark - UIScrollView (GYPullingRefreshCommon)

@interface UIScrollView (GYPullingRefreshCommon)

@property (nonatomic, assign) UIEdgeInsets originContentInset;

@end

@implementation UIScrollView (GYPullingRefreshCommon)

- (void)setOriginContentInset:(UIEdgeInsets)inset {
    objc_setAssociatedObject(self, @selector(originContentInset), [NSValue valueWithUIEdgeInsets:inset], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIEdgeInsets)originContentInset {
    return [objc_getAssociatedObject(self, _cmd) UIEdgeInsetsValue];
}

@end

#pragma mark - UIScrollView (GYPullingRefreshHeader)

@implementation UIScrollView (GYPullingRefreshHeader)

- (void)addPullingRefreshHeaderWithBlock:(void (^)(UIScrollView *scrollView))refreshHeaderBlock {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self setOriginContentInset:self.contentInset];
    });
    GYScrollViewTracker *tracker = [[GYScrollViewTracker alloc] initWithScrollView:self];
    tracker.triggerPositionY = [self.gy_headerRefreshView viewHeight];
    [self setHeaderTracker:tracker];
    [self setRefreshHeaderBlock:refreshHeaderBlock];
}

- (void)startHeaderRefresh {
    self.isHeaderRefreshing = YES;
    [self.gy_headerRefreshView startAnimate];
    [UIView animateWithDuration:0.2 animations:^{
        self.contentInset = UIEdgeInsetsMake(self.contentInset.top + self.gy_headerRefreshView.frame.size.height, 0, 0, 0);
    }];
    void (^refreshBlock) (UIScrollView *scrollView) = [self refreshHeaderBlock];
    if(refreshBlock){
        refreshBlock(self);
    }
}

- (void)endHeaderRefresh {
    [self.gy_headerRefreshView endAnimate];
    [UIView animateWithDuration:0.2 animations:^{
        self.contentInset = [self originContentInset];
    }];
    self.isHeaderRefreshing = NO;
}

- (void)setRefreshHeaderBlock:(void (^)(UIScrollView *scrollView))refreshBlock {
    objc_setAssociatedObject(self, @selector(refreshHeaderBlock), refreshBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void (^)(UIScrollView *scrollView))refreshHeaderBlock {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setHeaderTracker:(GYScrollViewTracker *)tracker {
    objc_setAssociatedObject(self, @selector(headerTracker), tracker, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (GYScrollViewTracker *)headerTracker {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setGy_headerRefreshView:(UIView<GYPollingRefreshViewProtocol> *)gy_refreshView {
    if(gy_refreshView == nil) { return; }
    if([self gy_justHeaderRefreshView] != gy_refreshView) {
        [[self gy_justHeaderRefreshView] removeFromSuperview];
    }
    objc_setAssociatedObject(self, @selector(gy_headerRefreshView), gy_refreshView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    gy_refreshView.frame = CGRectMake(0, -[gy_refreshView viewHeight], self.frame.size.width, [gy_refreshView viewHeight]);
    [self addSubview:gy_refreshView];
}

- (UIView<GYPollingRefreshViewProtocol> *)gy_headerRefreshView {
    UIView *view = objc_getAssociatedObject(self, _cmd);
    if(!view) {
        view = [[GYPollingRefreshHeaderViewDemo alloc] init];
        [self setGy_headerRefreshView:(UIView<GYPollingRefreshViewProtocol> *)view];
    }
    return objc_getAssociatedObject(self, _cmd);
}

- (UIView<GYPollingRefreshViewProtocol> *)gy_justHeaderRefreshView {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setIsHeaderRefreshing:(BOOL)isRefreshing {
    objc_setAssociatedObject(self, @selector(isHeaderRefreshing), @(isRefreshing), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isHeaderRefreshing {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)refreshHeaderContentOffsetChanged {
    [self.gy_headerRefreshView updatePullingY:self.contentOffset.y];
}

@end

#pragma mark - UIScrollView (GYPullingRefreshFooter)

@implementation UIScrollView (GYPullingRefreshFooter)

- (void)addPullingRefreshFooterWithBlock:(void (^)(UIScrollView *scrollView))refreshFooterBlock autoRefresh:(BOOL)autoRefresh {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self setOriginContentInset:self.contentInset];
    });
    [self setAutoRefresh:autoRefresh];
    [self setRefreshFooterBlock:refreshFooterBlock];
    GYScrollViewTracker *footerTracker = [[GYScrollViewTracker alloc] initWithScrollView:self];
    footerTracker.triggerPositionY = self.frame.size.height - [[UIScreen mainScreen] bounds].size.height + [self.gy_footerRefreshView viewHeight];
    footerTracker.type = GYScrollViewTrackerTypeFooter;
    [self setFooterTracker:footerTracker];
    
}

- (void)startFooterRefresh {
    self.isFooterRefreshing = YES;
    [self.gy_footerRefreshView startAnimate];
    [UIView animateWithDuration:0.2 animations:^{
        self.contentInset = UIEdgeInsetsMake(self.contentInset.top,
                                             self.contentInset.left,
                                             self.contentInset.bottom + [self.gy_footerRefreshView viewHeight],
                                             self.contentInset.right);
    }];
    void (^refreshFooterBlock) (UIScrollView *) = [self refreshFooterBlock];
    if(refreshFooterBlock) {
        refreshFooterBlock(self);
    }
}

- (void)endFooterRefresh {
    [self.gy_footerRefreshView endAnimate];
    self.isFooterRefreshing = NO;
    UIEdgeInsets inset = [self originContentInset];
    [UIView animateWithDuration:0.2 animations:^{
        self.contentInset = inset;
    }];
}

- (void)setRefreshFooterBlock:(void (^)(UIScrollView *scrollView))refreshFooterBlock {
    objc_setAssociatedObject(self, @selector(refreshFooterBlock), refreshFooterBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void (^)(UIScrollView *scrollView))refreshFooterBlock {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setFooterTracker:(GYScrollViewTracker *)footerTracker {
    objc_setAssociatedObject(self, @selector(footerTracker), footerTracker, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (GYScrollViewTracker *)footerTracker {
    return objc_getAssociatedObject(self, _cmd);
}

- (UIView<GYPollingRefreshViewProtocol> *)gy_footerRefreshView {
    UIView<GYPollingRefreshViewProtocol> *footerRefreshView = objc_getAssociatedObject(self, _cmd);
    if(!footerRefreshView) {
        footerRefreshView = [[GYPollingRefreshFooterViewDemo alloc] init];
        [self setGy_footerRefreshView:footerRefreshView];
    }
    return footerRefreshView;
}

- (UIView<GYPollingRefreshViewProtocol> *)gy_realFooterRefreshView {
    return objc_getAssociatedObject(self, @selector(gy_footerRefreshView));
}

- (void)setGy_footerRefreshView:(UIView<GYPollingRefreshViewProtocol> *)gy_footerRefreshView {
    if(!gy_footerRefreshView) { return; }
    if([self gy_realFooterRefreshView] != gy_footerRefreshView) {
        [[self gy_realFooterRefreshView] removeFromSuperview];
    }
    objc_setAssociatedObject(self, @selector(gy_footerRefreshView), gy_footerRefreshView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    gy_footerRefreshView.frame = CGRectMake(0,
                                         self.contentSize.height,
                                         self.frame.size.width,
                                         [gy_footerRefreshView viewHeight]);
    [self addSubview:gy_footerRefreshView];
}

- (void)setIsFooterRefreshing:(BOOL)isFooterRefreshing {
    objc_setAssociatedObject(self, @selector(isFooterRefreshing), @(isFooterRefreshing), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isFooterRefreshing {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setAutoRefreshYToBottom:(float)autoRefreshYToBottom {
    objc_setAssociatedObject(self, @selector(autoRefreshYToBottom), @(autoRefreshYToBottom), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (float)autoRefreshYToBottom {
    float y = [objc_getAssociatedObject(self, _cmd) floatValue];
    if(y < 1 && [self autoRefresh]) {
        [self setAutoRefreshYToBottom:400];
        return 400;
    }
    else if(y > 1 && ![self autoRefresh]) {
        [self setAutoRefresh:YES];
        [self setAutoRefreshYToBottom:y];
    }
    return y;
}

- (void)setAutoRefresh:(BOOL)autoRefresh {
    objc_setAssociatedObject(self, @selector(autoRefresh), @(autoRefresh), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)autoRefresh {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)refreshFooterContentSizeChanaged {
    UIView<GYPollingRefreshViewProtocol> *footerView = self.gy_footerRefreshView;
    footerView.frame = CGRectMake(0,
                                  self.contentSize.height,
                                  self.frame.size.width,
                                  [footerView viewHeight]);
}

- (void)refreshFooterContentOffsetChanged {
    [self.gy_footerRefreshView updatePullingY:self.contentOffset.y];
}

@end
