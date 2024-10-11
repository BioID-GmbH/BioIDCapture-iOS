//
//  ChallengeViewController.h
//  BioIDCapture
//
//  Copyright © 2024 BioID. All rights reserved.

#ifndef ChallengeViewController_h
#define ChallengeViewController_h

#import <UIKit/UIKit.h>

#import "BWS3Settings.h"
#import "BioIDHelper.h"
#import "BioIDCaptureViewController.h"
#import "ResultViewController.h"

@interface ChallengeViewController : UIViewController<BioIDCaptureViewControllerDelegate, NSURLSessionDataDelegate>

- (IBAction)process:(id)sender;

@property (weak, nonatomic) IBOutlet UITextView *introduction;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewer1;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewer2;
@property (weak, nonatomic) IBOutlet UIButton *capturePhotos;
@property (weak, nonatomic) IBOutlet UIButton *process;

@end

NSArray *challenges = nil;
NSString* currentChallenge = nil;
                       
#endif /* ChallengeViewController_h */
