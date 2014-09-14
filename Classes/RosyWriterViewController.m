
/*
     File: RosyWriterViewController.m
 Abstract: View controller for camera interface
  Version: 2.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 
 */

#import "RosyWriterViewController.h"

#import <QuartzCore/QuartzCore.h>
#import "RosyWriterCapturePipeline.h"
#import "OpenGLPixelBufferView.h"

@interface RosyWriterViewController () <RosyWriterCapturePipelineDelegate>
{
	BOOL _addedObservers;
	BOOL _recording;
	UIBackgroundTaskIdentifier _backgroundRecordingID;
	BOOL _allowedToUseGPU;
}

@property(nonatomic, retain) IBOutlet UIBarButtonItem *recordButton;
@property(nonatomic, retain) IBOutlet UILabel *framerateLabel;
@property(nonatomic, retain) IBOutlet UILabel *dimensionsLabel;
@property(nonatomic, retain) NSTimer *labelTimer;
@property(nonatomic, retain) OpenGLPixelBufferView *previewView;
@property(nonatomic, retain) RosyWriterCapturePipeline *capturePipeline;
@property(nonatomic, retain) UIView * transmitter;
@property(nonatomic, retain) UIButton * btn;
@property(nonatomic, retain) UIButton * mainMenuBtn;
@property(nonatomic, retain) UIView * menu;
@property(nonatomic, retain) UIButton * sendBtn;
@property(nonatomic, retain) UIButton * receiveBtn;
@property(nonatomic, retain) UIButton * mainMenuRecvrBtn;
@end

@implementation RosyWriterViewController {
    NSArray * colorsToDisplay;
    int currentColorIndex;
    int fps;
    int transmitState;
}


- (void)dealloc
{
	if (_addedObservers) {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:[UIDevice currentDevice]];
		[[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
	}

	[_recordButton release];
	[_framerateLabel release];
	[_dimensionsLabel release];
	[_labelTimer release];
	[_previewView release];
	[_capturePipeline release];
    
    [super dealloc];
}

#pragma mark - View lifecycle

- (void)applicationDidEnterBackground
{
	// Avoid using the GPU in the background
	_allowedToUseGPU = NO;
	[self.capturePipeline setRenderingEnabled:NO];

	[self.capturePipeline stopRecording]; // no-op if we aren't recording
	
	 // We reset the OpenGLPixelBufferView to ensure all resources have been clear when going to the background.
	[self.previewView reset];
}

- (void)applicationWillEnterForeground
{
	_allowedToUseGPU = YES;
	[self.capturePipeline setRenderingEnabled:YES];
}

- (void)viewDidLoad
{
    currentColorIndex = -1;
    colorsToDisplay = nil;
    self.capturePipeline = [[[RosyWriterCapturePipeline alloc] initWithViewController:self] autorelease];
    [self.capturePipeline setDelegate:self callbackQueue:dispatch_get_main_queue()];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(applicationDidEnterBackground)
												 name:UIApplicationDidEnterBackgroundNotification
											   object:[UIApplication sharedApplication]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(applicationWillEnterForeground)
												 name:UIApplicationWillEnterForegroundNotification
											   object:[UIApplication sharedApplication]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(deviceOrientationDidChange)
												 name:UIDeviceOrientationDidChangeNotification
											   object:[UIDevice currentDevice]];
	
    // Keep track of changes to the device orientation so we can update the capture pipeline
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
	
	_addedObservers = YES;
	
	// the willEnterForeground and didEnterBackground notifications are subsequently used to update _allowedToUseGPU
	_allowedToUseGPU = ( [[UIApplication sharedApplication] applicationState] != UIApplicationStateBackground );
	[self.capturePipeline setRenderingEnabled:_allowedToUseGPU];
	
    [super viewDidLoad];
}

- (void) receiveBtnPressed:(id) sender {
    [self showReceiver];
}

- (void) sendBtnPressed:(id) sender {
    [self showTransmitter];
    [self.transmitter setHidden:NO];
    [self.view bringSubviewToFront:self.transmitter];
}

- (void) showReceiver {
    [self.mainMenuRecvrBtn setHidden:NO];
    [self.menu setHidden:YES];
    [self.transmitter setHidden:YES];
}

