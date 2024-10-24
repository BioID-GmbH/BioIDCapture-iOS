//
//  BioIDCaptureViewController.m
//  BioIDCapture
//
//  Copyright © 2024 BioID. All rights reserved.
//

#import "BioIDCaptureViewController.h"

@interface BioIDCaptureViewController ()
// class extension
- (BOOL)setupAVCapture;
- (void)teardownAVCapture;
@property AVCaptureSession *captureSession;

@end

@implementation BioIDCaptureViewController

@synthesize previewView;
@synthesize captureSession;

// Feel free to change this string
NSString *const BIOID_INSTRUCTION_ACTIVE = @"Please nod your head";
NSString *const BIOID_INSTRUCTION_CHALLENGE = @"Follow the blue head";


// Faces to be found continuously until the initial recording is triggered
static int const TRIGGER_TO_START = 2;
// Wait a moment for camera adjustment
static double const WAIT_FOR_CAMERA_ADJUSTMENT = 0.5;
// Seconds after which the view will be dismissed if no activity (face finding/motion detection) was detected
static NSTimeInterval const INACTIVITY_TIMEOUT = 10;
// The threshold value given in percentage of complete motion (i.e. between 0 and 100)
static int const MIN_MOVEMENT_PERCENTAGE = 15;
// Used font in this controller
NSString *const BIOID_FONT = @"HelveticaNeue";

// Helper to calculate degree to radian
static CGFloat DegreesToRadians(CGFloat degrees)  { return degrees * M_PI / 180; }


#pragma mark - Lifecycle of ViewController

// Called after the controller`s view is loaded into memory.
- (void)viewDidLoad {
    [super viewDidLoad];
    
    capturing = false;
    captureTriggered = false;
    faceFinderRunning = false;
   
    // Receive notification if orientation is changed
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
    
    // Check permission of camera
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus == AVAuthorizationStatusAuthorized) {
        cameraAccess = [self setupAVCapture];
        [self createLayers];
        
        if (cameraAccess) {
            [self initFaceFinder];
        }
    }
    else {  // AVAuthorizationStatusDenied || AVAuthorizationStatusNotDetermined || AVAuthorizationStatusRestricted
        cameraAccess = NO;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    if (cameraAccess == NO) {
        [self abortViewController:BIOID_NO_CAMERA_ACCESS];
        return;
    }
    [self setLayers:[[UIDevice currentDevice] orientation]];
    
    /* starting capture session */
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.captureSession startRunning];
    });
   
    [self start];
    [super viewDidAppear:TRUE];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self.captureSession stopRunning];
    [self teardownAVCapture];
    [self cleanup];
    [super viewWillDisappear:TRUE];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dismissViewController {
    [self dismissViewControllerAnimated:NO completion:nil];
}

- (void)abortViewController:(int)errorCode {
    [self stop];
    if (self.callback) {
        [self.callback capturingFailed:errorCode];
    }
    [self dismissViewController];
}

- (void)cleanup {
    NSLog(@"-------------- Clean up ------------------");

    // Capture device & video output
    captureSession = nil;
    captureDevice = nil;
    previewLayer = nil;
    videoDataOutput = nil;
    videoDataOutputQueue = nil;
    
    // FaceDetector
    faceDetector = nil;
    detectorOptions = nil;
    
    // Motion detection
    templateBuffer = nil;
    
    // Timers
    [killTimer invalidate];
    killTimer = nil;
    [triggerTimer invalidate];
    triggerTimer = nil;
    
    // SceneView for 3D head
    if (sceneView != nil) {
        [sceneView.scene setPaused:YES];
        sceneView.scene = nil;
        sceneView = nil;
    }
    // 3D head node
    headNode = nil;
    
    // Remove all subViews
    NSArray *subViews = [self.view subviews];
    for (UIView* view in subViews) {
        [view removeFromSuperview];
    }
    
    debugLabel = nil;
    instructionLabel = nil;
}


