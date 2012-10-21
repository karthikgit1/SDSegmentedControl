//
//  SDSegmentedControl.m
//  Created by Olivier Poitrey on 22/09/12
//         and Marius Rackwitz on 19/10/12
//

#import "SDSegmentedControl.h"
#import <objc/runtime.h>



#pragma mark - Constants

// With properties
const NSTimeInterval kSDSegmentedControlDefaultDuration      = 0.5;
const CGFloat        kSDSegmentedControlArrowSize            = 6.5;
const CGFloat        kSDSegmentedControlInterItemSpace       = 30.0;
const CGSize         kSDSegmentedControlImageSize            = {18, 18};

// Without properties
const NSTimeInterval kSDSegmentedControlAddDuration          = 0.4;
const NSTimeInterval kSDSegmentedControlRemoveDuration       = 0.4;
const CGFloat        kSDSegmentedControlScrollBorder         = 44;
const CGFloat        kSDSegmentedControlScrollAmount         = 5;
const UIEdgeInsets   kSDSegmentedControlStainEdgeInsets      = {-3.5, -8, -2.5, -8};
const CGFloat        kSDSegmentedControlScrollOffset         = 20;
const CGFloat        kSDSegmentedControlScrollTimeInterval   = 0.01;



#pragma mark - Private interfaces

@interface SDSegmentedControl ()

@property (strong, nonatomic) NSMutableArray* items;

- (UIImage *)scaledImageWithImage:(UIImage *)sourceImage;
- (NSInteger)lastEnabledSegmentIndexNearIndex:(NSUInteger)index;
- (void)layoutSegments;
- (void)updateItems;

- (void)drawPathsToPosition:(CGFloat)position
                   animated:(BOOL)animated;
- (void)drawPathsToPosition:(CGFloat)position
          animationDuration:(CFTimeInterval)duration completion:(void (^)(void))completion;
- (void)drawPathsFromPosition:(CGFloat)oldPosition toPosition:(CGFloat)position
            animationDuration:(CFTimeInterval)duration;
- (void)drawPathsFromPosition:(CGFloat)oldPosition toPosition:(CGFloat)position
            animationDuration:(CFTimeInterval)duration completion:(void (^)(void))completion;

- (void)addAnimationWithDuration:(CFTimeInterval)duration onLayer:(CALayer *)layer
                          forKey:(NSString *)key toPath:(UIBezierPath *)path;
- (void)addArrowAtPoint:(CGPoint)point toPath:(UIBezierPath *)path withLineWidth:(CGFloat)width;

- (void)handleSelect:(SDSegmentView *)gestureRecognizer;
- (void)handleSlide:(UIPanGestureRecognizer *)gestureRecognizer;
- (void)panScrollTimer:(NSTimer *)timer;

@end


@interface SDPrivateSegmentView : SDSegmentView

@end


// Declare as a category, so that user doesn't necessarily
// have to subclass SDSegmentView
@interface SDSegmentView (Private)

@property (assign, nonatomic) BOOL    wasRemoved;
@property (assign, nonatomic) CGFloat customWidth;

// The rectangle which is used for SDStainView.
- (CGRect)innerFrame;

@end



#pragma mark - Implementation

@implementation SDSegmentedControl

@synthesize items;
@synthesize delegate;
@synthesize selectedStainView;
@synthesize panIsEnabled;
@synthesize animationDuration;
@synthesize interItemSpace;
@synthesize arrowSize;
@synthesize imageSize;
@synthesize stainEdgeInsets;


#pragma mark - Initialization

+ (Class)layerClass {
    return CAShapeLayer.class;
}

- (id)init {
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithItems:(NSArray *)newItems {
    self = [self init];
    if (self) {
        [self commonInit];
        [newItems enumerateObjectsUsingBlock:^(id title, NSUInteger idx, BOOL *stop) {
            [self insertSegmentWithTitle:title atIndex:idx animated:NO];
        }];
    }
    return self;
}

- (void)awakeFromNib {
    [self commonInit];
    selectedSegmentIndex = super.selectedSegmentIndex;
    for (NSInteger i = 0; i < super.numberOfSegments; i++) {
        [self insertSegmentWithTitle:[super titleForSegmentAtIndex:i] atIndex:i animated:NO];
    }
    [super removeAllSegments];
}

- (void)commonInit {
    // Init properties
    items                    = NSMutableArray.array;
    lastSelectedSegmentIndex = -1;
    selectedSegmentIndex     = -1;
    
    // Appearance properties
    animationDuration        = kSDSegmentedControlDefaultDuration;
    arrowSize                = kSDSegmentedControlArrowSize;
    imageSize                = kSDSegmentedControlImageSize;
    interItemSpace           = kSDSegmentedControlInterItemSpace;
    stainEdgeInsets          = kSDSegmentedControlStainEdgeInsets;
    self.autoresizingMask    = UIViewAutoresizingFlexibleWidth;
    
    // Panning
    panIsEnabled = YES;
    panPositionX = -1;
    pannedBefore = NO;
    
    // Remove all subviews
    [self.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    // Add gesture recognizer
    UIPanGestureRecognizer* panGestureRecognizer;
    panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleSlide:)];
    panGestureRecognizer.delegate = self;
    [self addGestureRecognizer:panGestureRecognizer];
    
    // Init layer
    ((CAShapeLayer *)self.layer).fillColor = [UIColor colorWithWhite:0.961 alpha:1].CGColor;
    self.layer.backgroundColor = UIColor.clearColor.CGColor;
    self.layer.shadowColor     = UIColor.blackColor.CGColor;
    self.layer.shadowRadius    = 0.8;
    self.layer.shadowOpacity   = 0.6;
    self.layer.shadowOffset    = CGSizeMake(0, 1);
    
    // Init border bottom layer
    borderBottomLayer = [CAShapeLayer layer];
    borderBottomLayer.strokeColor = UIColor.whiteColor.CGColor;
    borderBottomLayer.lineWidth   = 0.5;
    borderBottomLayer.fillColor   = nil;
    [self.layer addSublayer:borderBottomLayer];
    
    // Init scrollView
    scrollView                  = UIScrollView.new;
    scrollView.delegate         = self;
    scrollView.backgroundColor  = UIColor.clearColor;
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.showsVerticalScrollIndicator   = NO;
    [self addSubview:scrollView];
    
    // Init stain view
    self.selectedStainView = SDStainView.new;
    [scrollView addSubview:self.selectedStainView];
    self.selectedStainView.backgroundColor = [UIColor colorWithWhite:0.816 alpha:1];
}


