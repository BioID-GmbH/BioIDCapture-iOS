//
//  BioIDHelper.m
//  BioIDCapture
//
//  Copyright © 2024 BioID. All rights reserved.
//

#import "BioIDHelper.h"

@implementation BioIDHelper

// Mirror (flip horizontally) the image.
+(UIImage *)mirrorImage:(UIImage *)image {
    // Begin a new image context
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    // Get the current graphics context
    CGContextRef context = UIGraphicsGetCurrentContext();
    // Flip the context horizontally
    CGContextTranslateCTM(context, image.size.width, 0);
    CGContextScaleCTM(context, -1.0, 1.0); // Flip horizontally
    // Draw the original image into the flipped context
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    // Create a new image from the context
    UIImage *mirroredImage = UIGraphicsGetImageFromCurrentImageContext();
    // End the image context
    UIGraphicsEndImageContext();
    return mirroredImage;
}

// The image is resized if it has an image dimension larger than 1600x1200 pixels.
// The images are resized depending on which settings are set for image capturing
// or for a single capture via the ImagePickerController.
// A resolution higher than 1600x1200 pixels is not necessary for the BWS 3 and is
// automatically downscaled. With regard to data transfer and the performance of
// the BWS 3, this functionality should always be used!
+(UIImage *)resizeImageForUpload:(UIImage *)image {
    
    // Current capture setting is AVCaptureSessionPreset1280x720
    // If this capture setting was not changed, the size of these images will not be changed.
    // For landscape image
    if (image.size.width == 1280 && image.size.height == 720) { return image; }
    // For portrait image
    if (image.size.width == 720 && image.size.height == 1280) { return image; }
    
    // Check whether the image is smaller than 1600x1200.
    if (image.size.width > image.size.height && image.size.width < 1600) { return image; }
    if (image.size.width < image.size.height && image.size.width < 1600) { return image; }
        
    int resizeWidth;
    int resizeHeight;
    
    // Set new image dimension with keeping aspect ratio!
    // Landscape mode
    if (image.size.width > image.size.height) {
        resizeWidth = 1600;
        resizeHeight = (resizeWidth/image.size.width) * image.size.height;
    }
    else  { // Portrait mode
        resizeWidth = 1200;
        resizeHeight = (resizeWidth/image.size.width) * image.size.height +1;
    }
    
    // Now resize the image with the new dimension
    // Begin a new image context
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(resizeWidth, resizeHeight), YES, 1.0);
    // Draw the original image into the new context
    [image drawInRect:CGRectMake(0, 0, resizeWidth, resizeHeight)];
    // Create a new image from the context
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    // End the image context
    UIGraphicsEndImageContext();
    
    return resizedImage;
}

// Creates JSON data for the BWS 3 request body with one live image.
+(NSData *)createJSONRequestBody:(UIImage *)liveImage {
    return [BioIDHelper createJSONRequestBody:liveImage withSecondLiveImage:nil withSecondLiveImageTags:nil];
}

// Creates JSON data for the BWS 3 request body with two live images.
+(NSData *)createJSONRequestBody:(UIImage *)liveImage1 withSecondLiveImage:(UIImage *)liveImage2 {
    return [BioIDHelper createJSONRequestBody:liveImage1 withSecondLiveImage:liveImage2 withSecondLiveImageTags:nil];
}

// Creates JSON data for the BWS 3 request body with two live images with tagged second image.
+(NSData *)createJSONRequestBody:(UIImage *)liveImage1 withSecondLiveImage:(UIImage *)liveImage2 withSecondLiveImageTags:(NSString *) stringTags {
    
    // Create array for live images
    NSMutableArray *liveImages = [NSMutableArray array];
    
    if (liveImage1) {
        
        // Create PNG Image
        // Note: Please use the PNG format!!!
        // Unlike the JPG, compression for a PNG file is 'lossless'.
        // A lossy compression can affect biometric operations due to image artifacts.
        NSData *pngLiveImage1 = UIImagePNGRepresentation(liveImage1);
        NSLog(@"PNG FileSize: %.f KB", (float)pngLiveImage1.length/1024.0f);
        
        // Encode the image to base64String
        NSString *base64Image1  = [NSString stringWithFormat:@"%@", [pngLiveImage1 base64EncodedStringWithOptions:0]];
        NSLog(@"PNG Base64 Size: %.f KB", (float)[base64Image1 lengthOfBytesUsingEncoding:NSUTF8StringEncoding]/1024.0f);
        
        // Create JSON structure for the first live image
        NSDictionary *liveImage = @{
            @"image": base64Image1
        };
        
        // Add to array
        [liveImages addObject:liveImage];
    }
    
    if (liveImage2) {
        
        // Create PNG Image
        // Note: Please use the PNG format!!!
        // Unlike the JPG, compression for a PNG file is 'lossless'.
        // A lossy compression can affect biometric operations due to image artifacts.
        NSData *pngLiveImage2 = UIImagePNGRepresentation(liveImage2);
        NSLog(@"PNG FileSize: %.f KB", (float)pngLiveImage2.length/1024.0f);
        
        // Encode the image to base64String
        NSString *base64Image2  = [NSString stringWithFormat:@"%@", [pngLiveImage2 base64EncodedStringWithOptions:0]];
        NSLog(@"PNG Base64 Size: %.f KB", (float)[base64Image2 lengthOfBytesUsingEncoding:NSUTF8StringEncoding]/1024.0f);
        
        // If no tags are defined, this field remains empty.
        if (stringTags == nil) stringTags = @"";
        
        // Create array of tags
        NSArray *tags = [stringTags componentsSeparatedByString:@","];
        
        // Create JSON structure for the second live image
        NSDictionary *liveImage = @{
            @"image": base64Image2,
            @"tags": tags
        };
        
        // Add to array
        [liveImages addObject:liveImage];
    }
    
    // The LivenessDetection request object has a single field:
    NSDictionary *jsonObject = @{@"liveImages": liveImages};
    
    // Serialize to json format
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonObject options:0 error:&error];
    if (error != nil)  {
        NSLog(@"Error creating JSON Request Body:: %@", error);
    }
    
    return jsonData;
}