#pragma mark - Visual layers

- (void)createLayers {
    UIBlurEffect *effectDark = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    
    sceneView = [[SCNView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
    [sceneView setHidden:YES];
    [sceneView setAlpha:0.85];
    [self.view addSubview:sceneView];

    instructionViewBlurred = [[UIVisualEffectView alloc] initWithEffect:effectDark];
    [instructionViewBlurred setBounds:CGRectMake(0, 0, 300, 70)];
    [instructionViewBlurred setHidden:YES];
    
    instructionLabel = [[UILabel alloc] init];
    [instructionLabel setTextAlignment:NSTextAlignmentCenter];
    [instructionLabel setFrame:CGRectMake(0, 0, instructionViewBlurred.frame.size.width, instructionViewBlurred.frame.size.height)];
    
    [instructionViewBlurred.contentView addSubview:instructionLabel];
    [self.view addSubview:instructionViewBlurred];
    
#ifdef DEBUG
    debugLabel = [[UILabel alloc] init];
    [debugLabel setTextAlignment:NSTextAlignmentCenter];
    [debugLabel setBounds:CGRectMake(0, 0, 375, 20)];
    [debugLabel setBackgroundColor:[UIColor blackColor]];
    [self.view addSubview:debugLabel];
#endif
}

- (void)updateLayers {
    [instructionViewBlurred setCenter:CGPointMake(self.view.bounds.size.width/2, 70)];
    [sceneView setFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
}

- (void)setLayers:(UIDeviceOrientation)deviceOrientation {
    switch (deviceOrientation) {
        case UIDeviceOrientationPortrait: {
            [instructionViewBlurred setCenter:CGPointMake(self.view.bounds.size.width/2, 70)];
            [instructionViewBlurred setTransform:CGAffineTransformMakeRotation(DegreesToRadians(0.))];
            [sceneView setTransform:CGAffineTransformMakeRotation(DegreesToRadians(0.))];
            [sceneView setFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
            [debugLabel setCenter:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height-30)];
            [debugLabel setTransform:CGAffineTransformMakeRotation(DegreesToRadians(0.))];
            break;
        }
        case UIDeviceOrientationPortraitUpsideDown: {
            [instructionViewBlurred setCenter:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height-70)];
            [instructionViewBlurred setTransform:CGAffineTransformMakeRotation(DegreesToRadians(180.))];
            // Rotate 180 degree
            [sceneView setTransform:CGAffineTransformMakeRotation(DegreesToRadians(180.))];
            [sceneView setFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
            [debugLabel setCenter:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height-30)];
            [debugLabel setTransform:CGAffineTransformMakeRotation(DegreesToRadians(180.))];
            break;
        }
        case UIDeviceOrientationLandscapeLeft: {
            [instructionViewBlurred setCenter:CGPointMake(self.view.bounds.size.width-40, self.view.bounds.size.height/2)];
            [instructionViewBlurred setTransform:CGAffineTransformMakeRotation(DegreesToRadians(90.))];
            [sceneView setTransform:CGAffineTransformMakeRotation(DegreesToRadians(90.))];
            [sceneView setFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
            [debugLabel setCenter:CGPointMake(self.view.bounds.size.width-10, self.view.bounds.size.height/2)];
            [debugLabel setTransform:CGAffineTransformMakeRotation(DegreesToRadians(90.))];
            break;
        }
        case UIDeviceOrientationLandscapeRight: {
            [instructionViewBlurred setCenter:CGPointMake(40, self.view.bounds.size.height/2)];
            [instructionViewBlurred setTransform:CGAffineTransformMakeRotation(DegreesToRadians(-90.))];
            // Rotate 180 degree
            [sceneView setTransform:CGAffineTransformMakeRotation(DegreesToRadians(-90.))];
            [sceneView setFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
            [debugLabel setCenter:CGPointMake(10, self.view.bounds.size.height/2)];
            [debugLabel setTransform:CGAffineTransformMakeRotation(DegreesToRadians(-90.))];
            break;
        }
        default: {
            // Show UIDeviceOrientationPortrait!
            [instructionViewBlurred setCenter:CGPointMake(self.view.bounds.size.width/2, 70)];
            [instructionViewBlurred setTransform:CGAffineTransformMakeRotation(DegreesToRadians(0.))];
            [debugLabel setCenter:CGPointMake(self.view.bounds.size.width/2, 10)];
            [debugLabel setTransform:CGAffineTransformMakeRotation(DegreesToRadians(0.))];
            [sceneView setTransform:CGAffineTransformMakeRotation(DegreesToRadians(0.))];
            [sceneView setFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
            break;
        }
    }
    [self.view setNeedsLayout];
}

- (void)showInstructionLayer:(NSString *)instruction {
    NSMutableAttributedString *instructionString =[[NSMutableAttributedString alloc] initWithString:@""];
    
    if (instruction) {
        instructionString = [[NSMutableAttributedString alloc] initWithString:instruction];
        [instructionString addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:(NSRange){0, instructionString.length}];
        [instructionString addAttribute:NSFontAttributeName value:[UIFont fontWithName:BIOID_FONT size:20] range:[instructionString.string rangeOfString:instructionString.string]];
    }
    
    [instructionLabel setAttributedText:instructionString];
    [instructionLabel setNeedsDisplay];
    [instructionViewBlurred setHidden:NO];
}

- (void)hideInstructionLayer {
     dispatch_async(dispatch_get_main_queue(), ^(void) {
         [self->instructionViewBlurred setHidden:YES];
     });
}

- (void)show3DHeadLayer {
    [sceneView setHidden:NO];
}

- (void)hide3DHeadLayer {
    [sceneView setHidden:YES];
}


#pragma mark - Device Orientation

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (void)viewWillLayoutSubviews {
    previewLayer.frame = self.view.bounds;
    previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    
#if TARGET_OS_MACCATALYST
    // Code to include for Macos version
    // macOS window resize
    [self updateLayers];
#endif
}

-(void)orientationChanged:(NSNotification *)notification {
    [self setLayers:[[UIDevice currentDevice] orientation]];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}


#pragma mark - AVCapture configuration

- (BOOL)setupAVCapture {
    NSLog(@"Initialize camera!");
    NSError *error = nil;
    
    // Get front camera
    captureDevice = [self frontCamera];
    
    // setting up white balance
    if ([captureDevice isWhiteBalanceModeSupported: AVCaptureWhiteBalanceModeAutoWhiteBalance]) {
        if ([captureDevice lockForConfiguration:nil]) {
            [captureDevice setWhiteBalanceMode:AVCaptureWhiteBalanceModeAutoWhiteBalance];
            [captureDevice unlockForConfiguration];
        }
    }
    
    // Add the device to the session.
    AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:&error];
    if(error) {
        return NO;
    }
    
    captureSession = [[AVCaptureSession alloc] init];
    [captureSession beginConfiguration];
    
    // AVCaptureSessionPresetHigh - Specifies capture settings suitable for high-quality video!
    if([captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
       captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    }
    else {   // otherwise use AVCaptureSessionPreset640x480
        captureSession.sessionPreset = AVCaptureSessionPreset640x480;
    }
    
    [captureSession addInput:input];
    
    // Create the output for the capture session.
    videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    NSDictionary *rgbOutputSettings = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt:kCMPixelFormat_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    [videoDataOutput setVideoSettings:rgbOutputSettings];
    [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    
    videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    [videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
    
    if ([captureSession canAddOutput:videoDataOutput]) {
        [captureSession addOutput:videoDataOutput];
    }
    
    previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:captureSession];
    [previewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    CALayer *rootLayer = [previewView layer];
    [rootLayer setMasksToBounds:YES];
    [previewLayer setFrame:[rootLayer bounds]];
    [rootLayer addSublayer:previewLayer];
    [captureSession commitConfiguration];
    
    return YES;
}

- (void)teardownAVCapture {
    [previewLayer removeFromSuperlayer];
}

- (AVCaptureDevice *)frontCamera {
    NSLog(@"Get front camera!");
    
    AVCaptureDeviceDiscoverySession *captureDeviceDiscoverySession =
        [AVCaptureDeviceDiscoverySession
       discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
                              mediaType:AVMediaTypeVideo
                              position:AVCaptureDevicePositionFront];
    
    for (AVCaptureDevice *device in [captureDeviceDiscoverySession devices]) {
        if ([device position] == AVCaptureDevicePositionFront) {
            return device;
        }
    }

    return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
}


#pragma mark - Capturing & Workflow

- (void)start {
    NSLog(@"------------ Starting Capture ------------");
    
    capturing = false;
    captureTriggered = false;
    faceFinderRunning = false;
    continuousFoundFaces = 0;
    templateBuffer = nil;
    
    [self startDismissTimer];
    // Auto trigger after some time
    [self startWaitForCameraTimer];
}


- (void)stop {
    NSLog(@"------------ Stopping Capture ------------");
    
    // Kill timers
    [self killDismissTimer];
    
    // Hide layers
    [self hideInstructionLayer];
    [self hide3DHeadLayer];
    
    capturing = false;
    captureTriggered = false;
    faceFinderRunning = false;
    continuousFoundFaces = 0;
    
    NSLog(@"------------ Stopped Capture -------------");
}


// Grab the live camera
// Notifes the delegate that a new video frame was written
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
    
    int exifOrientation;
    UIImageOrientation imageOrientation = UIImageOrientationRight;
    
    switch (curDeviceOrientation) {
        case UIDeviceOrientationPortraitUpsideDown: {
            // Device oriented vertically, home button on the top
            imageOrientation = UIImageOrientationLeft;
            exifOrientation = kCGImagePropertyOrientationLeft;
            break;
        }
        case UIDeviceOrientationLandscapeLeft: {
            // Device oriented horizontally, home button on the right
            imageOrientation = UIImageOrientationDown;
            exifOrientation = kCGImagePropertyOrientationDown;
            break;
        }
        case UIDeviceOrientationLandscapeRight: {
            // Device oriented horizontally, home button on the left
            imageOrientation = UIImageOrientationUp;
            exifOrientation = kCGImagePropertyOrientationUp;
            break;
        }
        case UIDeviceOrientationUnknown: {
            imageOrientation = UIImageOrientationUp;
            exifOrientation = kCGImagePropertyOrientationUp;
            break;
        }
        case UIDeviceOrientationPortrait:
        case UIDeviceOrientationFaceUp:
            // ** Fall-through **
        default:
            // Device oriented vertically, home button on the bottom
            exifOrientation = kCGImagePropertyOrientationRight;
            break;
    }
    
    if (faceFinderRunning) {
        // Detect the face(s)
        NSDictionary *imageOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:exifOrientation] forKey:CIDetectorImageOrientation];
        NSArray *features = [faceDetector featuresInImage:ciImage options:imageOptions];
        
        // Features.count > 0 - one or more faces have been found
        if (features != NULL && features.count > 0) {
            if(++continuousFoundFaces == TRIGGER_TO_START) {
                captureTriggered = true;
                faceFinderRunning = false;
            }
        }
        else {
            // No face found - reset the counter!
            continuousFoundFaces = 0;
        }
    }
    
    // Trigger capture
    if (!capturing && captureTriggered) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            
            // Do 3D head action
            [self show3DHeadLayer];
            if ([self.challengeTag length] > 0) {
                [self showInstructionLayer:BIOID_INSTRUCTION_CHALLENGE];
                [self createActionForChallenge:self.challengeTag];
            }
            else  {
                [self showInstructionLayer:BIOID_INSTRUCTION_ACTIVE];
                [self createActionForLiveDetection];
            }
                
        });
        capturing = true;
    }
    
    if (capturing) {
        // Create UIImage and rotate the image
        UIImage *image = [self imageFromSampleBuffer:sampleBuffer orientation:imageOrientation];
        UIImage *currentImage = [self scaleAndRotateImage:image];
        
        if (templateBuffer) {
            BOOL motion = [self motionDetection:currentImage];
            if (motion) {
                image2 = image;

                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    [self stop];
                    [self dismissViewController];
                }];
              
                if (self.callback) {
                    UIImage *mirroredImage1 = [BioIDHelper mirrorImage:image1];
                    UIImage *mirroredImage2 = [BioIDHelper mirrorImage:image2];
                    [self.callback capturingFinished:mirroredImage1 secondImage:mirroredImage2];
                }
            }
        }
        else {
            // create template for motion detection
            [self createTemplate:currentImage];
            // store first image
            image1 = image;
        }
    }
}


