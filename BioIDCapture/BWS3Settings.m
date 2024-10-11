//
//  BWS3Settings.m
//  BioIDCapture
//
//  Copyright © 2024 BioID. All rights reserved.
//

#import <Foundation/Foundation.h>

// Please set the endpoint and ApiKey of the test server (GitHub: BioID.RestGrpcForwarder)
NSString * const BWS3_REST_GRPC_ENDPOINT =  @"http://:5226"; 
NSString * const BWS3_REST_GRPC_APIKEY = @"HwYrknSCZWPuIXX2B6Gg6Z7HjwR4WqdZ";

// Biometric tasks
NSString * const BWS3_TASK_LIVENESSDETECTION = @"/livenessdetection";
NSString * const BWS3_TASK_PHOTOVERIFY = @"/photoverify";