- (void)viewWillAppear:(BOOL)animated
{
    fps = -1;
    transmitState = -1;
    
	[super viewWillAppear:animated];
    self.transmitter = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.menu = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    int height = [UIScreen mainScreen].bounds.size.height;
    UILabel * title = [[UILabel alloc] initWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width/2 - 105, height/2 - 150, 300, 90)];
    [title setFont:[UIFont fontWithName:@"Helvetica" size:95.0f]];
    [title setText:@"Flare"];
    const int width = 100;
    
    self.sendBtn = [[UIButton alloc] initWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width/2 - 130/2, height/2 - 40, 130, 60)];
    self.sendBtn.layer.cornerRadius = 4;
    self.sendBtn.titleLabel.font = [UIFont fontWithName:@"Helvetica" size:30.0f];
    self.sendBtn.layer.borderColor = [[UIColor colorWithRed:0.9254 green:0.9411 blue:0.9450 alpha:1.0] CGColor];
    self.sendBtn.layer.borderWidth = 1;
    self.sendBtn.clipsToBounds = YES;
    [self.sendBtn addTarget:self action:@selector(sendBtnPressed:) forControlEvents:UIControlEventAllEvents];
    [self.sendBtn setTitle:@"Send" forState:UIControlStateNormal];
    [self.menu addSubview:self.sendBtn];
    
    self.receiveBtn = [[UIButton alloc] initWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width/2 - 130/2, height/2 + 40, 130, 60)];
    self.receiveBtn.layer.cornerRadius = 4;
    self.receiveBtn.titleLabel.font = [UIFont fontWithName:@"Helvetica" size:30.0f];
    self.receiveBtn.layer.borderColor = [[UIColor colorWithRed:0.9254 green:0.9411 blue:0.9450 alpha:1.0] CGColor];
    self.receiveBtn.layer.borderWidth = 1;
    self.receiveBtn.clipsToBounds = YES;
    [self.receiveBtn addTarget:self action:@selector(receiveBtnPressed:) forControlEvents:UIControlEventAllEvents];
    [self.receiveBtn setTitle:@"Receive" forState:UIControlStateNormal];
    [self.menu addSubview:self.receiveBtn];

    [self.menu setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:1]];
    [self.view addSubview:self.menu];
    [self.view bringSubviewToFront:self.menu];
    [self.menu addSubview:title];
    [title setTextColor:[UIColor colorWithRed:0.9254 green:0.9411 blue:0.9450 alpha:1.0]];
    

    self.mainMenuBtn = [[UIButton alloc] initWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width/2 - width/2, [UIScreen mainScreen].bounds.size.height - 45, width, 30)];
    self.mainMenuBtn.layer.cornerRadius = 4;
    self.mainMenuBtn.layer.borderColor = [[UIColor colorWithRed:0.9254 green:0.9411 blue:0.9450 alpha:1.0] CGColor];
    self.mainMenuBtn.layer.borderWidth = 1;
    self.mainMenuBtn.clipsToBounds = YES;

    [self.mainMenuBtn addTarget:self action:@selector(menuBtnPressed:) forControlEvents:UIControlEventAllEvents];
    [self.mainMenuBtn setTitle:@"Home" forState:UIControlStateNormal];
    [self.transmitter addSubview:self.mainMenuBtn];
    //
    
    self.mainMenuRecvrBtn = [[UIButton alloc] initWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width/2 - width/2, [UIScreen mainScreen].bounds.size.height - 45, width, 30)];
    self.mainMenuRecvrBtn.layer.cornerRadius = 4;
    self.mainMenuRecvrBtn.layer.borderColor = [[UIColor colorWithRed:0.9254 green:0.9411 blue:0.9450 alpha:1.0] CGColor];
    self.mainMenuRecvrBtn.layer.borderWidth = 1;
    self.mainMenuRecvrBtn.clipsToBounds = YES;
    [self.mainMenuRecvrBtn setHidden:YES];

    [self.mainMenuRecvrBtn addTarget:self action:@selector(menuBtnPressed:) forControlEvents:UIControlEventAllEvents];
    [self.mainMenuRecvrBtn setTitle:@"Home" forState:UIControlStateNormal];
    [self.view addSubview:self.mainMenuRecvrBtn];

    
    //
    
    self.btn = [[UIButton alloc] initWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width/2 - width/2, [UIScreen mainScreen].bounds.size.height - 90, width, 30)];
    self.btn.layer.cornerRadius = 4;
    self.btn.layer.borderColor = [[UIColor colorWithRed:0.9254 green:0.9411 blue:0.9450 alpha:1.0] CGColor];
    self.btn.layer.borderWidth = 1;
    self.btn.clipsToBounds = YES;