#pragma mark - FaceFinder

- (void)initFaceFinder {
    NSLog(@"Init FaceFinder!");
    // Create the face detector
    detectorOptions = @{ CIDetectorAccuracy: CIDetectorAccuracyLow };
    faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:NULL options:detectorOptions];
}


#pragma mark - Image processing

// Create a UIImage from sample buffer data
- (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer orientation:(UIImageOrientation)imageOrientation {
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage scale:1.0 orientation:imageOrientation];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    return (image);
}

- (UIImage *)scaleAndRotateImage:(UIImage *)image {
    int kMaxResolution = 1600;
    
    CGImageRef imgRef = image.CGImage;
    
    CGFloat width = CGImageGetWidth(imgRef);
    CGFloat height = CGImageGetHeight(imgRef);
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    CGRect bounds = CGRectMake(0, 0, width, height);
    if (width > kMaxResolution || height > kMaxResolution) {
        CGFloat ratio = width/height;
        if (ratio > 1) {
            bounds.size.width = kMaxResolution;
            bounds.size.height = bounds.size.width / ratio;
        }
        else {
            bounds.size.height = kMaxResolution;
            bounds.size.width = bounds.size.height * ratio;
        }
    }
    
    CGFloat scaleRatio = bounds.size.width / width;
    CGSize imageSize = CGSizeMake(CGImageGetWidth(imgRef), CGImageGetHeight(imgRef));
    CGFloat boundHeight;
    UIImageOrientation orient = image.imageOrientation;
    
    switch(orient) {
        case UIImageOrientationUp: {
            transform = CGAffineTransformMakeTranslation(imageSize.width, 0.0);
            transform = CGAffineTransformScale(transform, -1.0, 1.0);
            break;
        }
        case UIImageOrientationDown: {
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.height);
            transform = CGAffineTransformScale(transform, 1.0, -1.0);
            break;
        }
        case UIImageOrientationLeft: {
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeTranslation(imageSize.height, imageSize.width);
            transform = CGAffineTransformScale(transform, -1.0, 1.0);
            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
            break;
        }
        case UIImageOrientationRight: {
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeScale(-1.0, 1.0);
            transform = CGAffineTransformRotate(transform, M_PI / 2.0);
            break;
        }
        default:
            [NSException raise:NSInternalInconsistencyException format:@"Invalid image orientation"];
    }
    
    UIGraphicsBeginImageContext(bounds.size);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    if (orient == UIImageOrientationRight || orient == UIImageOrientationLeft) {
        CGContextScaleCTM(context, -scaleRatio, scaleRatio);
        CGContextTranslateCTM(context, -height, 0);
    }
    else {
        CGContextScaleCTM(context, scaleRatio, -scaleRatio);
        CGContextTranslateCTM(context, 0, -height);
    }
    
    CGContextConcatCTM(context, transform);
    
    CGContextDrawImage(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, width, height), imgRef);
    UIImage *imageCopy = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return imageCopy;
}

