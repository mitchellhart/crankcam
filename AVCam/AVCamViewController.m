/*
     File: AVCamViewController.m
 Abstract: View controller for camera interface.
  Version: 3.1
 */

#import "AVCamViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "AVCamPreviewView.h"
#import <mach/mach_time.h>

static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};

static void * CapturingStillImageContext = &CapturingStillImageContext;
static void * RecordingContext = &RecordingContext;
static void * SessionRunningAndDeviceAuthorizedContext = &SessionRunningAndDeviceAuthorizedContext;

@interface AVCamViewController () <AVCaptureFileOutputRecordingDelegate>

// For use in the storyboards.
@property (nonatomic, weak) IBOutlet AVCamPreviewView *previewView;
@property (nonatomic, weak) IBOutlet UIButton *recordButton;
@property (nonatomic, weak) IBOutlet UIButton *cameraButton;
@property (nonatomic, weak) IBOutlet UIButton *stillButton;

- (IBAction)toggleMovieRecording:(id)sender;
- (IBAction)changeCamera:(id)sender;
//- (IBAction)snapStillImage:(id)sender;
- (IBAction)focusAndExposeTap:(UIGestureRecognizer *)gestureRecognizer;

// Session management.
@property (nonatomic) dispatch_queue_t sessionQueue; // Communicate with the session and other session objects on this queue.
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureDevice *videoDevice;
@property (nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;


// Utilities.
@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;
@property (nonatomic, getter = isDeviceAuthorized) BOOL deviceAuthorized;
@property (nonatomic, readonly, getter = isSessionRunningAndDeviceAuthorized) BOOL sessionRunningAndDeviceAuthorized;
@property (nonatomic) BOOL lockInterfaceRotation;
@property (nonatomic) id runtimeErrorHandlingObserver;

@end

@implementation AVCamViewController


//@synthesize takePictureButton;
int pictureCount = 0;
double speed = 0;
float degrees;

- (BOOL)isSessionRunningAndDeviceAuthorized
{
	return [[self session] isRunning] && [self isDeviceAuthorized];
}

+ (NSSet *)keyPathsForValuesAffectingSessionRunningAndDeviceAuthorized
{
	return [NSSet setWithObjects:@"session.running", @"deviceAuthorized", nil];
}


//------------- FOR ROTATION -------------//

double wrapd(double _val, double _min, double _max)
{
    if(_val < _min) return _max - (_min - _val);
    if(_val > _max) return _min - (_max - _val);
    return _val;
}

//------------- FOR ROTATION -------------//


- (void)viewDidLoad
{
	[super viewDidLoad];
    
    savedLabel.alpha = 0;
    
	// Create the AVCaptureSession
	AVCaptureSession *session = [[AVCaptureSession alloc] init];
	[self setSession:session];
	
	// Setup the preview view
	[[self previewView] setSession:session];
	
	// Check for device authorization
	[self checkDeviceAuthorizationStatus];
    
    frameDuration = CMTimeMakeWithSeconds(1./24., 90000);
    
	
	// In general it is not safe to mutate an AVCaptureSession or any of its inputs, outputs, or connections from multiple threads at the same time.
	// Why not do all of this on the main queue?
	// -[AVCaptureSession startRunning] is a blocking call which can take a long time. We dispatch session setup to the sessionQueue so that the main queue isn't blocked (which keeps the UI responsive).
	
	dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
	[self setSessionQueue:sessionQueue];
	
	dispatch_async(sessionQueue, ^{
		[self setBackgroundRecordingID:UIBackgroundTaskInvalid];
		
		NSError *error = nil;
		
		AVCaptureDevice *videoDevice = [AVCamViewController deviceWithMediaType:AVMediaTypeVideo preferringPosition:AVCaptureDevicePositionBack];
		AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
		
		if (error)
		{
			NSLog(@"%@", error);
		}
		
		if ([session canAddInput:videoDeviceInput])
		{
			[session addInput:videoDeviceInput];
			[self setVideoDeviceInput:videoDeviceInput];

			dispatch_async(dispatch_get_main_queue(), ^{
				// Why are we dispatching this to the main queue?
				// Because AVCaptureVideoPreviewLayer is the backing layer for AVCamPreviewView and UIView can only be manipulated on main thread.
				// Note: As an exception to the above rule, it is not necessary to serialize video orientation changes on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.
  
				[[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] setVideoOrientation:(AVCaptureVideoOrientation)[self interfaceOrientation]];
			});
		}
		
		
		AVCaptureMovieFileOutput *movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
		if ([session canAddOutput:movieFileOutput])
		{
			[session addOutput:movieFileOutput];
			AVCaptureConnection *connection = [movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
			if ([connection isVideoStabilizationSupported])
				[connection setEnablesVideoStabilizationWhenAvailable:YES];
			[self setMovieFileOutput:movieFileOutput];
		}
        
        
        // Make a still image output
        stillImageOutput = [AVCaptureStillImageOutput new];
        if ([session canAddOutput:stillImageOutput])
            [session addOutput:stillImageOutput];
	});


//------------- FOR CRANK ROTATION -------------//

    m_block.center = self.view.center;
    [self.view addSubview:m_block];
   // [m_block release];
    
}


- (void)countDown
    {
    timerInt ++;
    timerLabel.text = [NSString stringWithFormat:@"%i", timerInt];
    }

//--------TOUCH BEGIN, MOVE, AND END-------------//


- (void)touchesBegan:(NSSet *)_touches withEvent:(UIEvent *)_event
{
    UITouch* touch = [_touches anyObject];
    CGPoint location = [touch locationInView:self.view];
    m_locationBegan = location;
    NSLog(@"touch started, buddy");
    timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(countDown) userInfo:nil repeats:YES];
    [self toggleMovieRecording];
}

- (void) touchesMoved:(NSSet *)_touches withEvent:(UIEvent *)_event
{
    UITouch* touch = [_touches anyObject];
    CGPoint location = [touch locationInView:self.view];
    [self updateRotation:location];

}

- (void) touchesEnded:(NSSet *)_touches withEvent:(UIEvent *)_event
{
    UITouch* touch = [_touches anyObject];
    CGPoint location = [touch locationInView:self.view];
    m_currentAngle = [self updateRotation:location];
    NSLog(@"touch ended, yo");
    [timer invalidate];
    timerInt = 0;

    
    [[self movieFileOutput] stopRecording];


    
    //-----AFTER TOUCH EVENT ENDS, this stops AVAssetWriter and lauches saveMovie funcion
//    if (assetWriter) {
//        [assetWriterInput markAsFinished];
//        [assetWriter finishWriting];
//        assetWriterInput = nil;
//        assetWriter = nil;
//        [self saveMovieToCameraRoll];
//    }
    

    [UIView animateWithDuration:.3 animations:^(void) {
        savedLabel.alpha = 0;
        savedLabel.alpha = 1;
    }];

    [self performSelector:@selector(delay) withObject:nil afterDelay: .6];
}


- (void)toggleMovieRecording
{
    //[[self recordButton] setEnabled:NO];
    
    dispatch_async([self sessionQueue], ^{
        if (![[self movieFileOutput] isRecording])
        {
            [self setLockInterfaceRotation:YES];
            
            if ([[UIDevice currentDevice] isMultitaskingSupported])
            {
                // Setup background task. This is needed because the captureOutput:didFinishRecordingToOutputFileAtURL: callback is not received until the app returns to the foreground unless you request background execution time. This also ensures that there will be time to write the file to the assets library when the app is backgrounded. To conclude this background execution, -endBackgroundTask is called in -recorder:recordingDidFinishToOutputFileURL:error: after the recorded file has been saved.
                [self setBackgroundRecordingID:[[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil]];
            }
            
            // Update the orientation on the movie file output video connection before starting recording.
            [[[self movieFileOutput] connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:[[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] videoOrientation]];
            
            // Turn OFF flash for video recording
            [AVCamViewController setFlashMode:AVCaptureFlashModeOff forDevice:[self videoDevice]];
            
            // Start recording to a temporary file.
            NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"movie" stringByAppendingPathExtension:@"mov"]];
            [[self movieFileOutput] startRecordingToOutputFileURL:[NSURL fileURLWithPath:outputFilePath] recordingDelegate:self];
        }
        else
        {
            return;
            //[[self movieFileOutput] stopRecording];
        }
    });
}



//----------Delay after finish crank ------//


-(void) delay {
    
        pictureCount = 0;
        frameLabel.text = [NSString stringWithFormat: @"%i frames taken", pictureCount];
    
    [UIView animateWithDuration:1.5 animations:^(void) {
        savedLabel.alpha = 1;
        savedLabel.alpha = 0;
    }];

}


- (float) updateRotation:(CGPoint)_location
{

    float fromAngle = atan2(m_locationBegan.y-m_block.center.y, m_locationBegan.x-m_block.center.x);
    float toAngle = atan2(_location.y-m_block.center.y, _location.x-m_block.center.x);
    float newAngle = wrapd(m_currentAngle + (toAngle - fromAngle), 0, 2*3.14);
    
    CGAffineTransform cgaRotate = CGAffineTransformMakeRotation(newAngle);
    m_block.transform = cgaRotate;
    
    int oneInFifty = (newAngle*50)/(2*3.14);
    
    
    int oneRotation = (newAngle)/(2*3.14);
    
    
    //------ display angle info and frames taken-----//
    
    
    //---average speed----//
    speed = (newAngle/timerInt);
    degrees = (newAngle * 57.2957795);
    
    
    infoLabel.text = [NSString stringWithFormat:@"Angle: %f : %i", degrees, oneRotation];
    frameLabel.text = [NSString stringWithFormat: @"%i frames taken", pictureCount];
    speedLabel.text = [NSString stringWithFormat:@"speed: %f", speed];
    
    
   
    if (oneInFifty==10 || oneInFifty==20 || oneInFifty==30 || oneInFifty==40 || oneInFifty==49 )
    
    {
        
        NSLog(@"Rotation works %i", oneRotation);
        
        
        // Capture a still image.
        //[self takePicture];
//        static dispatch_once_t predicate;
//        dispatch_once(&predicate, ^{
//            pictureCount ++; // should happen once per object
//        });
        

        pictureCount ++;
        
        
    }
   
   return newAngle;
}


- (BOOL)setupAssetWriterForURL:(NSURL *)fileURL formatDescription:(CMFormatDescriptionRef)formatDescription
{
    // allocate the writer object with our output file URL
    NSError *error = nil;
    assetWriter = [[AVAssetWriter alloc] initWithURL:fileURL fileType:AVFileTypeQuickTimeMovie error:&error];
    if (error)
        return NO;
    
    // initialized a new input for video to receive sample buffers for writing
    // passing nil for outputSettings instructs the input to pass through appended samples, doing no processing before they are written
    assetWriterInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:nil];
    [assetWriterInput setExpectsMediaDataInRealTime:YES];
    if ([assetWriter canAddInput:assetWriterInput])
        [assetWriter addInput:assetWriterInput];
    
    // specify the prefered transform for the output file
    CGFloat rotationDegrees;
    switch ([[UIDevice currentDevice] orientation]) {
        case UIDeviceOrientationPortraitUpsideDown:
            rotationDegrees = -90.;
            break;
        case UIDeviceOrientationLandscapeLeft: // no rotation
            rotationDegrees = 0.;
            break;
        case UIDeviceOrientationLandscapeRight:
            rotationDegrees = 180.;
            break;
        case UIDeviceOrientationPortrait:
        case UIDeviceOrientationUnknown:
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationFaceDown:
        default:
            rotationDegrees = 90.;
            break;
    }
    CGFloat rotationRadians = DegreesToRadians(rotationDegrees);
    
    [assetWriterInput setTransform:CGAffineTransformMakeRotation(rotationRadians)];
    
    // initiates a sample-writing at time 0
    nextPTS = kCMTimeZero;
    [assetWriter startWriting];
    [assetWriter startSessionAtSourceTime:nextPTS];
    
    return YES;
}