//    [btn setBackgroundColor:[UIColor colorWithRed:1 green:0 blue:0 alpha:1]];
//    [btn addTarget:self action:@selector(btnPressed)
    [self.btn addTarget:self action:@selector(btnPressed:) forControlEvents:UIControlEventAllEvents];
    [self.btn setTitle:@"Set data" forState:UIControlStateNormal];
    [self.transmitter addSubview:self.btn];

    [self showTransmitter];
    [self.view addSubview:self.transmitter];


    [[self recordButton] setTitle:@"Begin capture"];
	
	[self.capturePipeline startRunning];
	
	self.labelTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateLabels) userInfo:nil repeats:YES];
    [self.transmitter setHidden:YES];
}

- (void) btnPressed: (id) sender {
    
    if (transmitState == 0) {
        [((UIButton*) sender) setHidden:YES];
        transmitState = 1;
        [((UIButton*) sender) setTitle:@"Set data" forState:UIControlStateNormal];
    } else if (transmitState == -1) {
        [((UIButton*) sender) setTitle:@"Transmit" forState:UIControlStateNormal];
        transmitState = 3;
        [self showTransmitterAlert];
    }
}

- (void) menuBtnPressed: (id) sender {
    [self.mainMenuRecvrBtn setHidden:YES];
    [self.transmitter setHidden:YES];
    [self.menu setHidden:NO];
}

-(NSString *)toBinary:(NSInteger)input
{
    if (input == 1 || input == 0) {
        return [NSString stringWithFormat:@"%ld", (long)input];
    }
    else {
        return [NSString stringWithFormat:@"%@%ld", [self toBinary:input / 2], input % 2];
    }
}

- (void) showTransmitter {
    [self.view bringSubviewToFront:self.transmitter];
    [self.transmitter setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:1]];
}