#pragma mark - Segment accessors and mutators

- (SDSegmentView *)segmentAtIndex:(NSUInteger)index {
    NSParameterAssert(index >= 0 && index < self.items.count);
    return [self.items objectAtIndex:index];
}

- (void)setSegmentView:(SDSegmentView *)segmentView atIndex:(NSUInteger)index {
    NSParameterAssert(index >= 0 && index < self.items.count);
    [self.items replaceObjectAtIndex:index withObject:segmentView];
    [self bindSegmentView:segmentView];
    [self setNeedsLayout];
}

- (SDSegmentView *)newSegmentView {
    // Init new segment view and it's appearance
    SDSegmentView* segmentView             = SDPrivateSegmentView.new;
    segmentView.customWidth                = 0.0;
    segmentView.alpha                      = 0;
    segmentView.titleLabel.shadowOffset    = CGSizeMake(0, 0.5);
    segmentView.titleLabel.font            = [UIFont boldSystemFontOfSize:14];
    segmentView.userInteractionEnabled     = YES;
    segmentView.titleLabel.lineBreakMode   = UILineBreakModeTailTruncation;
    segmentView.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    segmentView.contentVerticalAlignment   = UIControlContentVerticalAlignmentCenter;
    segmentView.titleEdgeInsets            = UIEdgeInsetsMake(0, 4.0, 0, -4.0);  // Space between text and image 
    segmentView.imageEdgeInsets            = UIEdgeInsetsMake(0, 4.0, 0, -4.0);  // Space between image and stain
    segmentView.contentEdgeInsets          = UIEdgeInsetsMake(0, 0.0, 0,  8.0);  // Enlarge touchable area
    
    #ifdef SDSegmentedControlDebug
        segmentView.backgroundColor            = [UIColor colorWithHue:1.00 saturation:1.0 brightness:1.0 alpha:0.5];
        segmentView.imageView.backgroundColor  = [UIColor colorWithHue:0.66 saturation:1.0 brightness:1.0 alpha:0.5];
        segmentView.titleLabel.backgroundColor = [UIColor colorWithHue:0.33 saturation:1.0 brightness:1.0 alpha:0.5];
    #endif    
    
    [segmentView setTitleColor:[UIColor colorWithWhite:0.392 alpha:1] forState:UIControlStateNormal];
    [segmentView setTitleShadowColor:UIColor.whiteColor               forState:UIControlStateNormal];
    [segmentView setTitleColor:[UIColor colorWithWhite:0.235 alpha:1] forState:UIControlStateSelected];
    [segmentView setTitleShadowColor:UIColor.whiteColor               forState:UIControlStateSelected];
    [segmentView setTitleColor:[UIColor colorWithWhite:0.500 alpha:1] forState:UIControlStateDisabled];
    [segmentView setTitleShadowColor:UIColor.darkGrayColor            forState:UIControlStateDisabled];
    return segmentView;
}


#pragma mark - Helper

- (UIImage*)scaledImageWithImage:(UIImage*)sourceImage {
    if (!sourceImage) {
        return nil;
    }
    
    const CGSize sourceSize = sourceImage.size;
    const CGSize targetSize = self.imageSize;
    CGSize scaledSize = targetSize;
    CGPoint origin = CGPointMake(0.0, 0.0);
    
    if (CGSizeEqualToSize(sourceSize, targetSize) == NO)  {
        CGFloat widthFactor  = targetSize.width  / sourceSize.width;
        CGFloat heightFactor = targetSize.height / sourceSize.height;
        CGFloat scaleFactor  = MAX(widthFactor, heightFactor);
        
        scaledSize.width  = sourceSize.width  * scaleFactor;
        scaledSize.height = sourceSize.height * scaleFactor;
        
        // Center the image
        if (widthFactor > heightFactor) {
            origin.y = (targetSize.height - scaledSize.height) / 2; 
        } else if (heightFactor > widthFactor) {
            origin.x = (targetSize.width - scaledSize.width) / 2;
        }
    }
    
    UIGraphicsBeginImageContext(targetSize);
    [sourceImage drawInRect:(CGRect){origin, scaledSize}];
    UIImage* targetImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return targetImage;
}

- (void)bindSegmentView:(SDSegmentView *)segmentView {
    [segmentView addTarget:self action:@selector(handleSelect:) forControlEvents:UIControlEventTouchUpInside];
}

