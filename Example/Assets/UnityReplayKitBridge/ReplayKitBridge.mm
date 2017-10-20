//
//  ReplayKitBridge.mm
//  Unity-iPhone
//
//  Created by Chase Farmer on 10/18/17.
//
//

#import <Foundation/Foundation.h>
#import <ReplayKit/ReplayKit.h>

const char *kCallbackTarget = "ReplayKitBridge";
#define documentsDirectory [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]
#define SUBVIEW_TAG 4200

@interface ReplayKitBridge : NSObject <RPScreenRecorderDelegate, RPPreviewViewControllerDelegate>

@property (strong, nonatomic) RPPreviewViewController *previewViewController;
@property (nonatomic, readonly) RPScreenRecorder *screenRecorder;
@property (nonatomic, readonly) BOOL screenRecorderAvailable;
@property (nonatomic, readonly) BOOL recording;
@property (nonatomic) BOOL cameraEnabled;
@property (nonatomic) BOOL microphoneEnabled;
@property (strong, nonatomic) NSString *videoOutPath;
@property (strong, nonatomic) AVAssetWriter *assetWriter;
@property (strong, nonatomic) AVAssetWriterInput *assetWriterVideoInput;
@property (strong, nonatomic) AVAssetWriterInput *assetWriterAudioInput;
@property (strong, nonatomic) UIWindow *overlayWindow;
@property (nonatomic) BOOL avPermissionsGranted;

@end

@implementation ReplayKitBridge

static ReplayKitBridge *_sharedInstance = nil;
+ (ReplayKitBridge *)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [ReplayKitBridge new];
        [RPScreenRecorder sharedRecorder].delegate = _sharedInstance;
    });
    return _sharedInstance;
}

- (RPScreenRecorder *)screenRecorder {
    return [RPScreenRecorder sharedRecorder];
}

#pragma mark - Screen recording

- (void) setupOverlayWindow {
    CGRect frame = CGRectMake(0, 0, 50, 50);
    _overlayWindow = [[UIWindow alloc] initWithFrame:frame];
    _overlayWindow.backgroundColor =  [UIColor clearColor];
    
    UIView *controlsView = [[UIView alloc] initWithFrame:_overlayWindow.bounds];
    [_overlayWindow addSubview:controlsView];
    
    UIButton *but=[UIButton buttonWithType:UIButtonTypeRoundedRect];
    but.frame= CGRectMake(0, 0, 50, 50);
    [but setTitle:@"Stop Recording" forState:UIControlStateNormal];
    [but addTarget:self action:@selector(recordingButtonCallback) forControlEvents:UIControlEventTouchUpInside];
    [controlsView addSubview:but];
    
    [_overlayWindow addSubview:controlsView];
    [_overlayWindow setTag:SUBVIEW_TAG];
    [_overlayWindow makeKeyAndVisible];
}

- (void) recordingButtonCallback {
    [self stopRecording];
    UIView * subview = [_overlayWindow viewWithTag:SUBVIEW_TAG];
    [subview removeFromSuperview];
    _overlayWindow.hidden = YES;
}

- (void)addCameraPreviewView {
    if ([self.screenRecorder respondsToSelector:@selector(cameraPreviewView)]) {
        UIView *cameraPreviewView = self.screenRecorder.cameraPreviewView;
        if (cameraPreviewView) {
            UIViewController *rootViewController = UnityGetGLViewController();
            [rootViewController.view addSubview:cameraPreviewView];
        }
    }
}

- (void)removeCameraPreviewView {
    if ([self.screenRecorder respondsToSelector:@selector(cameraPreviewView)]) {
        UIView *cameraPreviewView = self.screenRecorder.cameraPreviewView;
        if (cameraPreviewView) {
            [cameraPreviewView removeFromSuperview];
        }
    }
}

- (void)setupVideoWriter {
    NSDictionary *compressionProperties = @{AVVideoProfileLevelKey         : AVVideoProfileLevelH264HighAutoLevel,
                                            AVVideoH264EntropyModeKey      : AVVideoH264EntropyModeCABAC,
                                            AVVideoAverageBitRateKey       : @(1920 * 1080 * 11.4),
                                            AVVideoMaxKeyFrameIntervalKey  : @60,
                                            AVVideoAllowFrameReorderingKey : @NO};
    
    NSDictionary *videoSettings = @{AVVideoCompressionPropertiesKey : compressionProperties,
                                    AVVideoCodecKey                 : AVVideoCodecTypeH264,
                                    AVVideoWidthKey                 : @1080,
                                    AVVideoHeightKey                : @1920};
    
    
    //Video Input
    self.assetWriterVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    [self.assetWriter addInput:self.assetWriterVideoInput];
    [self.assetWriterVideoInput setMediaTimeScale:60];
    [self.assetWriter setMovieTimeScale:60];
    [self.assetWriterVideoInput setExpectsMediaDataInRealTime:YES];
}