- (void)saveMovieToCameraRoll
{
    // save the movie to the camera roll
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    //NSLog(@"writing \"%@\" to photos album", outputURL);
    [library writeVideoAtPathToSavedPhotosAlbum:outputURL
                                completionBlock:^(NSURL *assetURL, NSError *error) {
                                    if (error) {
                                        NSLog(@"assets library failed (%@)", error);
                                    }
                                    else {
                                        [[NSFileManager defaultManager] removeItemAtURL:outputURL error:&error];
                                        if (error)
                                            NSLog(@"Couldn't remove temporary movie file \"%@\"", outputURL);
                                    }
                                    outputURL = nil;
                                }];
}



//-----THIS STARTED / FINISHED THE AVASSETWRITER AND KICKED OFF SAVEMOVIE....

//- (IBAction)startStop:(id)sender
//{
//    if (started) {
//        NSLog(@"AVAsset is initialized");
//        if (assetWriter) {
//            [assetWriterInput markAsFinished];
//            [assetWriter finishWriting];
//            assetWriterInput = nil;
//            assetWriter = nil;
//            [self saveMovieToCameraRoll];
//        }
//        [sender setTitle:@"Start"];
//        [takePictureButton setEnabled:NO];
//    }
//    else {
//        [sender setTitle:@"Finish"];
//        //[takePictureButton setEnabled:YES];
//        
//    }
//    started = !started;
//}
//
//



 

