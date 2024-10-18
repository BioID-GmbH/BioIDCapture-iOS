# BioIDCapture-iOS

## Overview

The **BioIDCapture** project demonstrates how to capture images on iOS/iPadOS or macOS and and sending these images to a server via RESTful API.
On GitHub, we offer two different “BioID RestGrpcForwarder” server implementations that accept RESTful API calls and forward them to our BWS 3 gRPC endpoint.

The implementation of BioIDCapture-iOS is in Objective-C and requires no further third party libraries.

A basic distinction must be made between taking a single image and generating 2 images during a live recording.

[BioID Liveness Detection][DevLivenessDetection] supports different variants of execution, depending on the number of live images and the tags provided in the call.
Also refer to the [Liveness Detection Modes][DevLivenessModes].

**One image**: Only passive liveness detection will be performed.

**Two images**: Passive and active liveness detection will be performed. Beside of the texture based liveness detection on each of the provided 
images a motion based 3D detection on each two consecutive images is executed. All decisions must indicate a live person to finally declare the entire call as live.

**Two images with tagged second image**: Passive and active liveness detection will be performed. Additionally a challenge-response mechanism 
is applied. As we have a motion direction calculated for the face found in the second image, we can check whether this is the same direction as 
demanded by the tags, i.e. whether the head moved up, down, left or right as requested. 








[DevLivenessDetection]: https://developer.bioid.com/bws/grpc/livenessdetection "BioID LivenessDetection - developer.bioid.com" 
[DevLivenessModes]: https://developer.bioid.com/bws/livenessmodes "BioID Liveness Detection Modes - developer.bioi.com"
