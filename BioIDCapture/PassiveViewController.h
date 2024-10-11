//
//  PassiveViewController.h
//  BioIDCapture
//
//  Copyright © 2024 BioID. All rights reserved.
//

#ifndef PassiveViewController_h
#define PassiveViewController_h

#import <UIKit/UIKit.h>

#import "BWS3Settings.h"
#import "BioIDHelper.h"
#import "ResultViewController.h"

@interface PassiveViewController : UIViewController<UINavigationControllerDelegate, UIImagePickerControllerDelegate, NSURLSessionDataDelegate>

- (IBAction)capturePhoto:(id)sender;
- (IBAction)process:(id)sender;

@property (weak, nonatomic) IBOutlet UITextView *introduction;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewer;
@property (weak, nonatomic) IBOutlet UIButton *process;

@end

#endif /* PassiveViewController_h */