- (void)viewWillAppear:(BOOL)animated
{
	dispatch_async([self sessionQueue], ^{
		[self addObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:SessionRunningAndDeviceAuthorizedContext];
		[self addObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:CapturingStillImageContext];
		[self addObserver:self forKeyPath:@"movieFileOutput.recording" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:RecordingContext];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:[[self videoDeviceInput] device]];
		
		__weak AVCamViewController *weakSelf = self;
		[self setRuntimeErrorHandlingObserver:[[NSNotificationCenter defaultCenter] addObserverForName:AVCaptureSessionRuntimeErrorNotification object:[self session] queue:nil usingBlock:^(NSNotification *note) {
			AVCamViewController *strongSelf = weakSelf;
			dispatch_async([strongSelf sessionQueue], ^{
				// Manually restarting the session since it must have been stopped due to an error.
				[[strongSelf session] startRunning];
				[[strongSelf recordButton] setTitle:NSLocalizedString(@"Record", @"Recording button record title") forState:UIControlStateNormal];
			});
		}]];
		[[self session] startRunning];
	});
}

- (void)viewDidDisappear:(BOOL)animated
{
	dispatch_async([self sessionQueue], ^{
		[[self session] stopRunning];
		
		[[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:[[self videoDeviceInput] device]];
		[[NSNotificationCenter defaultCenter] removeObserver:[self runtimeErrorHandlingObserver]];
		
		[self removeObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" context:SessionRunningAndDeviceAuthorizedContext];
		[self removeObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" context:CapturingStillImageContext];
		[self removeObserver:self forKeyPath:@"movieFileOutput.recording" context:RecordingContext];
	});
}


- (BOOL)prefersStatusBarHidden
{
	return YES;
}

- (BOOL)shouldAutorotate
{
	// Disable autorotation of the interface when recording is in progress.
	return ![self lockInterfaceRotation];
}

- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskAll;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] setVideoOrientation:(AVCaptureVideoOrientation)toInterfaceOrientation];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == CapturingStillImageContext)
	{
		BOOL isCapturingStillImage = [change[NSKeyValueChangeNewKey] boolValue];
		
		if (isCapturingStillImage)
		{
			[self runStillImageCaptureAnimation];
		}
	}
	else if (context == RecordingContext)
	{
		BOOL isRecording = [change[NSKeyValueChangeNewKey] boolValue];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if (isRecording)
			{
				[[self cameraButton] setEnabled:NO];
				[[self recordButton] setTitle:NSLocalizedString(@"Stop", @"Recording button stop title") forState:UIControlStateNormal];
				[[self recordButton] setEnabled:YES];
			}
			else
			{
				[[self cameraButton] setEnabled:YES];
				[[self recordButton] setTitle:NSLocalizedString(@"Record", @"Recording button record title") forState:UIControlStateNormal];
				[[self recordButton] setEnabled:YES];
			}
		});
	}
	else if (context == SessionRunningAndDeviceAuthorizedContext)
	{
		BOOL isRunning = [change[NSKeyValueChangeNewKey] boolValue];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if (isRunning)
			{
				[[self cameraButton] setEnabled:YES];
				[[self recordButton] setEnabled:YES];
				[[self stillButton] setEnabled:YES];
			}
			else
			{
				[[self cameraButton] setEnabled:NO];
				[[self recordButton] setEnabled:NO];
				[[self stillButton] setEnabled:NO];
			}
		});
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

