//
//  ChallengeViewController.m
//  BioIDCapture
//
//  Copyright © 2024 BioID. All rights reserved.

#import "ChallengeViewController.h"

@interface ChallengeViewController ()

@end

@implementation ChallengeViewController

// Called after the controller`s view is loaded into memory.
- (void)viewDidLoad {
    [super viewDidLoad];

    // Disable the "Process" button
    [_process setEnabled:false];
    
    // Create array for possible challenges
    challenges = [NSArray arrayWithObjects:
                  @"Up",
                  @"down",
                  @"left",
                  @"right",
    nil];
}

// The "Capture photo" button was tapped.
- (IBAction)capturePhotos:(id)sender {
    
    // clear imageViewers
    [_imageViewer1 setImage:nil];
    [_imageViewer2 setImage:nil];
    
    // Ask for camera permission
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus == AVAuthorizationStatusNotDetermined) {
        NSLog(@"Camera access not determined. Ask for permission");
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^(void) {[self performSegueWithIdentifier:@"showBioIDCaptureView" sender:self];});
        }];
    }
    else {
        [self performSegueWithIdentifier:@"showBioIDCaptureView" sender:self];
    }
}

// The "Process" button was tapped.
- (IBAction)process:(id)sender {
    
   if (_imageViewer1.image != nil && _imageViewer2.image != nil) {
       
       // Disable the "Process" button
       [_process setEnabled:false];
       
       // Get images from viewers
       UIImage* liveImage1 = _imageViewer1.image;
       UIImage* liveImage2 = _imageViewer2.image;
       
       // Perfom Active Liveness Detection with Challenge Response
       [self performChallengeResonse:liveImage1 withSecondImage:liveImage2 withTags:currentChallenge];
   }
}

// Notifies the ChallengeViewController that a seque is about to be performed.
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    if ([[segue identifier] isEqualToString:@"showBioIDCaptureView"]) {
        BioIDCaptureViewController *viewController = [segue destinationViewController];
        
        // Random generator based on existing challengs
        uint32_t rnd = arc4random_uniform((int)[challenges count]);
        
        // Set random challenge of predefined challenges
        currentChallenge = [challenges objectAtIndex:rnd];
        viewController.challengeTag = currentChallenge;
        viewController.callback = self;
    }
}

// BioIDCaptureController callback when images have been captured.
- (void)capturingFinished:(UIImage *)image1 secondImage:(UIImage *)image2 {
   
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        // Hide introduction view
        [self->_introduction setHidden:true];
        
        // Set captured images to viewers
        [self->_imageViewer1 setImage:image1];
        [self->_imageViewer2 setImage:image2];
       
        // Enable the "Process" button
        [self->_process setEnabled:true];
    });
}

// BioIDCaptureController callback for failed capturing with error code.
- (void)capturingFailed:(int)errorCode {
   
    NSString* errorMessage;
    switch(errorCode) {
        case BIOID_NO_CAMERA_ACCESS:
            errorMessage = @"No camera access.";
            break;
        case BIOID_NO_FACE_FOUND:
            errorMessage = @"No face found.";
            break;
        case BIOID_NO_MOTION_DETECTED:
            errorMessage = @"No motion detected.";
            break;
        default: // should not reach
            errorMessage = @"Unkown error";
            break;
    }
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"BWSCapture Error"
                                                                       message:errorMessage
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {}];
        [alert addAction:defaultAction];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

// Performs a active liveness detection with two live images with tagged second image.
- (void)performChallengeResonse:(UIImage *)liveImage1 withSecondImage:(UIImage *)liveImage2 withTags:(NSString *)tags {
   
    // Test server: REST-GRPC Forwarder endpoint
    NSURL* baseUrl = [NSURL URLWithString:BWS3_REST_GRPC_ENDPOINT];
    NSURL *url = [NSURL URLWithString:BWS3_TASK_LIVENESSDETECTION relativeToURL:baseUrl];
    NSLog(@"%@", url.absoluteURL);

    // Resize images before sending!!!
    UIImage* resizedLiveImage1 = [BioIDHelper resizeImageForUpload:liveImage1];
    UIImage* resizedLiveImage2 = [BioIDHelper resizeImageForUpload:liveImage2];
    
    // Create JSON Request Body with the help of the BioIDHelper
    NSData *jsonData = [BioIDHelper createJSONRequestBody:resizedLiveImage1 withSecondLiveImage:resizedLiveImage2 withSecondLiveImageTags:tags];

    // Create Reqeust object
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url.absoluteURL];
  
    // Set HTTP header fields
    [request setHTTPMethod:@"POST"];
    [request setValue:BWS3_REST_GRPC_APIKEY forHTTPHeaderField:@"ApiKey"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    // Optional, client specific reference number
    [request setValue:@"BioIDCapture-iOS" forHTTPHeaderField:@"Reference-Number"];
    // Set HTTP body with created JSON data
    [request setHTTPBody:jsonData];
    
    // Create NSURLSession object for network data transfer
    NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration:[self sessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    NSURLSessionDataTask *dataTask = [defaultSession dataTaskWithRequest:request];
    
    // Start the connection
    [dataTask resume];
}

#pragma mark - URLSessions

- (NSURLSessionConfiguration *)sessionConfiguration {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.URLCache = [[NSURLCache alloc] initWithMemoryCapacity:0 diskCapacity:0 diskPath:nil];
    return config;
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    
    completionHandler(NSURLSessionResponseAllow);
    
    NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
   
    if (statusCode != 200) {
        
        switch (statusCode) {
            case 400:
                NSLog(@"Bad Request");
                break;
            case 401:
                NSLog(@"Unauthorized");
                break;
            case 408:
                NSLog(@"Request Timeout");
                break;
            case 500:
                NSLog(@"Internal Server Error");
                break;
            case 503:
                NSLog(@"Service Unavailable");
                break;
            default:
                NSLog(@"Returned Status Code: %li", statusCode);
                break;
        }
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
   
    NSDictionary* response = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    BOOL accepted = [[response valueForKey:@"Accepted"] boolValue];
    if (accepted) {
        NSLog(@"Http status accepted");
    }
    else {
        NSLog(@"Response: %@", response);
        // NSString *error = [response valueForKey:@"Errors"];
    }
    
    NSError *error;
    NSData *jsonData =  [NSJSONSerialization dataWithJSONObject:response options:NSJSONWritingPrettyPrinted error:&error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    ResultViewController *resultViewController = [[ResultViewController alloc] init];
    resultViewController.jsonString = jsonString;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:resultViewController];
    [self presentViewController:navController animated:YES completion:nil];
    
    // Disable the "Process" button
    [_process setEnabled:true];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        NSLog(@"Connection error: %@", error.localizedDescription);
    }
}

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error {
    if (error) { }
    [session finishTasksAndInvalidate];
}


@end

