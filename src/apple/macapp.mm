#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#include "al2o3_platform/platform.h"
#include "al2o3_os/filesystem.hpp"
#include "utils_gameappshell/gameappshell.h"
#include "utils_gameappshell/apple/platform.h"
#include "al2o3_os/time.h"
#include "macapp.hpp"

#define APP_ABORT if (gGameAppShell.onAbortCallback) { \
                    gGameAppShell.onAbortCallback(); \
                  } else { \
                    abort(); \
                  }
#define APP_CALLBACK_RET(x) ((gGameAppShell.x) ?  gGameAppShell.x() : true)
#define APP_CALLBACK(x) if(gGameAppShell.x) { gGameAppShell.x(); }

namespace {

GameAppShell_Shell gGameAppShell = {};
GameAppShellBasic_AppleWindow gMainWindow = {};

}

AL2O3_EXTERN_C GameAppShell_Shell *GameAppShell_Init() {
	return &gGameAppShell;
}

AL2O3_EXTERN_C void GameAppShell_MainLoop(int argc, char const *argv[]) {

	Os::FileSystem::SetCurrentDir(Os::FileSystem::GetExePath());
	memcpy(&gMainWindow.desc, &gGameAppShell.initialWindowDesc, sizeof(GameAppShell_WindowDesc));

	if (gGameAppShell.initialWindowDesc.width == -1 ||
			gGameAppShell.initialWindowDesc.height == -1) {
		gMainWindow.desc.width = 1920;
		gMainWindow.desc.height = 1080;
	}

	[NSApplication sharedApplication];

	id appName;
	if (gGameAppShell.initialWindowDesc.name == NULL) {
		appName = [[NSProcessInfo processInfo] processName];
	} else {
		appName = [NSString stringWithUTF8String:gGameAppShell.initialWindowDesc.name];
	}
	[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
	id menubar = [[NSMenu alloc] initWithTitle:appName];
	id appMenuItem = [[NSMenuItem alloc] initWithTitle:appName action:NULL keyEquivalent:@""];
	[menubar addItem:appMenuItem];
	[NSApp setMainMenu:menubar];

	id appMenu = [[NSMenu alloc] initWithTitle:appName];
	id quitTitle = [@"Quit " stringByAppendingString:appName];
	id quitMenuItem = [[NSMenuItem alloc] initWithTitle:quitTitle
																							 action:@selector(terminate:) keyEquivalent:@"q"];
	[appMenu addItem:quitMenuItem];
	[appMenuItem setSubmenu:appMenu];

	NSRect frame = NSMakeRect(0, 0, gMainWindow.desc.width, gMainWindow.desc.height);

	NSWindow *window =
			[[NSWindow alloc]
					initWithContentRect:frame
										styleMask:(NSWindowStyleMask) ( //NSWindowStyleMaskFullSizeContentView |
												NSWindowStyleMaskTitled |
												NSWindowStyleMaskResizable |
												NSWindowStyleMaskClosable |
												NSWindowStyleMaskMiniaturizable)
											backing:NSBackingStoreBuffered
												defer:YES];
	[window center];
	[window setTitle:appName];

	GameViewController *gvc = [[GameViewController alloc] init];
	[window setContentViewController:gvc];

	[window makeKeyAndOrderFront:nil];
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp setDelegate:gvc];
	[NSApp run];
}

/************************************************************************/
// GameViewController implementation
/************************************************************************/

@implementation GameViewController {
}

- (void)loadView {
	// Set the view to use the default device
	id device = MTLCreateSystemDefaultDevice();

	NSRect frame = NSMakeRect(0, 0, gMainWindow.desc.width, gMainWindow.desc.height);
	MTKView *_view = [[MTKView alloc] initWithFrame:frame device:device];
	_view.delegate = self;
	gMainWindow.desc.width = _view.drawableSize.width;
	gMainWindow.desc.height = _view.drawableSize.height;

	self.view = _view;
	gMainWindow.metalView = _view;

	_view.paused = NO;
	_view.enableSetNeedsDisplay = NO;
	_view.preferredFramesPerSecond = 60;
	_view.translatesAutoresizingMaskIntoConstraints = NO;
	_view.autoresizesSubviews = YES;
	_view.clearColor = MTLClearColorMake(0, 0, 0, 1);
	_view.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
}

- (BOOL)acceptsFirstResponder {
	return TRUE;
}

// Called whenever view changes orientation or layout is changed
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {

	float const newWidth = (float) size.width;
	float const newHeight = (float) size.height;

	if (newWidth != gMainWindow.desc.width ||
			newHeight != gMainWindow.desc.height) {

		gMainWindow.desc.width = (uint32_t) newWidth;
		gMainWindow.desc.height = (uint32_t) newHeight;

		APP_CALLBACK(onDisplayResizeCallback);
	}

}

// Called whenever the view needs to render
- (void)drawInMTKView:(nonnull MTKView *)view {
	@autoreleasepool {
		//this is needed for NON Vsync mode.
		//This enables to force update the display
		if (view.enableSetNeedsDisplay == YES) {
			[view setNeedsDisplay:YES];
		}

		static double lastTimeMs = (double) Os_GetSystemTime();
		double deltaTimeMS = Os_GetSystemTime() - lastTimeMs;
		// if framerate appears to drop below about 6, assume we're at a breakpoint and simulate 20fps.
		if (deltaTimeMS > 0.15) {
			deltaTimeMS = 0.05;
		}

		if (gGameAppShell.perFrameUpdateCallback) {
			gGameAppShell.perFrameUpdateCallback(deltaTimeMS);
		}
		if (gGameAppShell.perFrameDrawCallback) {
			gGameAppShell.perFrameDrawCallback(deltaTimeMS);
		}

	}
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	LOGINFO("applicationDidFinishLaunching");
	@autoreleasepool {
		//if init fails then exit the app
		if (!APP_CALLBACK_RET(onInitCallback)) {
			for (NSWindow *window in [NSApplication sharedApplication].windows) {
				[window close];
			}
			APP_ABORT
		}

	}
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	LOGINFO("applicationWillTerminate");
	APP_CALLBACK(onQuitCallback)
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return YES;
}
- (void)applicationWillHide:(NSNotification *)notification {
	LOGINFO("applicationWillHide");

}

@end

// GameAppShell Window API
AL2O3_EXTERN_C void GameAppShell_WindowGetCurrentDesc(GameAppShell_WindowDesc *desc) {
	ASSERT(desc);

	memcpy(desc, &gMainWindow.desc, sizeof(GameAppShell_WindowDesc));
}

AL2O3_EXTERN_C void GameAppShell_Quit() {
	[[NSApplication sharedApplication] terminate:nil];
}

AL2O3_EXTERN_C void *GameAppShell_GetPlatformWindowPtr() {
	return (__bridge void *) [gMainWindow.metalView window];
}
