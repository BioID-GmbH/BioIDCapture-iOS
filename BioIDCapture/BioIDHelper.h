///
//  BioIDHelper.h
//  BioIDCapture
//
//  Copyright © 2024 BioID. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BioIDHelper : NSObject

+(UIImage *)mirrorImage:(UIImage *)image;
+(UIImage *)resizeImageForUpload:(UIImage *)image;
+(NSData *)createJSONRequestBody:(UIImage *)liveImage;
+(NSData *)createJSONRequestBody:(UIImage *)liveImage1 withSecondLiveImage:(UIImage *)liveImage2;
+(NSData *)createJSONRequestBody:(UIImage *)liveImage1 withSecondLiveImage:(UIImage *)liveImage2 withSecondLiveImageTags:(NSString *)stringTags;
+(NSData *)createJSONRequestBody:(UIImage *)liveImage withIDPhoto:(UIImage *)idPhoto withDisableLivenessDetection:(Boolean)disableLivenessDetection;
+(NSData *)createJSONRequestBody:(UIImage *)liveImage1 withSecondLiveImage:(UIImage *)liveImage2 withSecondImageTags:(NSString *)stringTags withIDPhoto:(UIImage *)idPhoto withDisableLivenessDetection:(Boolean)disableLivenessDetection;

@end
