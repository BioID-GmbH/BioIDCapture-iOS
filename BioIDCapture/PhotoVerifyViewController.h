//
//  PhotoVerifyViewController.h
//  BioIDCapture
//
//  Copyright © 2024 BioID. All rights reserved.

#ifndef PhotoVerifyViewController_h
#define PhotoVerifyViewController_h

#import <UIKit/UIKit.h>

#import "BWS3Settings.h"
#import "BioIDHelper.h"
#import "BioIDCaptureViewController.h"
#import "ResultViewController.h"

@interface PhotoVerifyViewController : UIViewController<BioIDCaptureViewControllerDelegate, NSURLSessionDataDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate>

- (IBAction)captureIDPhoto:(id)sender;
- (IBAction)process:(id)sender;

@property (weak, nonatomic) IBOutlet UITextView *introduction;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewer1;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewer2;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewer3;
@property (weak, nonatomic) IBOutlet UIButton *captureLivePhotos;
@property (weak, nonatomic) IBOutlet UIButton *captureSinglePhoto;
@property (weak, nonatomic) IBOutlet UIButton *captureIDPhoto;
@property (weak, nonatomic) IBOutlet UIButton *process;

@end

#endif /* PhotoVerifyViewController_h */