- (NSInteger)lastEnabledSegmentIndexNearIndex:(NSUInteger)index {
    // Select the first enabled segment
    NSUInteger indexToSelect = NSNotFound;
    NSUInteger indexOffset = 0;
    for (int i=0; i<self.items.count; i++) {
        SDSegmentView* segment = [self.items objectAtIndex:i];
        if (segment.wasRemoved) {
            indexOffset--;
        } else if (segment.enabled) {
            indexToSelect = i;
        }
        if (indexToSelect != NSNotFound && i >= index) {
            break;
        }
    }
    
    if (indexToSelect != NSNotFound) {
        // There was another enabled segment, so select it
        return indexToSelect + indexOffset;
    } else {
        // There is no other enabled segment at all, so select none 
        return -1;
    }
}


#pragma mark - Segment disabled state

- (void)setEnabled:(BOOL)enabled forSegmentAtIndex:(NSUInteger)index {
    [self segmentAtIndex:index].enabled = enabled;
    if (index == self.selectedSegmentIndex) {
        self.selectedSegmentIndex = [self lastEnabledSegmentIndexNearIndex:index];
    }
}

- (BOOL)isEnabledForSegmentAtIndex:(NSUInteger)index {
    return [self segmentAtIndex:index].enabled;
}


#pragma mark - Segment width getter and setter

- (void)setWidth:(CGFloat)width forSegmentAtIndex:(NSUInteger)index {
    [self segmentAtIndex:index].customWidth = width;
    [self setNeedsLayout];
}

- (CGFloat)widthForSegmentAtIndex:(NSUInteger)index {
    return [self segmentAtIndex:index].customWidth;
}


#pragma mark - Segment image accessors and mutators

- (void)insertSegmentWithImage:(UIImage *)image atIndex:(NSUInteger)segment animated:(BOOL)animated {
    [self insertSegmentWithTitle:nil image:image atIndex:segment animated:animated];
}

- (UIImage *)imageForSegmentAtIndex:(NSUInteger)index {
    return [self imageForSegmentAtIndex:index forState:UIControlStateNormal];
}

- (UIImage *)imageForSegmentAtIndex:(NSUInteger)index forState:(UIControlState)state {
    SDSegmentView* segmentView = [self segmentAtIndex:index];
    return [segmentView imageForState:state];
}

- (void)setImage:(UIImage *)image forSegmentAtIndex:(NSUInteger)index {
    [self setImage:image forSegmentAtIndex:index forState:UIControlStateNormal];
}

- (void)setImage:(UIImage *)image forSegmentAtIndex:(NSUInteger)index forState:(UIControlState)state {
    SDSegmentView* segmentView = [self segmentAtIndex:index];
    [segmentView setImage:[self scaledImageWithImage:image] forState:state];
    [segmentView sizeToFit];
    [self setNeedsLayout];
}


#pragma mark - Segment accessors and modifiers

- (void)setTitle:(NSString *)title forSegmentAtIndex:(NSUInteger)segment {
    [self setTitle:title forSegmentAtIndex:segment forState:UIControlStateNormal];
}

- (void)setTitle:(NSString *)title forSegmentAtIndex:(NSUInteger)index forState:(UIControlState)state {
    SDSegmentView* segmentView = [self segmentAtIndex:index];
    [segmentView setTitle:title forState:state];
    [segmentView sizeToFit];
    [self setNeedsLayout];
}

- (NSString *)titleForSegmentAtIndex:(NSUInteger)segment {
    return [self titleForSegmentAtIndex:segment]; 
}

- (NSString *)titleForSegmentAtIndex:(NSUInteger)index forState:(UIControlState)state {
    SDSegmentView* segmentView = [self segmentAtIndex:index];
    return [segmentView titleForState:state];
}

- (void)insertSegmentWithTitle:(NSString *)title atIndex:(NSUInteger)index animated:(BOOL)animated {
    [self insertSegmentWithTitle:title image:nil atIndex:index animated:animated];
}

- (void)insertSegmentWithTitle:(NSString *)title image:(UIImage *)image atIndex:(NSUInteger)index animated:(BOOL)animated {
    SDSegmentView* segmentView = [self newSegmentView];
    [self bindSegmentView:segmentView];
    
    // Set title
    [segmentView setTitle:title forState:UIControlStateNormal];
    [segmentView setImage:[self scaledImageWithImage:image] forState:UIControlStateNormal];
    [segmentView sizeToFit];
    
    // Add the segment to items and in the subview stack
    index = MAX(index, 0);
    if (index < self.items.count) {
        segmentView.center = ((UIView *)[self.items objectAtIndex:index]).center;
        [scrollView insertSubview:segmentView belowSubview:[self.items objectAtIndex:index]];
        [self.items insertObject:segmentView atIndex:index];
    } else {
        segmentView.center = self.center;
        [scrollView addSubview:segmentView];
        [self.items addObject:segmentView];
    }
    
    // Keep selection, and do not use the setter, so we can trigger
    // layoutSubviews by ourself with custom animation & duration
    if (selectedSegmentIndex >= index) {
        selectedSegmentIndex++;
    }
    lastSelectedSegmentIndex = selectedSegmentIndex;
    
    // Update component
    if (animated) {
        [UIView animateWithDuration:kSDSegmentedControlAddDuration
                         animations:^{
                             [self layoutSubviews];
                         }];
    } else {
        [self setNeedsLayout];
    }
}

