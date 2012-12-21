//
//  AppDelegate.h
//  iOSVirtualCamera
//
//  Created by hayashi on 12/21/12.
//  Copyright (c) 2012 hayashi. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MainWindow : NSWindow
@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (assign) IBOutlet NSWindow *window;
@end