- (UIImage *)convertImageToGrayScale:(UIImage *)image {
    // Create image rectangle with current image width / height
    CGRect rect = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);
    // Grayscale color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    // Create bitmap content with current image size and grayscale colorspace
    CGContextRef context = CGBitmapContextCreate(NULL, image.size.width, image.size.height, 8, 0, colorSpace, (CGBitmapInfo)kCGImageAlphaNone);
    
    // Draw image to current context
    CGContextDrawImage(context, rect, [image CGImage]);
    // Create bitmap image info from pixel data n current context
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    // Create a new UImage with grayscale image
    UIImage *grayImage = [UIImage imageWithCGImage:imageRef];
    
    // Release colorspace, context and bitmap info
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    CGImageRelease(imageRef);
    
    // Return the new grayscale image
    return grayImage;
}

- (UIImage *)resizeImageForMotionDetection:(UIImage *)image {
    int resizeWidth;
    int resizeHeight;
    
    if (image.size.width > image.size.height) {
        // Landscape mode
        resizeHeight = 120;
        // Calculate new width according to aspect ratio of original image
        resizeWidth = image.size.width * resizeHeight / image.size.height;
    }
    else {
        // Portrait mode
        resizeWidth = 120;
        // Calculate new height according to aspect ratio of original image
        resizeHeight = image.size.height * resizeWidth / image.size.width;
    }
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(resizeWidth, resizeHeight), YES, 0.0);
    [image drawInRect:CGRectMake(0, 0, resizeWidth, resizeHeight)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resizedImage;
}