// Creates JSON data for the BWS 3 request body with one live image and one ID photo.
// By default this BWS 3 API automatically calls into the LivenessDetection API with the provided live image.
// If you do not want to perform a liveness detection at all, simply set this parameter to true.
+(NSData *)createJSONRequestBody:(UIImage *)liveImage withIDPhoto:(UIImage *)idPhoto withDisableLivenessDetection:(Boolean)disableLivenessDetection {
    return [BioIDHelper createJSONRequestBody:liveImage withSecondLiveImage:nil withSecondImageTags:nil withIDPhoto:idPhoto withDisableLivenessDetection:disableLivenessDetection];
}

// Creates JSON data for the BWS 3 request body with two live images with tagged second image and one ID photo.
// By default this BWS 3 API automatically calls into the LivenessDetection API with the provided live images.
// If you do not want to perform a liveness detection at all, simply set this parameter to true.
+(NSData *)createJSONRequestBody:(UIImage *)liveImage1 withSecondLiveImage:(UIImage *)liveImage2 withSecondImageTags:(NSString *) stringTags withIDPhoto:(UIImage *) idPhoto withDisableLivenessDetection:(Boolean)disableLivenessDetection {
    
    // Create array for live images
    NSMutableArray *liveImages = [NSMutableArray array];
    
    if (liveImage1) {
        
        // Create PNG Image
        // Note: Please use the PNG format!!!
        // Unlike the JPG, compression for a PNG file is 'lossless'.
        // A lossy compression can affect biometric operations due to image artifacts.
        NSData *pngLiveImage1 = UIImagePNGRepresentation(liveImage1);
        NSLog(@"PNG FileSize: %.f KB", (float)pngLiveImage1.length/1024.0f);
        
        // Encode the image to base64String
        NSString *base64LiveImage1  = [NSString stringWithFormat:@"%@", [pngLiveImage1 base64EncodedStringWithOptions:0]];
        NSLog(@"PNG Base64 Size: %.f KB", (float)[base64LiveImage1 lengthOfBytesUsingEncoding:NSUTF8StringEncoding]/1024.0f);
        
        // Create JSON structure for the first live image
        NSDictionary *liveImage = @{
            @"image": base64LiveImage1
        };
        
        // Add to array
        [liveImages addObject:liveImage];
    }
    
    if (liveImage2) {
        
        // Create PNG Image
        // Note: Please use the PNG format!!!
        // Unlike the JPG, compression for a PNG file is 'lossless'.
        // A lossy compression can affect biometric operations due to image artifacts.
        NSData *pngLiveImage2 = UIImagePNGRepresentation(liveImage2);
        NSLog(@"PNG FileSize: %.f KB", (float)pngLiveImage2.length/1024.0f);
        
        // Encode the image to base64String
        NSString *base64LiveImage2  = [NSString stringWithFormat:@"%@", [pngLiveImage2 base64EncodedStringWithOptions:0]];
        NSLog(@"PNG Base64 Size: %.f KB", (float)[base64LiveImage2 lengthOfBytesUsingEncoding:NSUTF8StringEncoding]/1024.0f);
        
        // Create an array of tags by separating them with ','
        NSArray *tags = [stringTags componentsSeparatedByString:@","];
        
        // Create JSON structure for the second live image
        NSDictionary *liveImage = @{
            @"image": base64LiveImage2,
            @"tags": tags
        };
        
        // Add to array
        [liveImages addObject:liveImage];
    }
    
    NSString *base64IdPhoto;
    if (idPhoto) {
        
        // Create PNG Image
        // Note: Please use the PNG format!!!
        // Unlike the JPG, compression for a PNG file is 'lossless'.
        // A lossy compression can affect biometric operations due to image artifacts.
        NSData *pngIdPhotoImage = UIImagePNGRepresentation(idPhoto);
        NSLog(@"PNG FileSize: %.f KB", (float)pngIdPhotoImage.length/1024.0f);
        
        // Encode the image to base64String
        base64IdPhoto = [NSString stringWithFormat:@"%@", [pngIdPhotoImage base64EncodedStringWithOptions:0]];
        NSLog(@"PNG Base64 Size: %.f KB", (float)[base64IdPhoto lengthOfBytesUsingEncoding:NSUTF8StringEncoding]/1024.0f);
    }
    
    // Create final json object
    NSDictionary *jsonObject = @{@"liveImages": liveImages, @"photo": base64IdPhoto}; //, @"disableLivenessDetection": disable};
    
    // Serialize to json format
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonObject options:0 error:&error];
    if (error != nil) {
        NSLog(@"Error creating JSON Request Body: %@", error);
    }
    
    return jsonData;
}

@end