- (void)setupAudioWriter {
    bool canAddAudioWriter = false;
    
    //Audio Input Settings
    NSMutableDictionary* audioSettings = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                          [NSNumber numberWithInt:kAudioFormatMPEG4AAC], AVFormatIDKey,
                                          [NSNumber numberWithFloat: 44100.0], AVSampleRateKey,
                                          [NSNumber numberWithFloat: 64000], AVEncoderBitRateKey,
                                          [NSNumber numberWithUnsignedInteger:1], AVNumberOfChannelsKey,
                                          nil];
    
    //Audio Input
    self.assetWriterAudioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
    canAddAudioWriter = [self.assetWriter canAddInput:self.assetWriterAudioInput];
    
    if (canAddAudioWriter)
    {
        self.assetWriterAudioInput.expectsMediaDataInRealTime = YES; //true;
        [self.assetWriter addInput:self.assetWriterAudioInput];
    }
}

- (void) setupFileWriter {
    NSError *error = nil;
    self.videoOutPath = [[documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%u", arc4random() % 1000]] stringByAppendingPathExtension:@"mp4"];
    NSLog(@"Video %@", self.videoOutPath);
    
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:self.videoOutPath ];
    if(fileExists) {
        if (![[NSFileManager defaultManager] removeItemAtPath:self.videoOutPath error:&error])   //Delete it
        {
            NSLog(@"Delete file error: %@", error);
        }
    }
    
    self.assetWriter = [AVAssetWriter assetWriterWithURL:[NSURL fileURLWithPath:self.videoOutPath] fileType:AVFileTypeMPEG4 error:&error];
}

- (void)startRecording {
    //    __typeof__(self) __weak weakSelf = self;
    //    void (^handler)(NSError * _Nullable) = ^(NSError * _Nullable error){
    //        // [weakSelf addCameraPreviewView];
    //        UnitySendMessage(kCallbackTarget, "OnStartRecording", "");
    //    };
    
    
    
    [self setupFileWriter];
    [self setupVideoWriter];
    [self setupAudioWriter];
    [self setupOverlayWindow];
    
    [[RPScreenRecorder sharedRecorder] setMicrophoneEnabled:YES];
    
    [self requestAVPermissions];
}

- (void)requestAVPermissions {
    if(!self.avPermissionsGranted) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (granted)
                {
                    [self replayCaptureMicAndVideo];
                }
            });
        }];
    }
    else {
        NSLog(@"Permmisions Failure AV!");
    }
}