- (void)removeSegmentAtIndex:(NSUInteger)index animated:(BOOL)animated {
    if (self.items.count == 0) {
        return;
    }
    SDSegmentView* segmentView = [self segmentAtIndex:index];
    
    // Ensure that a segment is selected, if there was a segment selected before
    if (self.selectedSegmentIndex >= 0) {
        int indexToSelect = self.selectedSegmentIndex;
        BOOL changed = NO;
        
        if (self.items.count == 1) {
            // Deselect if there is no item
            indexToSelect = -1;
            changed = YES;
        } else if (indexToSelect == index) {
            // Inform that the old value doesn't exist anymore
            changed = YES;
        }
        
        segmentView.wasRemoved = YES;
        int newIndexToSelect = [self lastEnabledSegmentIndexNearIndex:indexToSelect];
        changed |= indexToSelect != newIndexToSelect;
        
        // It is important to set both, this will fix the animation.
        selectedSegmentIndex     = newIndexToSelect;
        lastSelectedSegmentIndex = newIndexToSelect;
        
        if (changed) {
            [self sendActionsForControlEvents:UIControlEventValueChanged];
        }
    }
    
    if (animated) {
        [self.items removeObject:segmentView];
        [UIView animateWithDuration:kSDSegmentedControlRemoveDuration
                         animations:^{
                             segmentView.alpha = 0;
                             [self layoutSegments];
                         }
                         completion:^(BOOL finished) {
                             [segmentView removeFromSuperview];
                         }];
    } else {
        [segmentView removeFromSuperview];
        [self.items removeObject:segmentView];
        [self setNeedsLayout];
    }
}

- (void)removeAllSegments {
    [self.items makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.items removeAllObjects];
    self.selectedSegmentIndex = -1;
    [self setNeedsLayout];
}

- (NSUInteger)numberOfSegments {
    return self.items.count;
}

- (void)setSelectedSegmentIndex:(NSInteger)aSelectedSegmentIndex {
    if (aSelectedSegmentIndex != selectedSegmentIndex) {
        NSParameterAssert(aSelectedSegmentIndex < (NSInteger)self.items.count);
        lastSelectedSegmentIndex = selectedSegmentIndex;
        selectedSegmentIndex     = aSelectedSegmentIndex;
        
        if ([delegate respondsToSelector:@selector(sdSegmentedControl:didSelectedIndex::)]) {
            [delegate sdSegmentedControl:self didSelectedIndex:selectedSegmentIndex];
        }
        
        [self setNeedsLayout];
    }
}

- (NSInteger)selectedSegmentIndex {
    return selectedSegmentIndex;
}

- (SDSegmentView *)selectedSegment {
    return [self.items objectAtIndex:self.selectedSegmentIndex];
}

- (NSInteger)segmentIndexByPosition:(CGFloat)position {
    // We catch all positions, also these between segments
    NSInteger selectedItemIndex = 0;
    for (int i=0; i<self.items.count; i++) {
        SDSegmentView* item = [self.items objectAtIndex:i];
        if (position > CGRectGetMinX(item.frame) - self.interItemSpace/2) {
            selectedItemIndex = i;
        }
        if (position < CGRectGetMaxX(item.frame) + self.interItemSpace/2) {
            break;
        }
    }
    return selectedItemIndex;
}


#pragma mark - Layout

- (void)willMoveToSuperview:(UIView *)newSuperview {
    CGRect frame = self.frame;
    if (frame.size.height == 0) {
        frame.size.height = 43;
    }
    if (frame.size.width == 0) {
        frame.size.width = CGRectGetWidth(newSuperview.bounds);
    }
}

- (void)setArrowSize:(CGFloat)newArrowSize {
    arrowSize = newArrowSize;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    scrollView.frame = self.bounds;
    [self layoutSegments];
}

