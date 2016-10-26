//
//  ScreenCapture.h
//  ScreenCapture
//
//  Created by Kobiton DevOps on 10/12/16.
//  Copyright © 2016 Kobiton DevOps. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMediaIO/CMIOHardware.h>

@import CocoaAsyncSocket;

@interface ScreenCapture : NSObject

- (instancetype)setUdid:(NSString *)udid andPort:(int)port;
- (void)initialize;
- (GCDAsyncSocket*)startServer;
- (void)runLoop;
- (void)initRecordSession;
- (void)createServer;
- (void)stop;
- (void)captureImage;
@end