#pragma mark Actions


//---------------CODE FOR VIDEO RECORD AND SAVE--------------------//


- (IBAction)toggleMovieRecording:(id)sender
{
	[[self recordButton] setEnabled:NO];
	
	dispatch_async([self sessionQueue], ^{
		if (![[self movieFileOutput] isRecording])
		{
			[self setLockInterfaceRotation:YES];
			
			if ([[UIDevice currentDevice] isMultitaskingSupported])
			{
				// Setup background task. This is needed because the captureOutput:didFinishRecordingToOutputFileAtURL: callback is not received until AVCam returns to the foreground unless you request background execution time. This also ensures that there will be time to write the file to the assets library when AVCam is backgrounded. To conclude this background execution, -endBackgroundTask is called in -recorder:recordingDidFinishToOutputFileURL:error: after the recorded file has been saved.
				[self setBackgroundRecordingID:[[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil]];
			}
			
			// Update the orientation on the movie file output video connection before starting recording.
			[[[self movieFileOutput] connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:[[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] videoOrientation]];
			
			// Turning OFF flash for video recording
			[AVCamViewController setFlashMode:AVCaptureFlashModeOff forDevice:[[self videoDeviceInput] device]];
			
			// Start recording to a temporary file.
			NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"movie" stringByAppendingPathExtension:@"mov"]];
			[[self movieFileOutput] startRecordingToOutputFileURL:[NSURL fileURLWithPath:outputFilePath] recordingDelegate:self];
		}
		else
		{
			[[self movieFileOutput] stopRecording];
		}
	});
}