// Cut out the template that is used by the motion detection.
-(void)createTemplate:(UIImage *)first {
    UIImage *resizedImage = [self resizeImageForMotionDetection:first];
    UIImage *resizedGrayImage = [self convertImageToGrayScale:resizedImage];
    
    resizeCenterX = resizedGrayImage.size.width / 2;
    resizeCenterY = resizedGrayImage.size.height / 2;
    
    if (resizedGrayImage.size.width > resizedGrayImage.size.height) {
        // Landscape mode
        templateWidth = resizedGrayImage.size.width / 10;
        templateHeight = resizedGrayImage.size.height / 3;
    }
    else {
        // Portrait mode
        templateWidth = resizedGrayImage.size.width / 10 * 4 / 3;
        templateHeight = resizedGrayImage.size.height / 4;
    }
    
    templateXpos = resizeCenterX - templateWidth / 2;
    templateYpos = resizeCenterY - templateHeight / 2;
    
    templateBuffer = nil;
    templateBuffer = malloc(templateWidth * templateHeight);
    
    CFDataRef rawData = CGDataProviderCopyData(CGImageGetDataProvider(resizedGrayImage.CGImage));
    int bytesPerRow = (int)CGImageGetBytesPerRow(resizedGrayImage.CGImage);
    const UInt8* buffer = CFDataGetBytePtr(rawData);
    
    int counter = 0;
    for (int y = templateYpos; y < templateYpos + templateHeight; y++) {
        for (int x = templateXpos; x < templateXpos + templateWidth; x++) {
            int templatePixel = buffer[x + y * bytesPerRow];
            templateBuffer[counter++] = templatePixel;
        }
    }
    
    // Release
    CFRelease(rawData);
}

