//
//  _DeepViewController.m
//  3Deep
//
//  Created by Rob Cavin on 5/26/11.
//  Copyright 2011 BumblebeeJuice. All rights reserved.
//

#import "_DeepViewController.h"
#import <CoreMotion/CoreMotion.h>
#import <AVFoundation/AVFoundation.h>

@implementation _DeepViewController

@synthesize session;
@synthesize motionManager;
@synthesize captureNewButton;
@synthesize stepCurrentButton;
@synthesize frameImageView;
@synthesize cameraView;
@synthesize frameCaptureData;
@synthesize camera;

#define NUM_FRAMES_TO_CAPTURE 10

- (void)dealloc
{
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    motionManager = [[CMMotionManager alloc] init]; 
    motionManager.deviceMotionUpdateInterval = 0.05;
    [motionManager startDeviceMotionUpdates];
    
    [self setupCaptureSession];
    
    NSLog(@"I'm alive");

}


- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    
    //[self setupCaptureSession];
    
    NSLog(@"I'm dead");
}


// Create and configure a capture session and start it running
- (void)setupCaptureSession 
{
    NSError *error = nil;
    
    // Create the session
    self.session = [[AVCaptureSession alloc] init];
    
    // Configure the session to produce lower resolution video frames, if your 
    // processing algorithm can cope. We'll specify medium quality for the
    // chosen device.
    session.sessionPreset = AVCaptureSessionPresetMedium;
    
    // Find a suitable AVCaptureDevice
    self.camera = [AVCaptureDevice
                   defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    // Create a device input with the device and add it to the session.
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:camera 
                                                                        error:&error];
    if (!input) {
        // Handling the error appropriately.
    }
    [session addInput:input];
    
    // Create a VideoDataOutput and add it to the session
    AVCaptureVideoDataOutput *output = [[[AVCaptureVideoDataOutput alloc] init] autorelease];
    [session addOutput:output];
    
    // Configure your output.
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    dispatch_release(queue);
    
    // Specify the pixel format
    output.videoSettings = 
    [NSDictionary dictionaryWithObject:
     [NSNumber numberWithInt:kCVPixelFormatType_32BGRA] 
                                forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    
    // If you wish to cap the frame rate to a known value, such as 15 fps, set 
    // minFrameDuration.
    output.minFrameDuration = CMTimeMake(1, 15);
    
    //AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
    //previewLayer.frame = self.cameraView.bounds; // Assume you want the preview layer to fill the view.
    //[self.cameraView.layer addSublayer:previewLayer];
    
}

- (IBAction) captureNewButtonPressed {
    // Start the session running to start the flow of data
    currentFrame = 0;
    [session startRunning];
    self.frameCaptureData = [NSMutableArray arrayWithCapacity:NUM_FRAMES_TO_CAPTURE];

}

- (void) test:(UIImage*)image {
    frameImageView.image = image;
    [image release];
}

// Delegate routine that is called when a sample buffer was written
- (void)captureOutput:(AVCaptureOutput *)captureOutput 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
       fromConnection:(AVCaptureConnection *)connection
{ 
    
    if ([camera isAdjustingFocus] || [camera isAdjustingExposure] || [camera isAdjustingWhiteBalance]) return;
    
    // Create a UIImage from the sample buffer data
    UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
    [image retain];
    [self performSelectorOnMainThread:@selector(test:) withObject:image waitUntilDone:NO];
    
    CMDeviceMotion* currentMotionInfo = motionManager.deviceMotion;

    NSMutableDictionary* imageWData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       //image,   @"image",
                                       currentMotionInfo, @"motionInfo",
                                       nil];
    
    [frameCaptureData addObject:imageWData];
    
    NSLog(@"Captured frame %d",currentFrame);
        
    NSString* path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* fileName = [path stringByAppendingFormat:@"/image%d.png",currentFrame+1];
    NSData* imageData = UIImagePNGRepresentation(image);
    [imageData writeToFile:fileName atomically:YES];

    if (++currentFrame == NUM_FRAMES_TO_CAPTURE) {
        
        NSLog(@"%@",frameCaptureData);
        
        
        NSString* path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];

    /*    int i = 0;
        for (NSMutableDictionary* frameCapture in frameCaptureData) {
            NSLog(@"%@",[frameCapture objectForKey:@"image"]);
            NSString* fileName = [path stringByAppendingFormat:@"/image%d.png",i+1];
            NSData* imageData = UIImagePNGRepresentation([frameCapture objectForKey:@"image"]);
            [imageData writeToFile:fileName atomically:YES];
            [frameCapture removeObjectForKey:@"image"];
            i++;
        }*/
        NSString* fileName = [path stringByAppendingFormat:@"/image_data.png",currentFrame+1];
        
        [NSKeyedArchiver archiveRootObject:frameCaptureData toFile:fileName];
        self.frameCaptureData = nil;

        [session stopRunning];
        currentFrame = 0;
        NSLog(@"Done encoding");
    }   
}