- (IBAction)changeCamera:(id)sender
{
	[[self cameraButton] setEnabled:NO];
	[[self recordButton] setEnabled:NO];
	[[self stillButton] setEnabled:NO];
	
	dispatch_async([self sessionQueue], ^{
		AVCaptureDevice *currentVideoDevice = [[self videoDeviceInput] device];
		AVCaptureDevicePosition preferredPosition = AVCaptureDevicePositionUnspecified;
		AVCaptureDevicePosition currentPosition = [currentVideoDevice position];
		
		switch (currentPosition)
		{
			case AVCaptureDevicePositionUnspecified:
				preferredPosition = AVCaptureDevicePositionBack;
				break;
			case AVCaptureDevicePositionBack:
				preferredPosition = AVCaptureDevicePositionFront;
				break;
			case AVCaptureDevicePositionFront:
				preferredPosition = AVCaptureDevicePositionBack;
				break;
		}
		
		AVCaptureDevice *videoDevice = [AVCamViewController deviceWithMediaType:AVMediaTypeVideo preferringPosition:preferredPosition];
		AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
		
		[[self session] beginConfiguration];
		
		[[self session] removeInput:[self videoDeviceInput]];
		if ([[self session] canAddInput:videoDeviceInput])
		{
			[[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:currentVideoDevice];
			
			[AVCamViewController setFlashMode:AVCaptureFlashModeOff forDevice:videoDevice];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:videoDevice];
			
			[[self session] addInput:videoDeviceInput];
			[self setVideoDeviceInput:videoDeviceInput];
		}
		else
		{
			[[self session] addInput:[self videoDeviceInput]];
		}
		
		[[self session] commitConfiguration];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[[self cameraButton] setEnabled:YES];
			[[self recordButton] setEnabled:YES];
			[[self stillButton] setEnabled:YES];
		});
	});
}