// This is the major computing step: Perform a normalized cross-correlation between the template of the first image and each incoming image.
// This algorithm is basically called: "Template Matching" - we use the normalized cross correlation to be independent of lighting images.
// We calculate the correlation of template and image over whole image area.
-(BOOL)motionDetection:(UIImage *)current {
#ifdef DEBUG
    NSDate *start = [NSDate date];
#endif
    
    UIImage *resizedImage = [self resizeImageForMotionDetection:current];
    UIImage *resizedGrayImage = [self convertImageToGrayScale:resizedImage];
    
    int bestHitX = 0;
    int bestHitY = 0;
    double maxCorr = 0.0;
    bool triggered = false;
    
    int searchWidth = resizedGrayImage.size.width / 4;
    int searchHeight = resizedGrayImage.size.height / 4;
    
    CFDataRef rawData = CGDataProviderCopyData(CGImageGetDataProvider(resizedGrayImage.CGImage));
    int bytesPerRow = (int)CGImageGetBytesPerRow(resizedGrayImage.CGImage);
    const UInt8* buffer = CFDataGetBytePtr(rawData);
    
    for (int y = resizeCenterY - searchHeight; y <= resizeCenterY + searchHeight - templateHeight; y++) {
        for (int x = resizeCenterX - searchWidth; x <= resizeCenterX + searchWidth - templateWidth; x++) {
            int nominator = 0;
            int denominator = 0;
            int templateIndex = 0;
            
            // Calculate the normalized cross-correlation coefficient for this position
            for (int ty = 0; ty < templateHeight; ty++) {
                int bufferIndex = x + (y + ty) * bytesPerRow;
                for (int tx = 0; tx < templateWidth; tx++) {
                    int imagePixel = buffer[bufferIndex++];
                    nominator += templateBuffer[templateIndex++] * imagePixel;
                    denominator += imagePixel * imagePixel;
                }
            }
            
            // The NCC coefficient is then (watch out for division-by-zero errors for bure black images)
            double ncc = 0.0;
            if (denominator > 0) {
                ncc = (double)nominator * (double)nominator / (double)denominator;
            }
            // Is it higher that what we had before?
            if (ncc > maxCorr) {
                maxCorr = ncc;
                bestHitX = x;
                bestHitY = y;
            }
        }
    }
    
    // Now the most similar position of the template is (bestHitX, bestHitY). Calculate the difference from the origin
    int distX = bestHitX - templateXpos;
    int distY = bestHitY - templateYpos;
    
    double movementDiff = sqrt(distX * distX + distY * distY);
    
    // The maximum movement possible is a complete shift into one of the corners, i.e.
    int maxDistX = searchWidth - templateWidth / 2;
    int maxDistY = searchHeight - templateHeight / 2;
    double maximumMovement = sqrt((double)maxDistX * maxDistX + (double)maxDistY * maxDistY);
    
    // The percentage of the detected movement is therefore
    double movementPercentage = movementDiff / maximumMovement * 100.0;
    
    if (movementPercentage > 100.0) {
        movementPercentage = 100.0;
    }
    
#ifdef DEBUG
    NSDate *stop = [NSDate date];
    NSTimeInterval execution = [stop timeIntervalSinceDate:start];
    NSString *info = [NSString stringWithFormat:@"Time: %.3fs - Movement: %.1f", execution, movementPercentage];
    NSMutableAttributedString *infoString =[[NSMutableAttributedString alloc] initWithString:@""];
    
    if (info != NULL) {
        infoString = [[NSMutableAttributedString alloc] initWithString:info];
        [infoString addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:(NSRange){0, infoString.length}];
        [infoString addAttribute:NSFontAttributeName value:[UIFont fontWithName:BIOID_FONT size:15] range:[infoString.string rangeOfString:infoString.string]];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self->debugLabel.attributedText = infoString;
        [self->debugLabel setNeedsDisplay];
    });