- (void)layoutSegments {
    // Cumulate total segment width
    CGFloat totalItemWidth = 0;
    for (SDSegmentView* item in self.items) {
        [item sizeThatFits:scrollView.bounds.size];
        if (item.customWidth > 0) {
            CGRect itemFrame = item.frame;
            itemFrame.size.width = item.customWidth;
            item.frame = itemFrame;
        }
        totalItemWidth += CGRectGetWidth(item.bounds);
    }
    CGFloat totalWidth = (totalItemWidth + (self.interItemSpace * (self.numberOfSegments - 1)));
    
    
    // Apply total to scrollView
    CGFloat pos = 0;
    CGSize contentSize = scrollView.contentSize;
    if (totalWidth > self.bounds.size.width) {
        // We must scroll, so add an offset
        totalWidth += 2 * kSDSegmentedControlScrollOffset;
        pos += kSDSegmentedControlScrollOffset;
        contentSize.width = totalWidth;
    } else {
        contentSize.width = self.bounds.size.width;
    }
    contentSize.height = self.bounds.size.height;
    scrollView.contentSize = contentSize;
    
    
    // Center all items horizontally and each item vertically
    const CGFloat spaceLeft  = scrollView.contentSize.width - totalWidth;
    const CGFloat itemHeight = scrollView.contentSize.height - self.arrowSize / 2;
    
    pos += spaceLeft / 2;
    for (int i=0; i<self.items.count; i++) {
        SDSegmentView* item = [self.items objectAtIndex:i];
        item.alpha = 1;
        item.frame = CGRectMake(pos, 0, CGRectGetWidth(item.bounds), itemHeight);
        pos += CGRectGetWidth(item.bounds) + self.interItemSpace;
    }
    
    
    // Layout stain view and update items
    BOOL animated = animationDuration > 0 && !CGRectEqualToRect(self.selectedStainView.frame, CGRectZero);
    BOOL isScrollingSinceNow = NO;
    
    CGFloat position;
    if (self.selectedSegmentIndex < 0) {
        self.selectedStainView.hidden = YES;
        position = CGFLOAT_MAX;
        [self updateItems];
    } else {
        NSUInteger     selectedIndex;
        SDSegmentView* selectedItem;
        if (panPositionX > 0) {
            selectedIndex = [self segmentIndexByPosition:panPositionX];
            selectedItem  = [self.items objectAtIndex:selectedIndex];
            position      = panPositionX;
        } else {
            selectedIndex = self.selectedSegmentIndex;
            selectedItem  = [self.items objectAtIndex:selectedIndex];
            position      = selectedItem.center.x;
        }
        
        UIView.animationsEnabled = animated;
        
        CGRect stainFrame = [self stainFrameForSegmentView:selectedItem];
        self.selectedStainView.hidden = NO;
        self.selectedStainView.layer.cornerRadius = stainFrame.size.height / 2;
        stainFrame.origin.x = position - stainFrame.size.width / 2;
        position -= scrollView.contentOffset.x;
        
        if (panPositionX > 0) {
            // If pan is in progress, scroll by a fixed amount
            CGPoint contentOffset     = scrollView.contentOffset;
            CGFloat fixedPanPositionX = panPositionX - contentOffset.x;
            CGFloat relPosition       = 0;
            if (fixedPanPositionX < kSDSegmentedControlScrollBorder) {
                relPosition = -fixedPanPositionX;
            } else if (fixedPanPositionX > CGRectGetMaxX(scrollView.bounds) - kSDSegmentedControlScrollBorder) {
                relPosition = CGRectGetMaxX(scrollView.bounds) - fixedPanPositionX;
            }
            if (relPosition != 0) {
                contentOffset.x += (relPosition < 0 ? -1 : 1) * kSDSegmentedControlScrollAmount;
                contentOffset.x = MAX(0, MIN(contentOffset.x, scrollView.contentSize.width));
                [scrollView setContentOffset:contentOffset animated:NO];
                
                if (!panScrollTimer) {
                    panScrollTimer = [NSTimer scheduledTimerWithTimeInterval:kSDSegmentedControlScrollTimeInterval
                                                                      target:self
                                                                    selector:@selector(panScrollTimer:)
                                                                    userInfo:nil
                                                                     repeats:YES];
                }
            }
        } else if (scrollView.contentSize.width > scrollView.bounds.size.width) {
            CGRect scrollRect = {scrollView.contentOffset, scrollView.bounds.size};
            CGRect targetRect = CGRectInset(stainFrame, -kSDSegmentedControlScrollOffset/2, 0);
            if (!CGRectContainsRect(scrollRect, targetRect)) {
                // Adjust position
                CGFloat posOffset = 0;
                if (CGRectGetMinX(targetRect) < CGRectGetMinX(scrollRect)) {
                    posOffset += CGRectGetMinX(scrollRect) - CGRectGetMinX(targetRect);
                } else if (CGRectGetMaxX(targetRect) > CGRectGetMaxX(scrollRect)) {
                    posOffset -= CGRectGetMaxX(targetRect) - CGRectGetMaxX(scrollRect);
                }
                
                // Recenter arrow with posOffset
                position += posOffset;
                
                // ...but not stainFrame because this causes a wrong position
                // in combination with a inserted segments.
                //stainFrame.origin.x += posOffset;
                
                // Temporary disable updates, if scrolling is needed, because scrollView will cause a
                // lot of relayouts. The field isScrollBySelection will be reseted by scrollView's delegate
                // call to scrollViewDidEndScrollingAnimation and can't be resetted after called, because
                // the animation is dispatched asynchronously, naturally.
                isScrollingBySelection = animated;
                isScrollingSinceNow    = YES;
                [scrollView scrollRectToVisible:targetRect animated:animated];
            }
        }
        
        [UIView animateWithDuration:animated ? animationDuration : 0
                         animations:^{
                             self.selectedStainView.frame = stainFrame;
                         }
                         completion:^(BOOL finished){
                             [self updateItems];
                         }];
        
        UIView.animationsEnabled = YES;
    }
    
    
    // Don't relayout paths while scrolling
    if (!isScrollingBySelection || isScrollingSinceNow) {
        // Animate paths only if pan gesture is not in progress
        animated &= panPositionX < 0;
        
        // Animate from a custom oldPosition if needed
        CGFloat oldPosition = CGFLOAT_MAX;
        if (animated && !pannedBefore && lastSelectedSegmentIndex != selectedSegmentIndex
            && lastSelectedSegmentIndex >= 0 && lastSelectedSegmentIndex < self.items.count) {
            SDSegmentView* lastSegmentView = [self.items objectAtIndex:lastSelectedSegmentIndex];
            oldPosition = lastSegmentView.center.x - scrollView.contentOffset.x;
        }
        pannedBefore = NO;
        
        [self drawPathsFromPosition:oldPosition toPosition:position animationDuration:animated ? self.animationDuration : 0];
    }
}

- (CGRect)stainFrameForSegmentView:(SDSegmentView *)segmentView {
    return UIEdgeInsetsInsetRect(segmentView.innerFrame, stainEdgeInsets);
}

- (void)updateItems {
    for (int i=0; i<self.items.count; i++) {
        SDSegmentView* item = [items objectAtIndex:i];
        item.selected = i == self.selectedSegmentIndex;
    }
}


#pragma mark - Draw paths
// Actually paths are not drawn here, instead they are relayouted

- (void)drawPathsToPosition:(CGFloat)position
                   animated:(BOOL)animated {
    [self drawPathsToPosition:position animationDuration:animated ? self.animationDuration : 0 completion:nil];
}

- (void)drawPathsToPosition:(CGFloat)position
          animationDuration:(CFTimeInterval)duration completion:(void (^)(void))completion {
    [self drawPathsFromPosition:CGFLOAT_MAX toPosition:position animationDuration:duration completion:completion];
}

- (void)drawPathsFromPosition:(CGFloat)oldPosition toPosition:(CGFloat)position animationDuration:(CFTimeInterval)duration {
    [self drawPathsFromPosition:oldPosition toPosition:position animationDuration:duration completion:nil];
}

