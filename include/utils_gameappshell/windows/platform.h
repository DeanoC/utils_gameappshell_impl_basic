#pragma once
#ifndef UTILS_GAMEAPPSHELL_BASIC_WINDOWS_PLATFORM_H
#define UTILS_GAMEAPPSHELL_BASIC_WINDOWS_PLATFORM_H

typedef struct GameAppShellBasic_Win32Window {
	GameAppShell_WindowDesc desc;
  HWND hwnd;
} GameAppShellBasic_Win32Window;

#endif //UTILS_GAMEAPPSHELL_BASIC_WINDOWS_PLATFORM_H
