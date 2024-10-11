//
//  BioIDCaptureViewController.h
//  BioIDCapture
//
//  Copyright © 2024 BioID. All rights reserved.
//

#ifndef BioIDCaptureViewController_h
#define BioIDCaptureViewController_h


#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <SceneKit/SceneKit.h>
#import <ImageIO/ImageIO.h>
#import <math.h>

#import "BioIDHelper.h"

@protocol BioIDCaptureViewControllerDelegate

- (void)capturingFinished:(UIImage *)image1 secondImage:(UIImage *)image2;
- (void)capturingFailed:(int)errorCode;

@end

// Error codes
static int const BIOID_NO_CAMERA_ACCESS = 1;
static int const BIOID_NO_FACE_FOUND = 2;
static int const BIOID_NO_MOTION_DETECTED = 3;

@interface BioIDCaptureViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate>
{
@private
    // Capture device & video output
    BOOL cameraAccess;
    AVCaptureDevice *captureDevice;
    AVCaptureVideoPreviewLayer *previewLayer;
    AVCaptureVideoDataOutput *videoDataOutput;
    dispatch_queue_t videoDataOutputQueue;
    
    // FaceDetector
    CIDetector *faceDetector;
    NSDictionary *detectorOptions;
    // Counter for continuous found faces
    int continuousFoundFaces;

    // Template for motion detection
    int templateWidth;
    int templateHeight;
    int templateXpos;
    int templateYpos;
    int resizeCenterX;
    int resizeCenterY;
    UInt8* templateBuffer;
    
    // Capturing
    BOOL faceFinderRunning;
    BOOL captureTriggered;
    BOOL capturing;
    
    // Images used for liveness detection
    UIImage *image1;
    UIImage *image2;
    
    // Visual effect views
    UIVisualEffectView *instructionViewBlurred;
    
    // Labels for displaying messages
    UILabel *instructionLabel;
    UILabel *debugLabel;
    
    // SceneView for 3D head
    SCNView *sceneView;
    // 3D head node
    SCNNode *headNode;
    
    // Timer
    NSTimer *cameraTimer;
    NSTimer *killTimer;
    NSTimer *triggerTimer;
}

@property (weak, nonatomic) IBOutlet UIView *previewView;
// callback provided by the caller
@property (nonatomic) id<BioIDCaptureViewControllerDelegate> callback;
// tag for challenge
@property (nonatomic) NSString *challengeTag;


@end

#endif /* BioIDCaptureViewController_h */