- (void)drawPathsFromPosition:(CGFloat)oldPosition toPosition:(CGFloat)position
            animationDuration:(CFTimeInterval)duration completion:(void (^)(void))completion {
    // Bounds
    const CGRect bounds  = self.bounds;
    const CGFloat left   = CGRectGetMinX(bounds);
    const CGFloat right  = CGRectGetMaxX(bounds);
    const CGFloat top    = CGRectGetMinY(bounds);
    const CGFloat bottom = CGRectGetMaxY(bounds);
    
    // Mask
    __block UIBezierPath* path = UIBezierPath.new;
    [path moveToPoint:CGPointMake(left, top)];
    [self addArrowAtPoint:CGPointMake(position, bottom) toPath:path withLineWidth:0.0];
    [path addLineToPoint:CGPointMake(right, top)];
    [path addLineToPoint:CGPointMake(left, top)];
    
    // Shadow mask
    __block UIBezierPath* shadowPath = UIBezierPath.new;
    [shadowPath moveToPoint:CGPointMake(left, top)];
    [self addArrowAtPoint:CGPointMake(position, bottom) toPath:shadowPath withLineWidth:0.0];
    [shadowPath addLineToPoint:CGPointMake(right, top)];
    [shadowPath addLineToPoint:CGPointMake(left, top)];
    
    // Bottom white line
    borderBottomLayer.frame = self.bounds;
    __block UIBezierPath* borderBottomPath = UIBezierPath.new;
    const CGFloat lineY = bottom - borderBottomLayer.lineWidth;
    [self addArrowAtPoint:CGPointMake(position, lineY) toPath:borderBottomPath withLineWidth:borderBottomLayer.lineWidth];
    
    // Skip current animations and ensure the completion block was applied
    // otherwise this will end up in ugly effects if the selection was changed very fast
    [self.layer removeAllAnimations];
    [borderBottomLayer removeAllAnimations];
    if (lastCompletionBlock) {
        lastCompletionBlock();
    }
    
    // Build block
    void(^assignLayerPaths)() = ^{
        ((CAShapeLayer *)self.layer).path = path.CGPath;
        self.layer.shadowPath             = shadowPath.CGPath;
        borderBottomLayer.path            = borderBottomPath.CGPath;
        
        // Dereference itself to be not executed twice
        lastCompletionBlock = nil;
    };
    
    __block void(^animationCompletion)(); 
    if (!completion) {
        animationCompletion = assignLayerPaths;
    } else {
        animationCompletion = ^{
            assignLayerPaths();
            completion();
        };
    }
    
    // Apply new paths
    if (duration > 0) {
        // That's a bit fragile: we detect stop animation call by duration!
        NSString* timingFuncName = duration < self.animationDuration
            ? kCAMediaTimingFunctionEaseIn
            : kCAMediaTimingFunctionEaseInEaseOut;
        
        // Check if we have to do a stop animation, which means that we first
        // animate to have a fully visible arrow and then move the arrow.
        // Otherwise there will be ugly effects.
        CFTimeInterval stopDuration = -1;
        CGFloat        stopPosition = -1; 
        if (oldPosition < CGFLOAT_MAX) {
            if (oldPosition < left+self.arrowSize) {
                stopPosition = left+self.arrowSize;
            } else if (oldPosition > right-self.arrowSize) {
                stopPosition = right-self.arrowSize;
            }
            
            if (stopPosition > 0) {
                float relStopDuration = ABS((stopPosition - oldPosition) / (position - oldPosition));
                if (relStopDuration > 1) {
                    relStopDuration = 1.0 / relStopDuration;
                }
                stopDuration = duration * relStopDuration;
                duration -= stopDuration;
                timingFuncName  = kCAMediaTimingFunctionEaseOut;
            }
        }
        
        void (^animation)() = ^{
            [CATransaction begin];
            [CATransaction setAnimationDuration:duration];
            CAMediaTimingFunction* timing = [CAMediaTimingFunction functionWithName:timingFuncName];
            [CATransaction setAnimationTimingFunction:timing];
            [CATransaction setCompletionBlock:animationCompletion];
            
            [self addAnimationWithDuration:duration onLayer:self.layer        forKey:@"path"   toPath:path];
            [self addAnimationWithDuration:duration onLayer:self.layer        forKey:@"shadow" toPath:shadowPath];
            [self addAnimationWithDuration:duration onLayer:borderBottomLayer forKey:@"path"   toPath:borderBottomPath];
            
            [CATransaction commit];
        };
        
        if (stopPosition > 0) {
            [self drawPathsToPosition:stopPosition animationDuration:stopDuration completion:animation];
        } else {
            animation();
        }
        
        // Remember completion block
        lastCompletionBlock = assignLayerPaths;
    } else {
        assignLayerPaths();
    }
}

- (void)addAnimationWithDuration:(CFTimeInterval)duration onLayer:(CALayer *)layer forKey:(NSString *)key toPath:(UIBezierPath *)path {
    NSString* camelCaseKeyPath;
    NSString* keyPath;
    if (key == @"path") {
        camelCaseKeyPath = key;
        keyPath          = key;
    } else {
        camelCaseKeyPath = [NSString stringWithFormat:@"%@Path", key];
        keyPath          = [NSString stringWithFormat:@"%@.path", key];
    }
    
    CABasicAnimation* pathAnimation = [CABasicAnimation animationWithKeyPath:camelCaseKeyPath];
    pathAnimation.removedOnCompletion = NO;
    pathAnimation.fillMode            = kCAFillModeForwards;
    pathAnimation.duration            = duration;
    pathAnimation.fromValue           = [layer valueForKey:keyPath];
    pathAnimation.toValue             = (id)path.CGPath;
    [layer addAnimation:pathAnimation forKey:key];
}