- (void)replayCaptureMicAndVideo {
    [self.screenRecorder startCaptureWithHandler:^(CMSampleBufferRef  _Nonnull sampleBuffer, RPSampleBufferType bufferType, NSError * _Nullable error) {
        if (self.assetWriter.status == AVAssetWriterStatusUnknown) {
            @try {
                [self.assetWriter startWriting];
                [self.assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
            }
            @catch(NSException *expection) {
                NSLog(@"Status FAILS!: %i", (int)self.assetWriter.status);
            }
        }
        
        if(self.assetWriter == nil) {
            return;
        }
        
        if (CMSampleBufferDataIsReady(sampleBuffer)) {
            
            if (self.assetWriter.status == AVAssetWriterStatusFailed) {
                NSLog(@"An error occured.");
                NSLog(@"Error %@", self.assetWriter.error);
                return;
            }
            
            if(self.assetWriter.status == AVAssetWriterStatusWriting) {
                if (bufferType == RPSampleBufferTypeVideo) {
                    if (self.assetWriterVideoInput.isReadyForMoreMediaData) {
                        [self.assetWriterVideoInput appendSampleBuffer:sampleBuffer];
                    }
                }
                
                if (bufferType == RPSampleBufferTypeAudioMic) {
                    if (self.assetWriterAudioInput.isReadyForMoreMediaData) {
                        [self.assetWriterAudioInput appendSampleBuffer:sampleBuffer];
                    }
                }
            }
            
        }
    } completionHandler:^(NSError * _Nullable error) {
        if (!error) {
            NSLog(@"Recording started successfully.");
        }
    }];
}

- (void)cancelRecording {
    [self.screenRecorder stopCaptureWithHandler:^(NSError * _Nullable error) {
        if (!error) {
            NSLog(@"Recording stopped successfully. Cleaning up...");
            [self.assetWriter finishWritingWithCompletionHandler:^{
                self.assetWriterVideoInput = nil;
                self.assetWriterAudioInput = nil;
                self.assetWriter = nil;
            }];
        }
    }];
}

- (void)stopRecording {
    [self.screenRecorder stopCaptureWithHandler:^(NSError * _Nullable error) {
        if (!error) {
            NSLog(@"Recording stopped successfully. Cleaning up...");
            UnitySendMessage(kCallbackTarget, "OnStopRecording", "");
            [self.assetWriter finishWritingWithCompletionHandler:^{
                UISaveVideoAtPathToSavedPhotosAlbum(self.videoOutPath, nil, nil, nil);
                self.assetWriterVideoInput = nil;
                self.assetWriterAudioInput = nil;
                self.assetWriter = nil;
            }];
        }
    }];
}

- (BOOL)presentPreviewView {
    if (self.previewViewController) {
        UIViewController *rootViewController = UnityGetGLViewController();
        [rootViewController presentViewController:self.previewViewController animated:YES completion:nil];
        return YES;
    }
    
    return NO;
}

- (void)dismissPreviewView {
    if (self.previewViewController) {
        [self.previewViewController dismissViewControllerAnimated:YES completion:^{
            self.previewViewController = nil;
        }];
    }
}

- (BOOL)isScreenRecorderAvailable {
    return self.screenRecorder.available;
}

- (BOOL)isRecording {
    return self.screenRecorder.recording;
}

- (BOOL)isCameraEnabled {
    if ([self.screenRecorder respondsToSelector:@selector(isCameraEnabled)]) {
        // iOS 10 or later
        return self.screenRecorder.cameraEnabled;
    }
}

- (void)setCameraEnabled:(BOOL)cameraEnabled {
    if ([self.screenRecorder respondsToSelector:@selector(setCameraEnabled:)]) {
        // iOS 10 or later
        self.screenRecorder.cameraEnabled = cameraEnabled;
    }
}

- (BOOL)isMicrophoneEnabled {
    if ([self.screenRecorder respondsToSelector:@selector(isMicrophoneEnabled)]) {
        // iOS 10 or later
        return self.screenRecorder.microphoneEnabled;
    }
}

- (void)setMicrophoneEnabled:(BOOL)microphoneEnabled {
    if ([self.screenRecorder respondsToSelector:@selector(setMicrophoneEnabled:)]) {
        // iOS 10 or later
        self.screenRecorder.microphoneEnabled = microphoneEnabled;
        return;
    }
}

#pragma mark - RPScreenRecorderDelegate

- (void)screenRecorderDidChangeAvailability:(RPScreenRecorder *)screenRecorder {
}

- (void)screenRecorder:(RPScreenRecorder *)screenRecorder didStopRecordingWithError:(NSError *)error previewViewController:(RPPreviewViewController *)previewViewController {
    [self removeCameraPreviewView];
    
    self.previewViewController = previewViewController;
    self.previewViewController.previewControllerDelegate = self;
    
    UnitySendMessage(kCallbackTarget, "OnStopRecordingWithError", error.description.UTF8String);
}

#pragma mark - RPPreviewControllerDelegate

- (void)previewControllerDidFinish:(RPPreviewViewController *)previewController {
    UnitySendMessage(kCallbackTarget, "OnFinishPreview", "");
}

- (void)previewController:(RPPreviewViewController *)previewController didFinishWithActivityTypes:(NSSet<NSString *> *)activityTypes {
    for (NSString *activityType in activityTypes) {
        UnitySendMessage(kCallbackTarget, "OnFinishPreview", activityType.UTF8String);
    }
}

@end

#pragma mark - C interface

extern "C" {
    void _rp_startRecording() {
        [[ReplayKitBridge sharedInstance] startRecording];
    }
    
    void _rp_cancelRecording() {
        [[ReplayKitBridge sharedInstance] cancelRecording];
    }
    
    void _rp_stopRecording() {
        [[ReplayKitBridge sharedInstance] stopRecording];
    }
    
    BOOL _rp_presentPreviewView() {
        return [[ReplayKitBridge sharedInstance] presentPreviewView];
    }
    
    void _rp_dismissPreviewView() {
        [[ReplayKitBridge sharedInstance] dismissPreviewView];
    }
    
    BOOL _rp_isScreenRecorderAvailable() {
        return [[ReplayKitBridge sharedInstance] isScreenRecorderAvailable];
    }
    
    BOOL _rp_isRecording() {
        return [[ReplayKitBridge sharedInstance] isRecording];
    }
    
    BOOL _rp_isCameraEnabled() {
        return [[ReplayKitBridge sharedInstance] isCameraEnabled];
    }
    
    void _rp_setCameraEnabled(BOOL cameraEnabled) {
        [[ReplayKitBridge sharedInstance] setCameraEnabled:cameraEnabled];
    }
    
    BOOL _rp_isMicrophoneEnabled() {
        return [[ReplayKitBridge sharedInstance] isMicrophoneEnabled];
    }
    
    void _rp_setMicrophoneEnabled(BOOL microphoneEnabled) {
        [[ReplayKitBridge sharedInstance] setMicrophoneEnabled:microphoneEnabled];
    }
}