- (void) showTransmitterAlert {
    if (transmitState == -1 || transmitState == 3) {
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Transmitter" message:@"Enter a string" delegate:self cancelButtonTitle:@"Done" otherButtonTitles:nil];
        alert.alertViewStyle = UIAlertViewStylePlainTextInput;
        [alert show];
        [alert release];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (!self.transmitter.isHidden) {
        NSString * text = [alertView textFieldAtIndex:0].text;
        const int fFPS = 15;
        fps = fFPS;
        transmitState = 0;
        NSArray * arr = [self makeSequence:text];
        [self setTransmitterAnimation:fFPS withSequence:arr];
    }
}

- (NSArray *) makeSequence:(NSString *) str {
    NSString * base64Table = @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    NSData * data = [str dataUsingEncoding:NSUTF8StringEncoding];
    NSString * base64Encoded = [data base64EncodedStringWithOptions:0];
    NSMutableArray * nums = [[NSMutableArray alloc] init];
    
    while ([[base64Encoded substringWithRange:NSMakeRange(base64Encoded.length - 1, 1)] isEqualToString:@"="]) {
        base64Encoded = [base64Encoded substringWithRange:NSMakeRange(0, base64Encoded.length - 1)];
    }
    
    for (int i = 0; i < base64Encoded.length; i++) {
        NSString * indChar = [base64Encoded substringWithRange:NSMakeRange(i, 1)];
        NSInteger loc = [base64Table rangeOfString:indChar].location;
        NSString * strLoc = [self toBinary:loc];
        if (strLoc.length > 6) {
            strLoc = [strLoc substringWithRange:NSMakeRange(0, 6)];
        } else if (strLoc.length < 6) {
            while (strLoc.length < 6) {
                strLoc = [NSString stringWithFormat:@"0%@", strLoc];
            }
        }
        
        const int minVal = 138;
        const int maxVal = 255;

        NSNumber * r1 = [NSNumber numberWithInt:[[strLoc substringWithRange:NSMakeRange(0, 1)] intValue] == 0 ? minVal : maxVal];
        NSNumber * g1 = [NSNumber numberWithInt:[[strLoc substringWithRange:NSMakeRange(1, 1)] intValue] == 0 ? minVal : maxVal];
        NSNumber * b1 = [NSNumber numberWithInt:[[strLoc substringWithRange:NSMakeRange(2, 1)] intValue] == 0 ? minVal : maxVal];
        NSNumber * r2 = [NSNumber numberWithInt:[[strLoc substringWithRange:NSMakeRange(3, 1)] intValue] == 0 ? minVal : maxVal];
        NSNumber * g2 = [NSNumber numberWithInt:[[strLoc substringWithRange:NSMakeRange(4, 1)] intValue] == 0 ? minVal : maxVal];
        NSNumber * b2 = [NSNumber numberWithInt:[[strLoc substringWithRange:NSMakeRange(5, 1)] intValue] == 0 ? minVal : maxVal];
        
        [nums addObject:r1];
        [nums addObject:g1];
        [nums addObject:b1];
        [nums addObject:r2];
        [nums addObject:g2];
        [nums addObject:b2];
    }
    
    for (int i = 3; i < nums.count; i += 3) {
        if (i % 3 == 0) {
            if ([nums[i] intValue] == [nums[i - 3] intValue] && [nums[i + 1] intValue] == [nums[i - 3 + 1] intValue] && [nums[i + 2] intValue] == [nums[i - 3 + 2] intValue]) {
                nums[i] = [NSNumber numberWithInt:0];
                nums[i + 1] = [NSNumber numberWithInt:0];
                nums[i + 2] = [NSNumber numberWithInt:0];
            }
        }
    }

    NSNumber * lastR = nums[nums.count - 3];
    NSNumber * lastG = nums[nums.count - 2];
    NSNumber * lastB = nums[nums.count - 1];
    
    for (int i = 0; i < 1 * fps; i++) {
        [nums addObject:lastR];
        [nums addObject:lastG];
        [nums addObject:lastB];
    }
    
    [nums insertObject:[NSNumber numberWithInt:0] atIndex:0];
    [nums insertObject:[NSNumber numberWithInt:0] atIndex:0];
    [nums insertObject:[NSNumber numberWithInt:0] atIndex:0];
    return nums;
}

- (void) setTransmitterAnimation:(int) fps_ withSequence:(NSArray *) sequence {
    [[self capturePipeline] stopRecording];
    fps = fps_;
    colorsToDisplay = sequence;
    [NSTimer scheduledTimerWithTimeInterval:1.0/fps
                                     target:self
                                   selector:@selector(updateTransmitter:)
                                   userInfo:nil
                                    repeats:NO];
}

- (void) updateTransmitter:(id) sender {
    if (currentColorIndex == -1) {
        currentColorIndex = 0;
    }
    if (transmitState == 1) {
        self.transmitter.backgroundColor = [UIColor
            colorWithRed:[[colorsToDisplay objectAtIndex:currentColorIndex] intValue]/255.0
            green:[[colorsToDisplay objectAtIndex:currentColorIndex + 1] intValue]/255.0
            blue:[[colorsToDisplay objectAtIndex:currentColorIndex + 2] intValue]/255.0
            alpha:1];

        NSLog(@"%f, %f, %f",[[colorsToDisplay objectAtIndex:currentColorIndex] intValue]/255.0, [[colorsToDisplay objectAtIndex:currentColorIndex + 1] intValue]/255.0,[[colorsToDisplay objectAtIndex:currentColorIndex + 2] intValue]/255.0);
        currentColorIndex += 3;
    }
    if (currentColorIndex <= colorsToDisplay.count - 3) {
        [NSTimer scheduledTimerWithTimeInterval:(1.0/fps)
                                         target:self
                                       selector:@selector(updateTransmitter:)
                                       userInfo:nil
                                        repeats:NO];
    } else if (transmitState == 1) {
        self.transmitter.backgroundColor = [UIColor
                                            colorWithRed:0
                                            green:0
                                            blue:0
                                            alpha:1];
        [self.btn setHidden:NO];
        transmitState = -1;
        currentColorIndex = -1;
    }
}

- (void) hideTransmitter {
    fps = -1;
    [[self capturePipeline] startRecording];
}

- (void) buttonClicked:(id) btn {
    NSLog(@"!!!");
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	
	[self.labelTimer invalidate];
	self.labelTimer = nil;
	
	[self.capturePipeline stopRunning];
}

- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)prefersStatusBarHidden
{
	return YES;
}

#pragma mark - UI

- (IBAction)toggleRecording:(id)sender
{
    if ( _recording )
	{
        [self.capturePipeline stopRecording];
    }
    else
	{
		// Disable the idle timer while recording
		[UIApplication sharedApplication].idleTimerDisabled = YES;
		
		// Make sure we have time to finish saving the movie if the app is backgrounded during recording
//		if ( [[UIDevice currentDevice] isMultitaskingSupported] )
//			_backgroundRecordingID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{}];
		
//		[[self recordButton] setEnabled:NO]; // re-enabled once recording has finished starting
		[[self recordButton] setTitle:@"End capture"];
		
		[self.capturePipeline startRecording];
		
		_recording = YES;
	}
}

