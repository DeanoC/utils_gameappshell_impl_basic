#pragma once
#ifndef UTILS_GAMEAPPSHELL_BASIC_APPLE_PLATFORM_H
#define UTILS_GAMEAPPSHELL_BASIC_APPLE_PLATFORM_H

#include "utils_gameappshell/windowdesc.h"
typedef struct GameAppShellBasic_AppleWindow {
	GameAppShell_WindowDesc desc;
	MTKView *_Nonnull metalView;
} GameAppShellBasic_AppleWindow;


#endif // end UTILS_GAMEAPPSHELL_BASIC_APPLE_PLATFORM_H