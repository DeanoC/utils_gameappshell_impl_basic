#include "al2o3_platform/platform.h"
#include "al2o3_platform/windows.h"
#include "utils_gameappshell/gameappshell.h"
#include "utils_gameappshell/windows/platform.h"
#include <fcntl.h>
#include <io.h>
#include <stdio.h>
#include <ios>

#define APP_ABORT if (gGameAppShell.onAbortCallback) { \
										gGameAppShell.onAbortCallback(); \
									} else { \
										abort(); \
									}
#define APP_CALLBACK_RET(x) ((gGameAppShell.x) ?  gGameAppShell.x() : true)
#define APP_CALLBACK(x) if(gGameAppShell.x) { gGameAppShell.x(); }
#define APP_CALLBACK1(x, arg0) if(gGameAppShell.x) { gGameAppShell.x(arg0); }


namespace {

GameAppShell_Shell gGameAppShell {};
GameAppShellBasic_Win32Window gMainWindow {};

struct WindowsSpecific {
	void createStandardArgs(LPSTR command_line);
	void getMessages(void);
	void ensureConsoleWindowsExists();
	bool registerClass(GameAppShell_WindowDesc const &desc);
	uint32_t createWindow(GameAppShell_WindowDesc &desc);
	void destroyWindow(uint32_t index);

	HINSTANCE hInstance;
	HINSTANCE hPrevInstance;
	int nCmdShow;

	static const int MAX_WINDOWS = 100;
	static const int MAX_CMDLINE_ARGS = 1024;

	GameAppShellBasic_Win32Window windows[MAX_WINDOWS];
	uint32_t windowCount;
	int argc;
	char *argv[MAX_CMDLINE_ARGS];
	char moduleFilename[MAX_PATH];
	bool windowsQuit = false;
} gWindowsSpecific;

LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
  switch (message) {
    case WM_DESTROY:gWindowsSpecific.windowsQuit = true;
      PostQuitMessage(0);
      break;
    case WM_PAINT:ValidateRect(hWnd, NULL);
      break;
    default:return DefWindowProc(hWnd, message, wParam, lParam);
  }
  return 0;
}
}
void WindowsSpecific::createStandardArgs(LPSTR command_line) {
  char *arg;
  int index;

  // count the arguments
  argc = 1;
  arg = command_line;

  while (arg[0] != 0) {
    while (arg[0] != 0 && arg[0] == ' ') {
      arg++;
    }

    if (arg[0] != 0) {
      argc++;
      while (arg[0] != 0 && arg[0] != ' ') {
        arg++;
      }
    }
  }

  if (argc > MAX_CMDLINE_ARGS) {
    argc = MAX_CMDLINE_ARGS;
  }

  // tokenize the arguments
  arg = command_line;
  index = 1;

  while (arg[0] != 0) {
    while (arg[0] != 0 && arg[0] == ' ') {
      arg++;
    }

    if (arg[0] != 0) {
      argv[index] = arg;
      index++;

      while (arg[0] != 0 && arg[0] != ' ') {
        arg++;
      }

      if (arg[0] != 0) {
        arg[0] = 0;
        arg++;
      }
    }
  }

  // put the program name into argv[0]
  argv[0] = moduleFilename;
}

//! Pumps windows messages
void WindowsSpecific::getMessages(void) {
  if (windowCount > 0) {
    MSG Message;
    while (PeekMessage(&Message, NULL, 0, 0, PM_REMOVE)) {
      TranslateMessage(&Message);
      DispatchMessage(&Message);

			APP_CALLBACK1(onMsgCallback, &Message);
    }
  } else {
    for (auto window : windows) {
      MSG Message;
      while (PeekMessage(&Message, window.hwnd, 0, 0, PM_REMOVE)) {
        TranslateMessage(&Message);
        DispatchMessage(&Message);
				APP_CALLBACK1(onMsgCallback, &Message);
      }
    }
  }
}
void WindowsSpecific::ensureConsoleWindowsExists() {
  // maximum mumber of lines the output console should have
  static const WORD MAX_CONSOLE_LINES = 500;

  using namespace std;
  int hConHandle;
  HANDLE lStdHandle;

  CONSOLE_SCREEN_BUFFER_INFO coninfo;
  FILE *fp;

  // allocate a console for this app
  AllocConsole();

  // set the screen buffer to be big enough to let us scroll text
  GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &coninfo);

  coninfo.dwSize.Y = MAX_CONSOLE_LINES;

  SetConsoleScreenBufferSize(GetStdHandle(STD_OUTPUT_HANDLE), coninfo.dwSize);

  // redirect unbuffered STDOUT to the console
  lStdHandle = GetStdHandle(STD_OUTPUT_HANDLE);
  hConHandle = _open_osfhandle((intptr_t) lStdHandle, _O_TEXT);
  fp = _fdopen(hConHandle, "w");
  *stdout = *fp;
  setvbuf(stdout, NULL, _IONBF, 0);

  // redirect unbuffered STDIN to the console
  lStdHandle = GetStdHandle(STD_INPUT_HANDLE);
  hConHandle = _open_osfhandle((intptr_t) lStdHandle, _O_TEXT);
  fp = _fdopen(hConHandle, "r");
  *stdin = *fp;
  setvbuf(stdin, NULL, _IONBF, 0);

  // redirect unbuffered STDERR to the console
  lStdHandle = GetStdHandle(STD_ERROR_HANDLE);
  hConHandle = _open_osfhandle((intptr_t) lStdHandle, _O_TEXT);
  fp = _fdopen(hConHandle, "w");
  *stderr = *fp;
  setvbuf(stderr, NULL, _IONBF, 0);


  // make cout, wcout, cin, wcin, wcerr, cerr, wclog and clog

  // point to console as well
  ios::sync_with_stdio();
}

