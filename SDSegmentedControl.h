//
//  SDSegmentedControl.h
//  Created by Olivier Poitrey on 22/09/12
//         and Marius Rackwitz on 19/10/12.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>


// Remove comment to see debugging backgrounds.
//#define SDSegmentedControlDebug 1

// If SDStrategyInherit is not defined you have not to subclass SDSegmentView
// and could inject other components which subclasses UIButton directly.
//#define SDStrategyInherit


// Stub
@protocol SDSegmentedControlDelegate;


#ifndef SDStrategyInherit
    #define SDSegmentView UIButton
#else
    @interface SDSegmentView : UIButton
    @end
#endif


@interface SDStainView : UIView<UIAppearance>

@property (assign, nonatomic) CGFloat      cornerRadius  UI_APPEARANCE_SELECTOR;
@property (assign, nonatomic) UIEdgeInsets edgeInsets    UI_APPEARANCE_SELECTOR;
@property (assign, nonatomic) CGSize       shadowOffset  UI_APPEARANCE_SELECTOR;
@property (assign, nonatomic) CGFloat      shadowBlur    UI_APPEARANCE_SELECTOR;
@property (assign, nonatomic) UIColor*     shadowColor   UI_APPEARANCE_SELECTOR;

@end


// Most inherited UI_APPERANCE_SELECTORs are ignored. You can use the following selectors
// to customize appearance:
//  +[SDSegmentedControl appearance]
//  +[SDSegmentView appearance]
//  +[SDStainView appearance]
@interface SDSegmentedControl : UISegmentedControl<UIScrollViewDelegate, UIGestureRecognizerDelegate> {
@protected
    CAShapeLayer* borderBottomLayer;
    UIScrollView* scrollView;
    
@private
    NSInteger selectedSegmentIndex;
    NSInteger lastSelectedSegmentIndex;
    CGFloat   panPositionX;
    BOOL      pannedBefore;
    BOOL      isScrollingBySelection;
    NSTimer*  panScrollTimer;
    void (^lastCompletionBlock)();
}

@property (assign, nonatomic) id<SDSegmentedControlDelegate> delegate;
@property (strong, nonatomic) UIView*        selectedStainView;
@property (assign, nonatomic) BOOL           panIsEnabled;
@property (assign, nonatomic) CFTimeInterval animationDuration  UI_APPEARANCE_SELECTOR;
@property (assign, nonatomic) CGFloat        interItemSpace     UI_APPEARANCE_SELECTOR;
@property (assign, nonatomic) CGFloat        arrowSize          UI_APPEARANCE_SELECTOR;
@property (assign, nonatomic) CGSize         imageSize          UI_APPEARANCE_SELECTOR;
@property (assign, nonatomic) UIEdgeInsets   stainEdgeInsets    UI_APPEARANCE_SELECTOR;

// Additional methods.
- (void)insertSegmentWithTitle:(NSString *)title image:(UIImage *)image atIndex:(NSUInteger)index animated:(BOOL)animated;

- (UIImage *)imageForSegmentAtIndex:(NSUInteger)index forState:(UIControlState)state;
- (void)setImage:(UIImage *)image forSegmentAtIndex:(NSUInteger)index forState:(UIControlState)state;

- (void)setTitle:(NSString *)title forSegmentAtIndex:(NSUInteger)segment forState:(UIControlState)state;
- (NSString *)titleForSegmentAtIndex:(NSUInteger)segment forState:(UIControlState)state;


// Only for overriding or advanced integration.
- (SDSegmentView *)selectedSegment;
- (SDSegmentView *)segmentAtIndex:(NSUInteger)index;
- (void)setSegmentView:(SDSegmentView *)segmentView atIndex:(NSUInteger)index;
- (SDSegmentView *)newSegmentView;
- (NSInteger)segmentIndexByPosition:(CGFloat)position;

@end


// This is not necessarily needed. You can also bind by default UIControl event dispatching mechanism.
@protocol SDSegmentedControlDelegate <NSObject>

@optional

- (void)sdSegmentedControl:(SDSegmentedControl *)segmentedControl didSelectedIndex:(NSUInteger)segmentIndex;
- (void)sdSegmentedControl:(SDSegmentedControl *)segmentedControl didPannedToPosition:(CGFloat)position;
- (void)sdSegmentedControl:(SDSegmentedControl *)segmentedControl didPannedToSegmentIndex:(NSUInteger)segmentIndex;

@end
