#define CATCH_CONFIG_RUNNER
#include "al2o3_catch2/catch2.hpp"
#include "utils_simple_logmanager/logmanager.h"
#include "utils_gameappshell/gameappshell.h"

namespace {
int runner_phase = 0;
bool Init() {
	runner_phase++; // catch not running yet
	return true;
}

bool Load() {
	runner_phase++; // catch not running yet
	return true;
}

void Update(double deltaTimeMS) {
	static bool testsHaveRun = false;
	if(testsHaveRun == false ) {
		runner_phase++; // catch not running yet
		char const* argv[] = { "GameAppShell Basic runner test" };
		Catch::Session().run(sizeof(argv)/sizeof(argv[0]), (char**) argv);
		testsHaveRun = true;
		GameAppShell_Quit();
	}
}

TEST_CASE( "count phase", "[GameApp runner]")
{
	REQUIRE(runner_phase++ == 3);
}

void Draw(double deltaTimeMS) {

}

void Unload() {
}

void Exit() {
}

void Abort() {
	abort();
}

} // end anon namespace


int main(int argc, char const *argv[]) {
	auto logger = SimpleLogManager_Alloc();

	GameAppShell_Shell* shell = GameAppShell_Init();
	shell->onInitCallback = &Init;
	shell->onDisplayLoadCallback = &Load;
	shell->onDisplayUnloadCallback = &Unload;
	shell->onQuitCallback = &Exit;
	shell->onAbortCallback = &Abort;
	shell->perFrameUpdateCallback = &Update;
	shell->perFrameDrawCallback = &Draw;

	auto ret = GameAppShell_MainLoop(argc, argv);

	SimpleLogManager_Free(logger);

	return ret;
}


