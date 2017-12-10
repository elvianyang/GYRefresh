//
//  UIScrollView+GYPullingRefresh.h
//  GYRefresh
//
//  Created by brad.gy on 2017/12/8.
//  Copyright © 2017年 brad.gy. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol GYPollingRefreshViewProtocol<NSObject>

- (void)startAnimate;
- (void)endAnimate;
- (void)updatePullingY:(CGFloat)y;
- (float)viewHeight;

@end

@interface UIScrollView (GYPullingRefreshHeader)

- (void)addPullingRefreshHeaderWithBlock:(void (^)(UIScrollView *scrollView))refreshHeaderBlock;
- (void)startHeaderRefresh;
- (void)endHeaderRefresh;

@property (nonatomic, strong) UIView<GYPollingRefreshViewProtocol> *gy_headerRefreshView;
@property (nonatomic, readonly) BOOL isHeaderRefreshing;

@end

@interface UIScrollView (GYPullingRefreshFooter)

- (void)addPullingRefreshFooterWithBlock:(void (^)(UIScrollView *scrollView))refreshFooterBlock autoRefresh:(BOOL)autoRefresh;
- (void)startFooterRefresh;
- (void)endFooterRefresh;

@property (nonatomic, strong) UIView<GYPollingRefreshViewProtocol> *gy_footerRefreshView;
@property (nonatomic, readonly) BOOL isFooterRefreshing;
@property (nonatomic, assign) float autoRefreshYToBottom;

@end


