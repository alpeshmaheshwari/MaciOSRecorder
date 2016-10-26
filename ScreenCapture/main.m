//
//  main.m
//  ScreenCapture
//
//  Created by Kobiton DevOps on 10/12/16.
//  Copyright © 2016 Kobiton DevOps. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ScreenCapture.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
        NSString *udid = [standardDefaults stringForKey:@"-udid"];
        NSInteger socketPort = [standardDefaults integerForKey:@"-socket-port"];
        if (!udid || socketPort < 0) {
            printf("Usage: %s [--udid <udid>] [--socket-port <port>]\n", argv[0]);
            return 1;
        }
        
        [[[[ScreenCapture alloc] init]
            setUdid:udid andPort:(int)socketPort]
            initialize];
    }
    
    return 0;
}
