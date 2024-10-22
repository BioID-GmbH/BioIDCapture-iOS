# BioIDCapture-iOS

## BioIDCaptureViewController

### How to invoke the controller
If the BioIDCaptureController is to be called, the function 'prepareForSegue' is a good way to set all the necessary values. 
Here is an example

 ```cmd

  (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
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

  ```

In the example above, a ChallengeTag is randomly set from a predefined array at head movements.
This is only necessary if you want to use challenge-response!

It is important that the callback is set to `self` and that the calling controller e.g. ActiveViewController has implemented 
the functions `capturingFinished` and `capturingFailed`.

#### capturingFinished
If the capturing is successfully completed, this callback returns two images.

#### capturingFailed
If an error occurs during capturing, this callback returns an `error code`.

This can be:
- BIOID_NO_CAMERA_ACCESS
- BIOID_NO_FACE_FOUND
- BIOID_NO_MOTION_DETECTED

A time interval INACTIVITY_TIMEOUT is defined for the errors BIOID_NO_FACE_FOUND and BioID_NO_MOTION_DETECTED, 
after which the controller is terminated if no activity (face detection/movement detection) has been detected. 
The default value is 10 seconds.


When the controller is started 

1. The status of the camera access is determined. If the user has not yet consented, a request is made. 
If access is permitted, the recording is started. Otherwise the process is aborted.

2. When the recording starts, Apple FaceFinder is used to check whether a face is included in the image. 
If so, this first image is saved for liveness detection. If the user makes a movement, 
for example “Nod your head”, a second image is captured by Motion Detection.


### 3D Head
A 3D head is displayed during the recording. Two modes are defined for this. For Active Liveness Detection, 
the user is promptly shown “Nod your head” and the 3D head moves accordingly. 
For Challenge-Response, the user prompt “Follow the blue head” is displayed 
and the 3D head moves in the specified direction that was previously defined 
with the challenge tag.