-(IBAction) stepCurrentButtonPressed {
    
    if (!self.frameCaptureData) {
        NSString* path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString* fileName = [path stringByAppendingFormat:@"/image_data.png",currentFrame+1];
        NSArray* motionData = [NSKeyedUnarchiver unarchiveObjectWithFile:fileName];
        
        self.frameCaptureData = [NSMutableArray array];
        for (NSDictionary* motionDataDict in motionData) {
            NSMutableDictionary* temp = [NSMutableDictionary dictionary];
            [temp addEntriesFromDictionary:motionDataDict];
            [self.frameCaptureData addObject:temp];
        }
        
        int i = 0;
        for (NSMutableDictionary* dict in frameCaptureData) {
            NSString* fileName = [path stringByAppendingFormat:@"/image%d.png",i+1];
            UIImage* image = [UIImage imageWithContentsOfFile:fileName];
            [dict setObject:image forKey:@"image"];
            i++;
        }
            
        
    }
    
    CMDeviceMotion* motion = [[frameCaptureData objectAtIndex:0] objectForKey:@"motionInfo"];
    CMDeviceMotion* newMotion = [[frameCaptureData objectAtIndex:currentFrame] objectForKey:@"motionInfo"];
    
    NSLog(@"motion = %@, new motion = %@",motion,newMotion);
    CMAttitude* attitude = motion.attitude;
    CMAttitude* attitudeDelta = ((CMDeviceMotion*) [newMotion copy]).attitude;
    
    [attitudeDelta multiplyByInverseOfAttitude:attitude];
    CMRotationMatrix rotMatrix = attitudeDelta.rotationMatrix;
    NSLog(@"rotation matrix %f %f %f",rotMatrix.m11, rotMatrix.m12,rotMatrix.m13);
    NSLog(@"rotation matrix %f %f %f",rotMatrix.m21, rotMatrix.m22,rotMatrix.m23);
    NSLog(@"rotation matrix %f %f %f",rotMatrix.m31, rotMatrix.m32,rotMatrix.m33);
    
    CATransform3D transform;
    transform.m11 = rotMatrix.m11; transform.m12 = rotMatrix.m12; transform.m13 = rotMatrix.m13; transform.m14 = 0;
    transform.m21 = rotMatrix.m21; transform.m22 = rotMatrix.m22; transform.m23 = rotMatrix.m23; transform.m24 = 0;
    transform.m31 = rotMatrix.m31; transform.m32 = rotMatrix.m32; transform.m33 = rotMatrix.m33; transform.m34 = 100;
    transform.m41 = 0;             transform.m42 = 0;             transform.m43 = 0;             transform.m44 = 1;
    
    NSLog(@"Showing frame %d of %d",currentFrame,[frameCaptureData count]);
        
    NSDictionary* imageWData = [frameCaptureData objectAtIndex:currentFrame];
    NSLog(@"%@",[imageWData allKeys]);
    
    //UIImage* image = [UIImage imageWithData:[imageWData objectForKey:@"imageData"]];
    UIImage* image = [imageWData objectForKey:@"image"];
    NSLog(@"%f %f",image.size.width, image.size.height);
    frameImageView.image = image;
    //frameImageView.layer.zPosition = 100;
    frameImageView.layer.transform = transform;
    
    [frameImageView setNeedsDisplay];
    
    currentFrame = (currentFrame+1) % NUM_FRAMES_TO_CAPTURE;
    
}

// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer 
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer); 
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer); 
    size_t height = CVPixelBufferGetHeight(imageBuffer); 
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB(); 
    if (!colorSpace) 
    {
        NSLog(@"CGColorSpaceCreateDeviceRGB failure");
        return nil;
    }
    
    // Get the base address of the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    // Get the data size for contiguous planes of the pixel buffer.
    size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer); 
    
    // Create a Quartz direct-access data provider that uses data we supply
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, baseAddress, bufferSize, 
                                                              NULL);
    // Create a bitmap image from data supplied by our data provider
    CGImageRef cgImage = 
    CGImageCreate(width,
                  height,
                  8,
                  32,
                  bytesPerRow,
                  colorSpace,
                  kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little,
                  provider,
                  NULL,
                  true,
                  kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    CGImageRef cgImageCopy = CGImageCreateCopy(cgImage);
    // Create and return an image object representing the specified Quartz image
    UIImage *image = [UIImage imageWithCGImage:cgImageCopy];
    CGImageRelease(cgImageCopy);
    CGImageRelease(cgImage);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    return image;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end