- (void)addArrowAtPoint:(CGPoint)point toPath:(UIBezierPath *)path withLineWidth:(CGFloat)lineWidth {
    // The arrow is added like below, whereas P is the point argument
    // and 1-5 are the points which were added to the path. It must be
    // always five points, otherwise animations will look ugly.
    //
    // P: point.x
    // s: self.arrowSize - line.width
    // w: self.bounds.size.width
    //
    //
    //   s < P < w-s:      P < -s:         P = MAX:       w+s < P: 
    //   
    //        3
    //       / \
    //      /   \
    //  1--2  P  4--5   1234--------5   1--2--3--4--5   1--------2345   
    //
    //
    //    0 < P < s:       -s < P:
    //
    //     3            
    //    / \           123
    //  12   \             \
    //     P  4-----5    P  4------5
    //
    
    const CGFloat left   = CGRectGetMinX(self.bounds);
    const CGFloat right  = CGRectGetMaxX(self.bounds);
    const CGFloat center = (right-left) / 2;
    const CGFloat width  = self.arrowSize - lineWidth;
    const CGFloat height = self.arrowSize + lineWidth/2;
    
    __block NSMutableArray* points = NSMutableArray.new;
    BOOL hasCustomLastPoint = NO;
    
    void (^addPoint)(CGFloat x, CGFloat y) = ^(CGFloat x, CGFloat y) {
        [points addObject:[NSValue valueWithCGPoint:CGPointMake(x, y)]];
    };
    
    // Add first point
    addPoint(left, point.y);
    
    if (point.x >= left+width && point.x <= right-width) {
        // Arrow is completely inside the view
        addPoint(point.x - width, point.y);
        addPoint(point.x,         point.y - height);
        addPoint(point.x + width, point.y);
    } else {
        // Just some tricks, to allow correctly cutted arrows and
        // to have always a proper animation.
        if (point.x <= left-width) {
            // Left aligned points
            addPoint(left + 0.01, point.y);
            addPoint(left + 0.02, point.y);
            addPoint(left + 0.03, point.y);
        } else if (point.x < left+width && point.x > left-width) {
            // Left cutted arrow
            [points removeAllObjects]; // Custom first point
            if (point.x < left) {
                CGFloat x = width + point.x;
                addPoint(left,        point.y - x);
                addPoint(left + 0.01, point.y - x + 0.01);
                addPoint(left + 0.02, point.y - x + 0.02);
                addPoint(left + x,    point.y);
            } else {    
                CGFloat x = width - point.x;
                addPoint(left,            point.y - x);
                addPoint(left + 0.01,     point.y - x + 0.01);
                addPoint(point.x,         point.y - height);
                addPoint(point.x + width, point.y);
            }
        } else if (point.x == CGFLOAT_MAX) {
            // Centered "arrow", with zero height
            addPoint(center - width, point.y);
            addPoint(center,         point.y);
            addPoint(center + width, point.y);
        } else if (point.x < right+width && point.x > right-width) {
            // Right cutted arrow, is like left cutted arrow but:
            //  * swapped if/else case
            //  * inverse point order
            //  * other calculation of x
            hasCustomLastPoint = YES; // Custom last point
            if (point.x < right) {
                CGFloat x = width - (right - point.x);
                addPoint(point.x - width, point.y);
                addPoint(point.x,         point.y - height);
                addPoint(right - 0.01,    point.y - x + 0.01);
                addPoint(right,           point.y - x);
            } else {
                CGFloat x = width + (right - point.x);
                addPoint(right - x,    point.y);
                addPoint(right - 0.02, point.y - x + 0.02);
                addPoint(right - 0.01, point.y - x + 0.01);
                addPoint(right,        point.y - x);
            }
        } else {
            // Right aligned points
            addPoint(right - 0.03, point.y);
            addPoint(right - 0.02, point.y);
            addPoint(right - 0.01, point.y);
        }
    }
    
    // Add points from array to path
    CGPoint node = ((NSValue *)[points objectAtIndex:0]).CGPointValue;
    if (path.isEmpty) {
        [path moveToPoint:node];
    } else {
        [path addLineToPoint:node];
    }
    for (int i=1; i<points.count; i++) {
        node = ((NSValue *)[points objectAtIndex:i]).CGPointValue;
        [path addLineToPoint:node];
    }
    
    // Add last point of not replaced
    if (!hasCustomLastPoint) {
        [path addLineToPoint:CGPointMake(right, point.y)];
    }
}


#pragma mark - Interaction

