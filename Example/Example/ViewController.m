//
//  ViewController.m
//  Example
//
//  Created by Olivier Poitrey on 26/09/12.
//  Copyright (c) 2012 Hackemist. All rights reserved.
//

#import "ViewController.h"
#import "SDSegmentedControl.h"


@implementation ViewController

@synthesize segmentedControl;
@synthesize selectedSegmentLabel;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    addCount = 0;
    
    // Try appearance API
    [SDSegmentedControl.appearance setArrowSize:8.0];
    [SDSegmentedControl.appearance setInterItemSpace:15.0];
    [SDSegmentedControl.appearance setImageSize:CGSizeMake(24, 24)];
    [SDSegmentView.appearance setFont:[UIFont systemFontOfSize:14]];
    [SDSegmentView.appearance setTitleColor:UIColor.blackColor forState:UIControlStateSelected];
    
    // Just enlarge the frame in the height for larger images
    // and pad it on left and right to see correct borders
    // and animation behavior.
    CGRect frame = segmentedControl.frame;
    frame.size.height += 8;
    frame.size.width  -= 16;
    frame.origin.x    += 8;
    segmentedControl.frame = frame;
    
    [self.segmentedControl setTitle:@"Messages" forSegmentAtIndex:0];
    [self.segmentedControl setTitle:@"History"  forSegmentAtIndex:1];
    [self.segmentedControl setTitle:@"License"  forSegmentAtIndex:2];
    
    [self.segmentedControl setImage:[UIImage imageNamed:@"08-chat"]  forSegmentAtIndex:0];
    [self.segmentedControl setImage:[UIImage imageNamed:@"11-clock"] forSegmentAtIndex:1];
    [self.segmentedControl setImage:[UIImage imageNamed:@"24-gift"]  forSegmentAtIndex:2];
    
    [self.segmentedControl setEnabled:NO forSegmentAtIndex:1];
    
    [self updateSelectedSegmentLabel];
}

- (void)updateSelectedSegmentLabel {
    self.selectedSegmentLabel.text = [NSString stringWithFormat:@"%d", self.segmentedControl.selectedSegmentIndex];
}

- (IBAction)segmentDidChange:(id)sender {
    [self updateSelectedSegmentLabel];
}

- (IBAction)removeSegment:(id)sender {
    [self.segmentedControl removeSegmentAtIndex:0 animated:YES];
    [self updateSelectedSegmentLabel];
}

- (IBAction)addSegment:(id)sender {
    addCount++;
    if (addCount % 4 == 0) {
        [self.segmentedControl insertSegmentWithTitle:@"New" atIndex:0 animated:YES];
    } else if (addCount % 4 == 1) {
        [(SDSegmentedControl *)self.segmentedControl insertSegmentWithTitle:@"New"
                                                                      image:[UIImage imageNamed:@"13-target"]
                                                                    atIndex:0
                                                                   animated:YES];
    } else if (addCount % 4 == 2) {
        [self.segmentedControl insertSegmentWithImage:[UIImage imageNamed:@"13-target"] atIndex:0 animated:YES];
    } else if (addCount % 4 == 3) {
        [self.segmentedControl insertSegmentWithTitle:@"Custom Width" atIndex:0 animated:YES];
        [self.segmentedControl setWidth:200.0 forSegmentAtIndex:0];
    }
    [self updateSelectedSegmentLabel];
}

@end
