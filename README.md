# BioIDCapture-iOS

## Overview

The **BioIDCapture** project demonstrates how to capture images on iOS/iPadOS or macOS and send these images to a server via RESTful API.
On GitHub, we offer two different “BioID RestGrpcForwarder” server implementations that accept RESTful API calls and forward them to our BWS 3 gRPC endpoint.

A basic distinction must be made between the recording of a single image and generating 2 images during a live recording.

[BioID Liveness Detection][DevLivenessDetection] supports different variants of execution, depending on the number of live images and the tags provided in the call.
Also refer to the [Liveness Detection Modes][DevLivenessModes].

**One image**: Only passive liveness detection will be performed.

**Two images**: Passive and active liveness detection will be performed. Beside of the texture based liveness detection on each of the provided 
images a motion based 3D detection on each two consecutive images is executed. All decisions must indicate a live person to finally declare the entire call as live.

**Two images with tagged second image**: Passive and active liveness detection will be performed. Additionally a challenge-response mechanism 
is applied. As we have a motion direction calculated for the face found in the second image, we can check whether this is the same direction as 
demanded by the tags, i.e. whether the head moved up, down, left or right as requested. 


## Technologies

- iOS/iPadOS 12
- Mac Catalyst 14.2
- RESTful
- Objective-C 
- No Third-party libraries


## Get Started

First of all, you can build and run this application immediately to try out the different image capture workflows available. 

If you want to send the images to the BioID Web Service 3, you need the BioID RestGrpcForwarder project. You can use the GitHub repositories 
[BWSClient-RestGrpc-CSharp][RepoRestGrpcCSharp] or [BWSClient-RestGrpc-Java][RepoRestGrpcJava].

The iOS app sends the data to the RestGrpcForwarder via a RESTful call. The server is designed to receive requests from REST endpoints and forward them to gRPC services.

Please follow the instruction in the server repository to configure and start the server.

The communication between app and RESTGrpcForwarder server works with the API authentication `ApiKey`.
The values for the app and the server are already set by default and can be changed if required.

You must make the following settings in the `BWS3Settings.m` file in order to access the server:
- `BWS3_REST_GRPC_ENDPOINT`

> [NOTE] 
> Depending on where the server is started, the URL is different. For example, you can make the server publicly available with TLS (different port than without TLS).
> 
> Or you can host the server directly on the macOS system on which the app is started. For this use case, follow the steps in the article [Accessing your macbook's localhost on your iPhone][ArticleLocalHostAndiPhone].

## How the app works
The app offers 4 different biometric functions.

### Passive Liveness Detection
The simplest implementation is [Passive Liveness Detection][DevLivenessDetection]. 
For this, the standard camera controller `UIImagePickerController` is used to capture exactly one live image. 
After tapping 'Use Photo', the image is displayed in the image viewer of the controller. 
You can then send this image to the RestGrpcForwarder. 

To prepare the image data for the request, the BioIDHelper class offers some useful functions. 

First, use the function `resizeImageForUpload` before sending. 
Then you can use the BioIDHelper function `createJSONRequestBody` to prepare the image data for the request.


### Active Liveness Detection
The ViewController for [Active Liveness Detection][DevLivenessDetection] uses the BioIDCaptureViewController. 
The BioIDCaptureViewController uses the live camera and captures the first image. A second image is triggered by Motion Detection. Both images are returned to the ActiveViewController.

[More details about the BioIDCaptureViewController.](BioIDCaptureViewController.md) 


### Challenge Response
The ViewController for [Challenge Response][DevLivenessDetection] uses the BioIDCaptureViewController. 
In contrast to active liveness detection, a challenge-response mechanism is also used. 
For this purpose, a `challengeTag` is passed to the BioIDCaptureViewController during initialization. 

Possible challenges can be to move the head `up`, `down`, `left` or `right`.

In the BioIDCaptureViewController, “Follow the blue head” appears as a prompt to the user. 
When capturing, the first image is taken and the second image is also triggered with motion detection. 

The BioID Web Service can now check whether the user has performed the same movement that was previously defined.

[More details about the BioIDCaptureViewController.](BioIDCaptureViewController.md) 

### PhotoVerify

[PhotoVerify][DevPhotoVerify] is a service, which uses one photo, e.g. a passport image from an ID document, and compares that to one or 
two "live" images of a person, to find out whether the persons shown are the same. 

The ViewController for PhotoVerify can use either the standard `UIImagePickerController` (for Passive Liveness Detection) 
or the BioIDCaptureViewController (for Active Liveness Detection). 
The `UIImagePickerController` is also used for capturing the ID photo e.g. passport image. 

[More details about the BioIDCaptureViewController.](BioIDCaptureViewController.md) 

### Network Data Transfer

The NSURLSession object checks the [`HTTP Status Codes`][DevLivenessDetection] and evaluates the response from the BioID Web Service and displays it in the ResultViewController.


[DevLivenessDetection]: https://developer.bioid.com/bws/restful/livenessdetection "BioID LivenessDetection - developer.bioid.com" 
[DevPhotoVerify]: https://developer.bioid.com/bws/restful/photoverify "BioID PhotoVerify - developer.bioid.com"
[DevLivenessModes]: https://developer.bioid.com/bws/livenessmodes "BioID Liveness Detection Modes - developer.bioi.com"
[RepoRestGrpcCSharp]: https://github.com/BioID-GmbH/BWSClient-RestGrpc-CSharp "GitHub Repository BWSClient-RestGrpc-CSharp"
[RepoRestGrpcJava]: https://github.com/BioID-GmbH/BWSClient-RestGrpc-Java  "GitHub Repository BWSClient-RestGrpc-Java"
[ArticleLocalHostAndiPhone]: https://ishwar-rimal.medium.com/accessing-macs-localhost-on-your-iphone-5d564a387f09 "Accessing your macbook's localhost on your iPhone"