- (void)handleSelect:(SDSegmentView *)view {
    NSUInteger index = [self.items indexOfObject:view];
    if (index != NSNotFound) {
        self.selectedSegmentIndex = index;
        [self setNeedsLayout];
        [self sendActionsForControlEvents:UIControlEventValueChanged];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (!panIsEnabled) {
        return YES;
    }
    if (otherGestureRecognizer == scrollView.panGestureRecognizer) {
        return NO;
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (self.items.count == 0 || !panIsEnabled) {
        return NO;
    }
    if (panPositionX > 0) {
        return YES;
    }
    CGPoint position = [touch locationInView:scrollView];
    if (CGRectContainsPoint(self.selectedSegment.frame, position)) {
        return YES;
    }
    return NO;
}

- (void)handleSlide:(UIPanGestureRecognizer *)gestureRecognizer {
    if (self.items.count == 0 || !panIsEnabled) {
        return;
    }
    
    CGPoint panPosition       = [gestureRecognizer locationInView:scrollView];
    panPositionX              = panPosition.x;
    lastSelectedSegmentIndex  = -1;
    NSInteger pannedItemIndex = [self segmentIndexByPosition:panPosition.x];
    SDSegmentView* segment    = [self segmentAtIndex:pannedItemIndex];
    
    if ([delegate respondsToSelector:@selector(sdSegmentedControl:didPannedToPosition:)]) {
        [delegate sdSegmentedControl:self didPannedToPosition:panPositionX];
    }
    if ([delegate respondsToSelector:@selector(sdSegmentedControl:didPannedToSegmentIndex:)]) {
        [delegate sdSegmentedControl:self didPannedToSegmentIndex:pannedItemIndex];
    }
    
    // Apply selected index or reset
    if (segment.enabled && gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        self.selectedSegmentIndex = pannedItemIndex;
        [self sendActionsForControlEvents:UIControlEventValueChanged];
    }
    
    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateFailed:
            panPositionX = -1;
            pannedBefore = YES;
            if (panScrollTimer) {
                [panScrollTimer invalidate];
                panScrollTimer = nil;
            }
            break;
            
        default:
            // Do nothing, just to silence warnings!
            break;
    }
    
    [self setNeedsLayout];
}

- (void)panScrollTimer:(NSTimer *)timer {
    [self setNeedsLayout];
}


#pragma mark - ScrollViewDelegate's implementation

- (void)scrollViewDidScroll:(UIScrollView *)aScrollView {
    if (isScrollingBySelection) {
        return;
    }
    CGFloat position;
    if (panPositionX > 0) {
        position = panPositionX;
    } else {
        position = self.selectedSegment.center.x;
    }
    [self drawPathsToPosition:position - scrollView.contentOffset.x animated:NO];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    isScrollingBySelection = NO;
}

@end


#pragma mark - SDSegmentView as dedicated class if needed

#ifdef SDStrategyInherit
    @implementation SDSegmentView

    + (id)appearance {
        return [self appearanceWhenContainedIn:SDSegmentedControl.class, nil];
    }

    @end
#endif


#pragma mark - SDPrivateSegmentView as bridge

@implementation SDPrivateSegmentView

+ (SDPrivateSegmentView *)new {
    return [[self class] buttonWithType:UIButtonTypeCustom];
}

@end


#pragma mark - Private category on SDSegmentView with needed behavior

@implementation SDSegmentView (Private)

static char wasRemovedKey;
static char customWidthKey;

@dynamic wasRemoved;
@dynamic customWidth;

+ (id)appearance {
    return [self appearanceWhenContainedIn:SDSegmentedControl.class, nil];
}

- (void)setWasRemoved:(BOOL)wasRemoved {
    objc_setAssociatedObject(self,
                             &wasRemovedKey,
                             [NSNumber numberWithBool:wasRemoved],
                             OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)wasRemoved {
    return ((NSNumber *)objc_getAssociatedObject(self, &wasRemovedKey)).boolValue;
}

- (void)setCustomWidth:(CGFloat)width {
    objc_setAssociatedObject(self,
                             &customWidthKey,
                             [NSNumber numberWithFloat:width],
                             OBJC_ASSOCIATION_RETAIN);
}

- (CGFloat)customWidth {
    return ((NSNumber *)objc_getAssociatedObject(self, &customWidthKey)).floatValue;
}

- (CGRect)innerFrame {
    const CGPoint origin = self.frame.origin;
    CGRect innerFrame = CGRectOffset(self.titleLabel.frame, origin.x, origin.y);
    
    if (innerFrame.size.width > 0) {
        innerFrame.size.width =
              self.titleEdgeInsets.left
            + self.titleLabel.frame.size.width
            + self.titleEdgeInsets.right;
    }
    
    if ([self imageForState:self.state]) {
        const CGRect imageViewFrame = self.imageView.frame;
        if (innerFrame.size.height > 0) {
            innerFrame.origin.y -= (imageViewFrame.size.height - innerFrame.size.height) / 2;
        } else {
            innerFrame.origin.y = imageViewFrame.origin.y;
        }
        innerFrame.size.height = imageViewFrame.size.height;
        innerFrame.size.width +=
              self.imageEdgeInsets.left
            + imageViewFrame.size.width
            + self.imageEdgeInsets.right;
    }
    
    return innerFrame;
}

@end

    
#pragma mark - SDStainView

@implementation SDStainView

@synthesize cornerRadius;
@synthesize edgeInsets;
@synthesize shadowOffset;
@synthesize shadowBlur;
@synthesize shadowColor;


+ (id)appearance {
    return [self appearanceWhenContainedIn:SDSegmentedControl.class, nil];
}

- (id)init {
    self = [super init];
    if (self) {
        self.clipsToBounds = YES;
        
        edgeInsets   = UIEdgeInsetsMake(-0.5, -0.5, -0.5, -0.5);
        shadowOffset = CGSizeMake(0.0, 0.5);
        shadowBlur   = 2.5;
        shadowColor  = UIColor.blackColor;
    }
    return self;
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGPathRef roundedRect = [UIBezierPath bezierPathWithRoundedRect:UIEdgeInsetsInsetRect(rect, self.edgeInsets)
                                                       cornerRadius:self.layer.cornerRadius].CGPath;
    CGContextAddPath(context, roundedRect);
    CGContextClip(context);
    
    CGContextAddPath(context, roundedRect);
    CGContextSetShadowWithColor(UIGraphicsGetCurrentContext(), self.shadowOffset, self.shadowBlur, self.shadowColor.CGColor);
    CGContextSetStrokeColorWithColor(context, self.backgroundColor.CGColor);
    CGContextStrokePath(context);
}

@end