#endif
    
    // Trigger if movementPercentage is above threshold (default: when 15% of the maximum movement is exceeded)
    if (movementPercentage > MIN_MOVEMENT_PERCENTAGE)  {
        triggered = true;
    }
    
    // Release
    CFRelease(rawData);
    
    return triggered;
}


#pragma mark - Timers

- (void)startWaitForCameraTimer {
    cameraTimer = [NSTimer scheduledTimerWithTimeInterval:WAIT_FOR_CAMERA_ADJUSTMENT target:self selector:@selector(killWaitForCameraTimer) userInfo:nil repeats:NO];
}

- (void)killWaitForCameraTimer {
    if (cameraTimer && [cameraTimer isValid]) {
        NSLog(@"Kill camera Timer");
        [cameraTimer invalidate];
        faceFinderRunning = true;
    }
    cameraTimer = nil;
}

- (void)startDismissTimer {
    [self killDismissTimer];
    NSLog(@"Starting dismiss timer");
    killTimer = [NSTimer scheduledTimerWithTimeInterval:INACTIVITY_TIMEOUT target:self selector:@selector(dismissTimerMethod:) userInfo:nil repeats:NO];
}

- (void)killDismissTimer {
    if (killTimer && [killTimer isValid]) {
        NSLog(@"Stopping dismiss timer");
        [killTimer invalidate];
    }
    killTimer = nil;
}

