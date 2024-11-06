//
//  PhotoVerifyViewController.m
//  BioIDCapture
//
//  Copyright © 2024 BioID. All rights reserved.


#import "PhotoVerifyViewController.h"

@interface PhotoVerifyViewController ()

@end

@implementation PhotoVerifyViewController

// Called after the controller`s view is loaded into memory.
- (void)viewDidLoad {
    [super viewDidLoad];
   
    // Disable the "Capture ID photo" button
    [_captureIDPhoto setEnabled:false];
    
    // Disable the "Process" button
    [_process setEnabled:false];
}

// The "Capture 1 photo" button was tapped.
-(IBAction)captureSinglePhoto:(id)sender {
  
  // Clear imageViewers
  [_imageViewer1 setImage:nil];
  [_imageViewer2 setImage:nil];
  
  UIImagePickerController *pickerSinglePhoto = [[UIImagePickerController alloc] init];
  pickerSinglePhoto.delegate = self;
  pickerSinglePhoto.sourceType = UIImagePickerControllerSourceTypeCamera;
  pickerSinglePhoto.cameraDevice = UIImagePickerControllerCameraDeviceFront;
  pickerSinglePhoto.showsCameraControls = YES;
  
  // Set a tag to distinguish the caller in the callback
  pickerSinglePhoto.view.tag = 1;
  
  [self presentViewController:pickerSinglePhoto animated:YES completion:nil];
}

// The "Capture 2 photos" button was tapped.
- (IBAction)captureLivePhotos:(id)sender {
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

// The "Capture ID photo" button was tapped.
- (IBAction)captureIDPhoto:(id)sender {
   
    // Clear imageViewer
   [_imageViewer3 setImage:nil];
   
   // Create and show image picker controller
   UIImagePickerController *pickerIDPhoto = [[UIImagePickerController alloc] init];
   pickerIDPhoto.delegate = self;
   pickerIDPhoto.sourceType = UIImagePickerControllerSourceTypeCamera;
   pickerIDPhoto.cameraDevice = UIImagePickerControllerCameraDeviceFront;
   pickerIDPhoto.showsCameraControls = YES;
   [self presentViewController:pickerIDPhoto animated:YES completion:nil];
}

// The "Process" button was tapped.
- (IBAction)process:(id)sender {
   if (_imageViewer1.image != nil && _imageViewer3.image != nil) {
       
       // Disable the "Process" button
       [_process setEnabled:false];
       
       // Get images from viewers
       UIImage* liveImage1 = _imageViewer1.image;
       UIImage* liveImage2 = _imageViewer2.image;
       UIImage* idPhoto = _imageViewer3.image;
       
       // Perfom PhotoVerify with liveness detection (passive or active liveness detection depends on whether one or two images are captured).
       [self performPhotoVerify:liveImage1 withSecondLiveImage:liveImage2 withSecondImageTags:@"" withIDPhoto:idPhoto withDisableLivenessDetection:false];
   }
}

// Callback of ImagePickerController after the photo has been accepted by the user.
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(nonnull NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
   
    // Hide introduction view
   [_introduction setHidden:true];
   
   UIImage *image = info[UIImagePickerControllerOriginalImage];
   
   // If we hava a view tag value of 1 we know the caller was "Capture 1 photo" button
   if (picker.view.tag == 1)  {
       
       // Set image from ImagePickerController to ImageViewer
       // Mirror the image from ImagePickerController and set to ImageViewer
       [_imageViewer1 setImage:[BioIDHelper mirrorImage:image]];
       
       // Disable "Capture 2 photos" button
       [_captureLivePhotos setEnabled:false];
       // Enable "Capture ID photo" button
       [_captureIDPhoto setEnabled:true];
       
   } // Otherwise the caller is "Caputure ID photo" button
   else {
       // Set image from ImagePickerController to ImageViewer
       // Mirror the image from ImagePickerController and set to ImageViewer
       [_imageViewer3 setImage:[BioIDHelper mirrorImage:image]];
       
       // Enable the "Process" button
       [_process setEnabled:true];
   }
   
   // Close ImagePickerController
   [picker dismissViewControllerAnimated:YES completion:nil];
   
   // If one live image and the ID photo is available
   if (_imageViewer1.image != nil && _imageViewer3.image != nil) {
       // Enable the "Process" button
       [_process setEnabled:true];
   }
}

// Notifies the PhotoViewController that a seque is about to be performed.
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    if ([[segue identifier] isEqualToString:@"showBioIDCaptureView"]) {
        BioIDCaptureViewController *viewController = [segue destinationViewController];
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
        
        // Disable "Capture 1 photo" button
        [self->_captureSinglePhoto setEnabled:false];
        /// Enable the "Capture ID photo" button
        [self->_captureIDPhoto setEnabled:true];
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

// Performs a PhotoVerify with one or two live images with tagged second image and a ID photo.
- (void)performPhotoVerify:(UIImage *)liveImage1 withSecondLiveImage:(UIImage *)liveImage2 withSecondImageTags:(NSString *)stringTags withIDPhoto:(UIImage *) idPhoto withDisableLivenessDetection:(Boolean)disableLivenessDetection {
   
    // Test server: REST-GRPC Forwarder endpoint
    NSURL* baseUrl = [NSURL URLWithString:BWS3_REST_GRPC_ENDPOINT];
    NSURL *url = [NSURL URLWithString:BWS3_TASK_PHOTOVERIFY relativeToURL:baseUrl];
    NSLog(@"%@", url.absoluteURL);

    NSData *jsonData = nil;
    
    if (liveImage2 != nil) {
        
        // Resize image before sending!!!
        UIImage* resizedLiveImage1 = [BioIDHelper resizeImageForUpload:liveImage1];
        UIImage* resizedLiveImage2 = [BioIDHelper resizeImageForUpload:liveImage2];
        UIImage* resizedIdPhoto = [BioIDHelper resizeImageForUpload:idPhoto];
        
        // Create JSON Request Body with the help of the BioIDHelper
        jsonData = [BioIDHelper createJSONRequestBody:resizedLiveImage1 withSecondLiveImage:resizedLiveImage2 withSecondImageTags:stringTags withIDPhoto:resizedIdPhoto withDisableLivenessDetection:false];
    }
    else  {
        // Resize image before sending!!!
        UIImage* resizedLiveImage1 = [BioIDHelper resizeImageForUpload:liveImage1];
        UIImage* resizedIdPhoto = [BioIDHelper resizeImageForUpload:idPhoto];
        
        // Create JSON Request Body with the help of the BioIDHelper
        jsonData = [BioIDHelper createJSONRequestBody:resizedLiveImage1 withIDPhoto:resizedIdPhoto withDisableLivenessDetection:false];
    }
    
    // Create Request object
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
    if (response == nil) {
        NSLog(@"No Response!");
        // Enable the "Process" button
        [_process setEnabled:true];
        return;
    }
    
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
     
    // Enable process button
    [_process setEnabled:true];
    
    // Enable buttons
    [_captureSinglePhoto setEnabled:true];
    [_captureLivePhotos setEnabled:true];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        NSLog(@"Connection error: %@", error.localizedDescription);
        // Enable the "Process" button
        [_process setEnabled:true];
    }
}

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error {
    if (error) { }
    [session finishTasksAndInvalidate];
}

@end