bool WindowsSpecific::registerClass(GameAppShell_WindowDesc const& desc) {
  // Register class
  WNDCLASSEX wcex;
  wcex.cbSize = sizeof(WNDCLASSEX);
  wcex.style = CS_HREDRAW | CS_VREDRAW | CS_OWNDC;
  wcex.lpfnWndProc = WndProc;
  wcex.cbClsExtra = 0;
  wcex.cbWndExtra = 0;
  wcex.hInstance = hInstance;
  wcex.hIcon = (HICON) desc.bigIcon;
  wcex.hCursor = LoadCursor(NULL, IDC_ARROW);
  wcex.hbrBackground = (HBRUSH) (COLOR_WINDOW + 1);
  wcex.lpszMenuName = NULL;
  wcex.lpszClassName = desc.name;
  wcex.hIconSm = (HICON) desc.smallIcon;
  if (!RegisterClassEx(&wcex)) {
    return false;
  }

  return true;
}

uint32_t WindowsSpecific::createWindow(GameAppShell_WindowDesc& desc) {
  // Create window
  if (desc.width == -1 || desc.width == 0) {
		desc.width = 1920;
  }
  if( desc.height == -1 || desc.height == 0) {
		desc.height = 1080;
  }

	RECT rc = {0, 0, (LONG) desc.width, (LONG) desc.height};
	DWORD style = WS_VISIBLE;
	DWORD styleEx = 0;
	if(!desc.fullScreen) style |= WS_OVERLAPPEDWINDOW;

  HWND hwnd = CreateWindowEx(styleEx,
                             desc.name,
                             desc.name,
                             style,
                             0, 0, rc.right - rc.left, rc.bottom - rc.top,
                             nullptr,
                             nullptr,
                             gWindowsSpecific.hInstance,
                             nullptr);
  if (!hwnd) { return ~0u; }

  GetClientRect(hwnd, &rc);
  desc.width = rc.right - rc.left;
  desc.height = rc.bottom - rc.top;
  desc.dpiBackingScale[0] = 1.0f; // TODO when Windows backend is DPI aware
	desc.dpiBackingScale[1] = 1.0f;

  gWindowsSpecific.getMessages();
  ShowWindow(hwnd, gWindowsSpecific.nCmdShow);
  gWindowsSpecific.getMessages();
  gWindowsSpecific.windows[windowCount++] = {desc, hwnd};

  return windowCount - 1;
}

void WindowsSpecific::destroyWindow(uint32_t index) {
  if (index == ~0u) { return; }
  if (index >= windowCount) { return; }

  if (gWindowsSpecific.windows[index].hwnd == nullptr) { return; }

  DestroyWindow(gWindowsSpecific.windows[index].hwnd);
  gWindowsSpecific.windows[index].hwnd = nullptr;
}

EXTERN_C int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
  gWindowsSpecific.hInstance = hInstance;
  gWindowsSpecific.hPrevInstance = hPrevInstance;
  gWindowsSpecific.nCmdShow = nCmdShow;

  GetModuleFileNameA(NULL, gWindowsSpecific.moduleFilename, MAX_PATH);
  gWindowsSpecific.createStandardArgs(lpCmdLine);
//  gWindowsSpecific.ensureConsoleWindowsExists();

	extern int main(int argc, char const *argv[]);

  return main(gWindowsSpecific.argc, (char const**)gWindowsSpecific.argv);
}

// GuiShell Window API
AL2O3_EXTERN_C void GameAppShell_WindowGetCurrentDesc(GameAppShell_WindowDesc *desc) {
  ASSERT(desc);
  memcpy(desc, &gWindowsSpecific.windows[0].desc, sizeof(GameAppShell_WindowDesc));
}

AL2O3_EXTERN_C void GameAppShell_Quit() {
	gWindowsSpecific.windowsQuit = true;
}

AL2O3_EXTERN_C GameAppShell_Shell *GameAppShell_Init()
{
	return &gGameAppShell;
}

AL2O3_EXTERN_C void GameAppShell_MainLoop(int argc, char const *argv[]) {
	if(gGameAppShell.initialWindowDesc.name == NULL) {
		gGameAppShell.initialWindowDesc.name = "No name for al2o3 app specified";
	}

	GameAppShell_WindowDesc& desc = gGameAppShell.initialWindowDesc;
	gWindowsSpecific.registerClass(desc);
	uint32_t mainWindowIndex = gWindowsSpecific.createWindow(desc);
	ASSERT(mainWindowIndex == 0);

	if(!APP_CALLBACK_RET(onInitCallback))
	{
		APP_ABORT
		return;
	}
	if(!APP_CALLBACK_RET(onDisplayLoadCallback)) {
		APP_ABORT;
		return;
	}

	while (gWindowsSpecific.windowsQuit == false) {
		// TODO timing
		double deltaTimeMS = 18.0;

		gWindowsSpecific.getMessages();

		if (gGameAppShell.perFrameUpdateCallback) {
			gGameAppShell.perFrameUpdateCallback(deltaTimeMS);
		}
		if (gGameAppShell.perFrameDrawCallback) {
			gGameAppShell.perFrameDrawCallback(deltaTimeMS);
		}
	}

	APP_CALLBACK(onDisplayUnloadCallback);
	APP_CALLBACK(onQuitCallback)

	gWindowsSpecific.destroyWindow(mainWindowIndex);
}

AL2O3_EXTERN_C void *GameAppShell_GetPlatformWindowPtr() {
	ASSERT(gWindowsSpecific.windowCount > 0);
  return gWindowsSpecific.windows[0].hwnd;
}