#pragma once
#ifndef WYRD_GUISHELL_MACAPP_HPP
#define WYRD_GUISHELL_MACAPP_HPP

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include <AppKit/NSOpenPanel.h>
#include "utils_gameappshell/windowdesc.h"

#include "utils_gameappshell/apple/platform.h"

#if defined(TARGET_IOS) || defined(TARGET_TVOS)
#import <UIKit.h>;
#define PlatformViewController UIViewController
#else
#import <AppKit/AppKit.h>
#define PlatformViewController NSViewController
#endif

@interface GameViewController : PlatformViewController<NSApplicationDelegate, MTKViewDelegate>
- (void)loadView;

@end

#endif //WYRD_GUISHELL_MACAPP_HPP
