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

AL2O3_EXTERN_C GameAppShell_Shell *GameAppShell_Init()
{
	return &gGameAppShell;
}

AL2O3_EXTERN_C int GameAppShell_MainLoop(int argc, char const *argv[]) {
	if(gGameAppShell.initialWindowDesc.name == NULL) {
		gGameAppShell.initialWindowDesc.name = "No name for al2o3 app specified";
	}

	return NSApplicationMain(argc, (char const**)argv);
}
/************************************************************************/
// GameViewController implementation
/************************************************************************/

@implementation GameViewController {
  MTKView *_view;
  id <MTLDevice> _device;
  MetalKitApplication *_application;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  // Set the view to use the default device
  _device = MTLCreateSystemDefaultDevice();
  _view = (MTKView *) self.view;
  _view.delegate = self;
  _view.device = _device;
  _view.paused = NO;
  _view.enableSetNeedsDisplay = NO;
  _view.preferredFramesPerSecond = 60;
  [_view.window makeFirstResponder:self];
  _view.autoresizesSubviews = YES;

  // Adjust window size to match retina scaling.
  gMainWindow.retinaScale[0] = (float) (_view.drawableSize.width / _view.frame.size.width);
  gMainWindow.retinaScale[1] = (float) (_view.drawableSize.height / _view.frame.size.height);

  NSSize windowSize = CGSizeMake(_view.frame.size.width / gMainWindow.retinaScale[0],
                                 _view.frame.size.height / gMainWindow.retinaScale[1]);
  [_view.window setContentSize:windowSize];
  [_view.window setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];

  if (!_device) {
    NSLog(@"Metal is not supported on this device");
    self.view = [[NSView alloc] initWithFrame:self.view.frame];
  }

  // Kick-off the MetalKitApplication.
  _application = [[MetalKitApplication alloc] initWithMetalDevice:_device
                                        renderDestinationProvider:self
                                                             view:_view];

  //register terminate callback
  NSApplication *app = [NSApplication sharedApplication];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(applicationWillTerminate:)
                                               name:NSApplicationWillTerminateNotification
                                             object:app];

	[self.view.window makeKeyWindow];
}

/*A notification named NSApplicationWillTerminateNotification.*/
- (void)applicationWillTerminate:(NSNotification *)notification {
  [_application shutdown];
}

- (BOOL)acceptsFirstResponder {
  return TRUE;
}

- (BOOL)canBecomeKeyView {
  return TRUE;
}

// Called whenever view changes orientation or layout is changed
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
  view.window.contentView = _view;
  [_application drawRectResized:view.bounds.size];
}

// Called whenever the view needs to render
- (void)drawInMTKView:(nonnull MTKView *)view {
  @autoreleasepool {
    [_application update];
    //this is needed for NON Vsync mode.
    //This enables to force update the display
    if (_view.enableSetNeedsDisplay == YES) {
      [_view setNeedsDisplay:YES];
    }
  }
}

@end

/************************************************************************/
// MetalKitApplication implementation
/************************************************************************/

// Metal application implementation.
@implementation MetalKitApplication {
}

- (nonnull instancetype)initWithMetalDevice:(nonnull id <MTLDevice>)device
                  renderDestinationProvider:(nonnull id <RenderDestinationProvider>)renderDestinationProvider
                                       view:(nonnull MTKView *)view {
  self = [super init];

  if (self) {
    Os::FileSystem::SetCurrentDir(Os::FileSystem::GetExePath());

    memcpy(&gMainWindow.desc, &gGameAppShell.initialWindowDesc, sizeof(GameAppShell_WindowDesc));
    gMainWindow.metalView = view;

    if (gGameAppShell.initialWindowDesc.width == -1 ||
				gGameAppShell.initialWindowDesc.height == -1) {
      gMainWindow.desc.width = 1920;
      gMainWindow.desc.height = 1080;
    } else {
      //if width and height were set manually in App constructor
      //then override and set window size to user width/height.
      //That means we now render at size * gRetinaScale.
      //TODO: make sure pSettings->mWidth determines window size and not drawable size as on retina displays we need to make sure that's what user wants.
      NSSize windowSize = CGSizeMake(gMainWindow.desc.width, gMainWindow.desc.height);
      [view.window setContentSize:windowSize];
      [view setFrameSize:windowSize];
    }
    NSString *nameNSString = [NSString stringWithUTF8String:gMainWindow.desc.name];
    [view.window setTitle:nameNSString];

    @autoreleasepool {
      //if init fails then exit the app
      if (!APP_CALLBACK_RET(onInitCallback)) {
        for (NSWindow *window in [NSApplication sharedApplication].windows) {
          [window close];
        }
				APP_ABORT
      }

      //if display load fails then exit the app
      if (!APP_CALLBACK_RET(onDisplayLoadCallback)) {
        for (NSWindow *window in [NSApplication sharedApplication].windows) {
          [window close];
        }
				APP_ABORT
      }

    }
  }

  return self;
}

- (void)drawRectResized:(CGSize)size {
  float const newWidth = (float) size.width * gMainWindow.retinaScale[0];
  float const newHeight = (float) size.height * gMainWindow.retinaScale[1];

  if (newWidth != gMainWindow.desc.width ||
      newHeight != gMainWindow.desc.height) {

    gMainWindow.desc.width = (uint32_t) newWidth;
    gMainWindow.desc.height = (uint32_t) newHeight;

    APP_CALLBACK(onDisplayUnloadCallback);
		if( APP_CALLBACK_RET(onDisplayLoadCallback) ) {
			APP_ABORT
		}
  }
}

- (void)update {

	static double lastTimeMs = (double)Os_GetSystemTime();
  double deltaTimeMS = Os_GetSystemTime() - lastTimeMs;
  // if framerate appears to drop below about 6, assume we're at a breakpoint and simulate 20fps.
  if (deltaTimeMS > 0.15) {
    deltaTimeMS = 0.05;
  }

	if(gGameAppShell.perFrameUpdateCallback) { gGameAppShell.perFrameUpdateCallback(deltaTimeMS); }
	if(gGameAppShell.perFrameDrawCallback) { gGameAppShell.perFrameDrawCallback(deltaTimeMS); }

}

- (void)shutdown {
	APP_CALLBACK(onDisplayUnloadCallback)
	APP_CALLBACK(onQuitCallback)
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

AL2O3_EXTERN_C void* GameAppShell_GetPlatformWindowPtr() {
  return (__bridge void*)[gMainWindow.metalView window];
}
