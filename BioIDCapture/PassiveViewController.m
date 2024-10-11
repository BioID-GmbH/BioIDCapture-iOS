//
//  PassiveViewController.m
//  BioIDCapture
//
//  Copyright © 2024 BioID. All rights reserved.
//

#import "PassiveViewController.h"

@interface PassiveViewController ()

@end

@implementation PassiveViewController 

// Called after the controller`s view is loaded into memory.
- (void)viewDidLoad {
    [super viewDidLoad];
  
    // Clear imageViewer
    [_imageViewer setImage:nil];
    
    // Disable the "Process" button
    [_process setEnabled:false];
}

// The "Capture photo" button was tapped.
- (IBAction)capturePhoto:(id)sender {
    
    // Clear imageViewer
    [_imageViewer setImage:nil];
    
    // Create and show image picker controller
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    picker.cameraCaptureMode = UIImagePickerControllerCameraCaptureModePhoto;
    picker.cameraDevice = UIImagePickerControllerCameraDeviceFront;
    picker.showsCameraControls = YES;
    [self presentViewController:picker animated:YES completion:nil];
}

// The "Process" button was tapped.
- (IBAction)process:(id)sender {
    
    if (_imageViewer.image != nil) {
        
        // Disable the "Process" button
        [_process setEnabled:false];
        
        // Perform Passive LivenessDetection operation
        [self performPassiveLivenessDetection:_imageViewer.image];
    }
}

// Callback of ImagePickerController after the photo has been accepted by the user.
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(nonnull NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    
    // Get image from ImagePickerController
    UIImage *sourceImage = info[UIImagePickerControllerOriginalImage];
     
    // Hide introduction view
    [_introduction setHidden:true];
    
    // Mirror the image from ImagePickerController and set to ImageViewer
    [_imageViewer setImage:[BioIDHelper mirrorImage:sourceImage]];
    
    // Enable the "Process" button
    [_process setEnabled:true];
    
    // Close ImagePickerController
    [picker dismissViewControllerAnimated:YES completion:nil];
}

// Performs a passive liveness detection with one live image.
- (void)performPassiveLivenessDetection:(UIImage *)liveImage1 {
    
    // Test server: REST-GRPC Forwarder endpoint
    NSURL* baseUrl = [NSURL URLWithString:BWS3_REST_GRPC_ENDPOINT];
    NSURL *url = [NSURL URLWithString:BWS3_TASK_LIVENESSDETECTION relativeToURL:baseUrl];
    NSLog(@"%@", url.absoluteURL);

    // Resize image before sending!!!
    UIImage* resizedImage = [BioIDHelper resizeImageForUpload:liveImage1];
    
    // Create JSON Request Body with the help of the BioIDHelper
    NSData *jsonData = [BioIDHelper createJSONRequestBody:resizedImage];
    
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
    
    // Enable the "Process" button
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