- (IBAction)focusAndExposeTap:(UIGestureRecognizer *)gestureRecognizer
{
	CGPoint devicePoint = [(AVCaptureVideoPreviewLayer *)[[self previewView] layer] captureDevicePointOfInterestForPoint:[gestureRecognizer locationInView:[gestureRecognizer view]]];
	[self focusWithMode:AVCaptureFocusModeLocked exposeWithMode:AVCaptureExposureModeAutoExpose atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
}

- (void)subjectAreaDidChange:(NSNotification *)notification
{
	CGPoint devicePoint = CGPointMake(.5, .5);
	[self focusWithMode:AVCaptureFocusModeLocked exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:NO];
}



#pragma mark File Output Delegate

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
	if (error)
		NSLog(@"%@", error);
	
	[self setLockInterfaceRotation:NO];
	
	// Note the backgroundRecordingID for use in the ALAssetsLibrary completion handler to end the background task associated with this recording. This allows a new recording to be started, associated with a new UIBackgroundTaskIdentifier, once the movie file output's -isRecording is back to NO — which happens sometime after this method returns.
	UIBackgroundTaskIdentifier backgroundRecordingID = [self backgroundRecordingID];
	[self setBackgroundRecordingID:UIBackgroundTaskInvalid];
	
	[[[ALAssetsLibrary alloc] init] writeVideoAtPathToSavedPhotosAlbum:outputFileURL completionBlock:^(NSURL *assetURL, NSError *error) {
		if (error)
			NSLog(@"%@", error);
		
		[[NSFileManager defaultManager] removeItemAtURL:outputFileURL error:nil];
		
		if (backgroundRecordingID != UIBackgroundTaskInvalid)
			[[UIApplication sharedApplication] endBackgroundTask:backgroundRecordingID];
	}];
}

#pragma mark Device Configuration



- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange
{
	dispatch_async([self sessionQueue], ^{
		AVCaptureDevice *device = [[self videoDeviceInput] device];
		NSError *error = nil;
		if ([device lockForConfiguration:&error])
		{
			if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:focusMode])
			{
				[device setFocusMode:focusMode];
				[device setFocusPointOfInterest:point];
			}
			if ([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:exposureMode])
			{
				[device setExposureMode:exposureMode];
				[device setExposurePointOfInterest:point];
			}
			[device setSubjectAreaChangeMonitoringEnabled:monitorSubjectAreaChange];
			[device unlockForConfiguration];
		}
		else
		{
			NSLog(@"%@", error);
		}
	});
}
 
 

+ (void)setFlashMode:(AVCaptureFlashMode)flashMode forDevice:(AVCaptureDevice *)device
{
	if ([device hasFlash] && [device isFlashModeSupported:flashMode])
	{
		NSError *error = nil;
		if ([device lockForConfiguration:&error])
		{
			[device setFlashMode:flashMode];
			[device unlockForConfiguration];
		}
		else
		{
			NSLog(@"%@", error);
		}
	}
}

+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
	NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
	AVCaptureDevice *captureDevice = [devices firstObject];
	
	for (AVCaptureDevice *device in devices)
	{
		if ([device position] == position)
		{
			captureDevice = device;
			break;
		}
	}
	
	return captureDevice;
}

#pragma mark UI

- (void)runStillImageCaptureAnimation
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[[[self previewView] layer] setOpacity:0.0];
		[UIView animateWithDuration:.25 animations:^{
			[[[self previewView] layer] setOpacity:1.0];
		}];
	});
}

- (void)checkDeviceAuthorizationStatus
{
	NSString *mediaType = AVMediaTypeVideo;
	
	[AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
		if (granted)
		{
			//Granted access to mediaType
			[self setDeviceAuthorized:YES];
		}
		else
		{
			//Not granted access to mediaType
			dispatch_async(dispatch_get_main_queue(), ^{
				[[[UIAlertView alloc] initWithTitle:@"AVCam!"
											message:@"AVCam doesn't have permission to use Camera, please change privacy settings"
										   delegate:self
								  cancelButtonTitle:@"OK"
								  otherButtonTitles:nil] show];
				[self setDeviceAuthorized:NO];
			});
		}
	}];
}

@end