- (void)dismissTimerMethod:(NSTimer *)timer {
    NSLog(@"Dismiss timer fired!");
    if (faceFinderRunning) {
        [self abortViewController:BIOID_NO_FACE_FOUND];
    }
    else {
        [self abortViewController:BIOID_NO_MOTION_DETECTED];
    }
}


#pragma mark - SceneKit

- (void)createSceneView {
    // Create a new scene
    SCNScene *headScene = [SCNScene sceneNamed:@"art.scnassets/3DHead.dae"];
    
    // Create and add a camera to the scene
    SCNNode *cameraNode = [SCNNode node];
    cameraNode.camera = [SCNCamera camera];
    
    // Place the camera
    cameraNode.position = SCNVector3Make(0.0, 0.15, 2.0);
    [headScene.rootNode addChildNode:cameraNode];
    
    // create and add a light to the scene
    SCNNode *lightNode = [SCNNode node];
    lightNode.light = [SCNLight light];
    lightNode.light.type = SCNLightTypeOmni;
    lightNode.position = SCNVector3Make(0, 10, 10);
    [headScene.rootNode addChildNode:lightNode];
    
    // create and add an ambient light to the scene
    SCNNode *ambientLightNode = [SCNNode node];
    ambientLightNode.light = [SCNLight light];
    ambientLightNode.light.type = SCNLightTypeAmbient;
    ambientLightNode.light.color = [UIColor darkGrayColor];
    [headScene.rootNode addChildNode:ambientLightNode];
    
    // Retrieve the head node
    headNode = nil;
    headNode = [headScene.rootNode childNodeWithName:@"BioID-Head" recursively:YES];
    headNode.position = SCNVector3Make(0, 0, 0);
    
    // Set the scene to the view
    sceneView.scene = nil;
    sceneView.scene = headScene;
    
    // Configure the background color
    sceneView.backgroundColor = [UIColor darkGrayColor]; // or use clearColor
}

- (void)createActionForLiveDetection {
    [self createSceneView];
    
    [headNode removeAllActions];
   
    SCNAction *action = nil;
    SCNAction *moveUp = [SCNAction rotateByX:-0.2 y:0 z:0 duration:1.0];
    SCNAction *moveDown =  [SCNAction rotateByX:0.2 y:0 z:0 duration:1.0];
    SCNAction *moveSequence = [SCNAction sequence:@[moveUp,moveDown]];
    action = [SCNAction repeatActionForever:moveSequence];
   
    [headNode runAction:action];
}

- (void)createActionForChallenge:(NSString *)direction {
    [self createSceneView];
    
    SCNAction *action = nil;
   
    // Create direction for 3D Head
    if([direction isEqualToString:@"up"]) {
        action = [SCNAction rotateByX:-0.2 y:0 z:0 duration:1.0];
    }
    else if([direction isEqualToString:@"down"]) {
        action = [SCNAction rotateByX:0.2 y:0 z:0 duration:1.0];
    }
    else if([direction isEqualToString:@"left"]) {
        action = [SCNAction rotateByX:0 y:-0.2 z:0 duration:1.0];
    }
    else if([direction isEqualToString:@"right"]) {
        action = [SCNAction rotateByX:0 y:0.2 z:0 duration:1.0];
    }
    NSLog(@"%@", direction);
    [headNode runAction:action];
}

@end
