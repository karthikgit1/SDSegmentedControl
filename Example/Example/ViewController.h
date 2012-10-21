//
//  ViewController.h
//  Example
//
//  Created by Olivier Poitrey on 26/09/12.
//  Copyright (c) 2012 Hackemist. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface ViewController : UIViewController {
    int addCount;
}

@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentedControl;
- (IBAction)segmentDidChange:(id)sender;
@property (weak, nonatomic) IBOutlet UILabel *selectedSegmentLabel;
- (IBAction)removeSegment:(id)sender;
- (IBAction)addSegment:(id)sender;

@end
