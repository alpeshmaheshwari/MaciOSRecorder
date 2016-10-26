//
//  ScreenCapture.m
//  ScreenCapture
//
//  Created by Kobiton DevOps on 10/12/16.
//  Copyright © 2016 Kobiton DevOps. All rights reserved.
//

#import "ScreenCapture.h"


void EnableDALDevices() {
    CMIOObjectPropertyAddress prop = {
        kCMIOHardwarePropertyAllowScreenCaptureDevices,
        kCMIOObjectPropertyScopeGlobal,
        kCMIOObjectPropertyElementMaster
    };
    UInt32 allow = 1;
    CMIOObjectSetPropertyData(kCMIOObjectSystemObject,
                              &prop, 0, NULL,
                              sizeof(allow), &allow );
}

void start() {
    EnableDALDevices();
}

@interface ScreenCapture() {
    NSString *_udid;
    int _port;
    
    GCDAsyncSocket *_serverSocket;
    GCDAsyncSocket *_clientSocket;
    AVCaptureSession *_captureSession;
    AVCaptureDeviceInput *_inputDevice;
    AVCaptureStillImageOutput *_imageOutput;
    AVCaptureConnection *_videoConnection;
    bool accepted;
}
@end
@implementation ScreenCapture

- (instancetype)setUdid:(NSString *)udid andPort:(int)port {
    NSLog(@"Start running");
    _udid = udid;
    _port = port;
    return self;
}

- (void)initialize {
    NSLog(@"Initialize");
    start();
    accepted = false;
    _serverSocket = [self startServer];
    if (_serverSocket) {
    }
    else {
        NSLog(@"Error initialize");
    }
    NSNotificationCenter *notiCenter = [NSNotificationCenter defaultCenter];
    id connObs =[notiCenter addObserverForName:AVCaptureDeviceWasConnectedNotification
                                        object:nil
                                         queue:[NSOperationQueue mainQueue]
                                    usingBlock:^(NSNotification *note)
                 {
                     NSArray* devs = [AVCaptureDevice devices];
                     for(AVCaptureDevice* dev in devs) {
                         NSLog(@"Device found: 1 %@ 2 %@", [dev uniqueID], [dev modelID]);
                     }
                     // Device addition logic
                 }];
    id disconnObs =[notiCenter addObserverForName:AVCaptureDeviceWasDisconnectedNotification
                                           object:nil
                                            queue:[NSOperationQueue mainQueue]
                                       usingBlock:^(NSNotification *note)
                    {
                        NSArray* devs = [AVCaptureDevice devices];
                        for(AVCaptureDevice* dev in devs) {
                            NSLog(@"Device found: 1 %@ 2 %@", [dev uniqueID], [dev modelID]);
                        }
                        // Device removal logic
                    }];
    
    [[NSRunLoop currentRunLoop] run];
    [notiCenter removeObserver:connObs];
    [notiCenter removeObserver:disconnObs];
}

- (GCDAsyncSocket*)startServer {
    GCDAsyncSocket *socket = nil;
    GCDAsyncSocket *_socket = [[GCDAsyncSocket alloc]
                     initWithDelegate:self
                     delegateQueue:dispatch_queue_create("DelegateQueue", DISPATCH_QUEUE_SERIAL)];
    NSError *error;
    [_socket acceptOnPort:_port error:&error];
    if(error) {
        NSLog(@"Failed to listen on port: %d, error: %@", _port, error);
        return false;
    } else {
        socket = _socket;
    }
    NSLog(@"Socket started on port: %d", _port);
    return socket;
}

- (void)initRecordSession {
    BOOL found = false;
    AVCaptureDevice *device;
    NSArray* devs = [AVCaptureDevice devices];
    for(AVCaptureDevice* dev in devs) {
        NSLog(@"Device found: 1 %@ 2 %@", [dev uniqueID], [dev modelID]);
        if([[dev uniqueID] isEqualToString:_udid]) {
            device = dev;
            found = true;
        }
    }
    if(found) {
        NSLog(@"Found");
        NSError *err;
        _captureSession = [[AVCaptureSession alloc] init];
        _captureSession.sessionPreset = AVCaptureSessionPresetMedium;
    
        _inputDevice = [AVCaptureDeviceInput deviceInputWithDevice:device error:&err];
        [_captureSession addInput:_inputDevice];
        _imageOutput = [[AVCaptureStillImageOutput alloc] init];
        NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
        [_imageOutput setOutputSettings:outputSettings];
        [_captureSession addOutput:_imageOutput];
        [_captureSession startRunning];
        
        _videoConnection = nil;
        for (AVCaptureConnection *connection in _imageOutput.connections) {
            for (AVCaptureInputPort *port in [connection inputPorts]) {
                if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
                    _videoConnection = connection;
                    break;
                }
            }
            if (_videoConnection) { break; }
        }
        [self captureImage];
    }
}

- (void)captureImage {
    if(!accepted) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSTimer scheduledTimerWithTimeInterval:(1.0/5.0) target:self selector:@selector(captureImage) userInfo:nil repeats:NO];
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
    NSLog(@"About to request a capture from: %@", _videoConnection);
    [_imageOutput captureStillImageAsynchronouslyFromConnection:_videoConnection completionHandler: ^(CMSampleBufferRef imageSampleBuffer, NSError *error)
     {
         NSLog(@"Data collected");
         CFDictionaryRef exifAttachments = CMGetAttachment( imageSampleBuffer, kCGImagePropertyExifDictionary, NULL);
         if (exifAttachments)
         {
             // Do something with the attachments.
             NSLog(@"attachements: %@", exifAttachments);
         } else {
             NSLog(@"no attachments");
         }
         
         NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
         NSMutableData *data = [NSMutableData data];
         int length = (int)imageData.length;
         [data appendBytes:&length length:sizeof(length)];
         [data appendBytes:[imageData bytes] length:imageData.length];
         //if(_clientSocket) {
             NSLog(@"Send data to client: %@:%hu", [_clientSocket connectedHost], [_clientSocket connectedPort]);
             [_clientSocket writeData:data withTimeout:-1 tag:0];
         //}
     }];
    });
}

- (void)socket:(GCDAsyncSocket*)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    if(accepted) {
        NSLog(@"Accepted more new socket from %@:%hu", [newSocket connectedHost], [newSocket connectedPort]);
        return;
    }
    accepted = true;
    NSLog(@"Accepted new socket from %@:%hu", [newSocket connectedHost], [newSocket connectedPort]);
    _clientSocket = newSocket;
    NSLog(@"Client socket %@", _clientSocket);
    [self initRecordSession];
    [self captureImage];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    NSLog(@"socket closed from %@:%hu", [sock connectedHost], [sock connectedPort]);
    // _clientSocket = nil;
    [self stop];
    accepted = false;
}

- (void)stop {
    [_serverSocket setDelegate:nil];
    [_serverSocket disconnect];
    _serverSocket = nil;
    _clientSocket = nil;
}

@end