- (void) recordingStopped {
	_recording = NO;
	[[self recordButton] setEnabled:YES];
	[[self recordButton] setTitle:@"Begin capture"];
	[UIApplication sharedApplication].idleTimerDisabled = NO;
	
//	[[UIApplication sharedApplication] endBackgroundTask:_backgroundRecordingID];
//	_backgroundRecordingID = UIBackgroundTaskInvalid;
}

- (void)setupPreviewView
{
    // Set up GL view
    self.previewView = [[[OpenGLPixelBufferView alloc] initWithFrame:CGRectZero] autorelease];
	self.previewView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
	
	UIInterfaceOrientation currentInterfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    self.previewView.transform = [self.capturePipeline transformFromVideoBufferOrientationToOrientation:(AVCaptureVideoOrientation)currentInterfaceOrientation withAutoMirroring:YES]; // Front camera preview should be mirrored

    [self.view insertSubview:self.previewView atIndex:0];
    CGRect bounds = CGRectZero;
    bounds.size = [self.view convertRect:self.view.bounds toView:self.previewView].size;
    self.previewView.bounds = bounds;
    self.previewView.center = CGPointMake(self.view.bounds.size.width/2.0, self.view.bounds.size.height/2.0);	
}

- (void)deviceOrientationDidChange
{
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
	
	// Update recording orientation if device changes to portrait or landscape orientation (but not face up/down)
	if ( UIDeviceOrientationIsPortrait( deviceOrientation ) || UIDeviceOrientationIsLandscape( deviceOrientation ) ) {
        [self.capturePipeline setRecordingOrientation:(AVCaptureVideoOrientation)deviceOrientation];
	}
}

- (void)updateLabels
{	
	NSString *frameRateString = [NSString stringWithFormat:@"%d FPS", (int)roundf(self.capturePipeline.videoFrameRate)];
	[self.framerateLabel setText:frameRateString];
	
	NSString *dimensionsString = [NSString stringWithFormat:@"%d x %d", self.capturePipeline.videoDimensions.width, self.capturePipeline.videoDimensions.height];
	[self.dimensionsLabel setText:dimensionsString];
}

- (void)showError:(NSError *)error
{
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
														message:[error localizedFailureReason]
													   delegate:nil
											  cancelButtonTitle:@"OK"
											  otherButtonTitles:nil];
	[alertView show];
	[alertView release];
}

#pragma mark - RosyWriterCapturePipelineDelegate

- (void)capturePipeline:(RosyWriterCapturePipeline *)capturePipeline didStopRunningWithError:(NSError *)error
{
	[self showError:error];
	
	[[self recordButton] setEnabled:NO];
}

// Preview
- (void)capturePipeline:(RosyWriterCapturePipeline *)capturePipeline previewPixelBufferReadyForDisplay:(CVPixelBufferRef)previewPixelBuffer
{
	if ( ! _allowedToUseGPU ) {
		return;
	}
	
	if ( ! self.previewView ) {
		[self setupPreviewView];
	}
	
	[self.previewView displayPixelBuffer:previewPixelBuffer];
}

- (void)capturePipelineDidRunOutOfPreviewBuffers:(RosyWriterCapturePipeline *)capturePipeline
{
	if ( _allowedToUseGPU ) {
		[self.previewView flushPixelBufferCache];
	}
}

// Recording
- (void)capturePipelineRecordingDidStart:(RosyWriterCapturePipeline *)capturePipeline
{
	[[self recordButton] setEnabled:YES];
}

- (void)capturePipelineRecordingWillStop:(RosyWriterCapturePipeline *)capturePipeline
{
	// Disable record button until we are ready to start another recording
	[[self recordButton] setEnabled:NO];
	[[self recordButton] setTitle:@"Begin capture"];
}

- (void)capturePipelineRecordingDidStop:(RosyWriterCapturePipeline *)capturePipeline
{
	[self recordingStopped];
}

- (void)capturePipeline:(RosyWriterCapturePipeline *)capturePipeline recordingDidFailWithError:(NSError *)error
{
	[self recordingStopped];
	[self showError:error];
}

@end
