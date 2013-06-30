/*
 JNJProgressButton
 
 Copyright (c) 2013 Josh Johnson <jnjosh@jnjosh.com>
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
 of the Software, and to permit persons to whom the Software is furnished to do
 so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

#import "JNJProgressButton.h"
#import <QuartzCore/QuartzCore.h>

static CGFloat const kJNJProgressCircleSize = 20.0f;

@interface JNJProgressButton ()

@property (nonatomic, assign, readwrite) JNJProgressButtonState state;
@property (nonatomic, strong) NSMutableDictionary *imageStateStore;

@property (nonatomic, strong) UIImageView *startButtonImageView;
@property (nonatomic, strong) UIImageView *endButtonImageView;

@property (nonatomic, strong) CAShapeLayer *progressButtonLayer;

@end

@implementation JNJProgressButton

#pragma mark - Life Cycle

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    self.state = JNJProgressButtonStateUnstarted;
    self.imageStateStore = [NSMutableDictionary dictionary];
    [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(progressButtonWasTapped:)]];
    
    self.startButtonImageView = [UIImageView new];
    [self addSubview:self.startButtonImageView];
    self.endButtonImageView = [UIImageView new];
    [self addSubview:self.endButtonImageView];
}

#pragma mark - Properties

- (UIColor *)tintColor
{
    if (!_tintColor) {
        _tintColor = [UIColor blackColor];
    }
    return _tintColor;
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGPoint center = (CGPoint) { CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds) };
    self.startButtonImageView.center = center;
    self.endButtonImageView.center = center;
}

#pragma mark - Accessibility

- (BOOL)isAccessibilityElement
{
    return YES;
}

- (UIAccessibilityTraits)accessibilityTraits
{
    return [super accessibilityTraits] | UIAccessibilityTraitButton;
}

#pragma mark - Progress

- (void)setProgress:(float)progress animated:(BOOL)animated
{
    self.progress = progress;
}

#pragma mark - Action

- (void)progressButtonWasTapped:(UIGestureRecognizer *)gestureRecognizer
{
    if (self.state == JNJProgressButtonStateUnstarted) {
        [self startProgress];
        
        if ([self.delegate respondsToSelector:@selector(progressButtonStartButtonTapped:)]) {
            [self.delegate progressButtonStartButtonTapped:self];
        }
    } else if (self.state == JNJProgressButtonStateProgressing) {
        [self cancelProgress];
        
        if ([self.delegate respondsToSelector:@selector(progressButtonDidCancelProgress:)]) {
            [self.delegate progressButtonDidCancelProgress:self];
        }
    } else if (self.state == JNJProgressButtonStateFinished) {
        if ([self.delegate respondsToSelector:@selector(progressButtonEndButtonTapped:)]) {
            [self.delegate progressButtonEndButtonTapped:self];
        }
    }
}

#pragma mark - Button Images

- (void)setButtonImage:(UIImage *)image
      highlightedImage:(UIImage *)highlightImage
              forState:(JNJProgressButtonState)state
{
    NSParameterAssert(image);
    
    [self.imageStateStore setObject:image forKey:@(state)];
    
    if (highlightImage) {
        [self.imageStateStore setObject:highlightImage forKey:@(state)];
    }
    
    self.startButtonImageView.image = [self.imageStateStore objectForKey:@(JNJProgressButtonStateUnstarted)];
    self.startButtonImageView.frame = (CGRect) { CGPointZero, self.startButtonImageView.image.size };
    self.endButtonImageView.image = [self.imageStateStore objectForKey:@(JNJProgressButtonStateFinished)];
    self.endButtonImageView.frame = (CGRect) { CGPointZero, self.endButtonImageView.image.size };
    self.startButtonImageView.hidden = !(self.state == JNJProgressButtonStateUnstarted);
    self.endButtonImageView.hidden = !(self.state == JNJProgressButtonStateFinished);
}

#pragma mark - Actions

- (void)startProgress
{
    self.state = JNJProgressButtonStateProgressing;

    [UIView animateWithDuration:0.2 animations:^{
        self.startButtonImageView.alpha = 0.0f;
        self.startButtonImageView.transform = CGAffineTransformMakeScale(0.5f, 0.5f);
    }];
    
    [self startPreprogress];
}

- (void)cancelProgress
{
    self.state = JNJProgressButtonStateUnstarted;
    
    CABasicAnimation *shrinkAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    shrinkAnimation.toValue = @0.0f;
    shrinkAnimation.duration = 0.25f;
    [self.progressButtonLayer addAnimation:shrinkAnimation forKey:@"shrinkProgress"];
    self.progressButtonLayer.transform = CATransform3DMakeScale(0, 0, 0);
    
    [UIView animateWithDuration:0.2 animations:^{
        self.startButtonImageView.alpha = 1.0f;
        self.startButtonImageView.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        [self.progressButtonLayer removeFromSuperlayer];
        self.progressButtonLayer = nil;
    }];
}

- (void)startPreprogress
{
    UIColor *strokeColor = self.tintColor;
    UIColor *glowColor = [self glowColorForTintColor];
    CGRect circleRect = [self rectForProgressCircle];
    
    self.progressButtonLayer = [self circleLayerWithRect:circleRect
                                             strokeColor:strokeColor
                                             shadowColor:glowColor];
    self.progressButtonLayer.frame = self.bounds;
    [self.layer addSublayer:self.progressButtonLayer];

    CAAnimationGroup *growAnimationGroup = [CAAnimationGroup animation];
    {
        CABasicAnimation *growAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        growAnimation.fromValue = @0.0f;
        CABasicAnimation *fadeAnimation = [CABasicAnimation animationWithKeyPath:@"fillColor"];
        fadeAnimation.fromValue = (__bridge id)(glowColor.CGColor);
        fadeAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
        growAnimationGroup.animations = @[ growAnimation, fadeAnimation ];
    }
    growAnimationGroup.duration = 0.25f;
    growAnimationGroup.removedOnCompletion = YES;
    [self.progressButtonLayer addAnimation:growAnimationGroup forKey:@"scale"];
    
    CABasicAnimation *rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotationAnimation.fromValue = @0.0f;
    rotationAnimation.toValue = @(M_PI * 2);
    rotationAnimation.repeatCount = CGFLOAT_MAX;
    rotationAnimation.duration = 1.0f;
    [self.progressButtonLayer addAnimation:rotationAnimation forKey:@"rotate"];
}

#pragma mark - Helpers

- (CGRect)rectForProgressCircle
{
    return (CGRect) {
        CGRectGetMidX(self.bounds) - kJNJProgressCircleSize / 2.0f,
        CGRectGetMidY(self.bounds) - kJNJProgressCircleSize / 2.0f,
        kJNJProgressCircleSize,
        kJNJProgressCircleSize
    };
}

- (CAShapeLayer *)circleLayerWithRect:(CGRect)circleRect
                          strokeColor:(UIColor *)strokeColor
                          shadowColor:(UIColor *)shadowColor
{
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:circleRect];
    CAShapeLayer *circleLayer = [CAShapeLayer new];
    circleLayer.masksToBounds = NO;
    circleLayer.path = path.CGPath;
    circleLayer.fillColor = [UIColor clearColor].CGColor;
    circleLayer.strokeColor = strokeColor.CGColor;
    circleLayer.lineWidth = 1.0f;
    circleLayer.strokeEnd = 0.9;
    circleLayer.shadowPath = path.CGPath;
    circleLayer.shadowColor = shadowColor.CGColor;
    circleLayer.shadowOpacity = 0.1f;
    circleLayer.shadowRadius = kJNJProgressCircleSize / 2.0f;
    circleLayer.shadowOffset = CGSizeZero;
    circleLayer.shouldRasterize = YES;
    circleLayer.rasterizationScale = [[UIScreen mainScreen] scale];
    circleLayer.anchorPoint = (CGPoint) { 0.5f, 0.5f };
    return circleLayer;
}

- (UIColor *)glowColorForTintColor
{
    UIColor *glowColor = nil;
    UIColor *tintColor = self.tintColor;

    CGFloat hue, saturation, brightness, alpha;
    if ([tintColor getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha]) {
        glowColor = [UIColor colorWithHue:hue
                               saturation:saturation * 0.7f
                               brightness:brightness
                                    alpha:0.8f];
    }
    
    return glowColor;
}

- (void)setImageViewAlphaIfNeeded:(CGFloat)alpha
{
    if (self.state == JNJProgressButtonStateUnstarted) {
        self.startButtonImageView.alpha = alpha;
    }
    
    if (self.state == JNJProgressButtonStateFinished) {
        self.endButtonImageView.alpha = alpha;
    }
}

#pragma mark - Touch Handling

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    [self setImageViewAlphaIfNeeded:0.5f];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    [self setImageViewAlphaIfNeeded:1.0f];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    [self setImageViewAlphaIfNeeded:1.0f];
}

@end
