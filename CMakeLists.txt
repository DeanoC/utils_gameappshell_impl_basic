cmake_minimum_required(VERSION 3.12.4)
get_directory_property(hasParent PARENT_DIRECTORY)
if(NOT hasParent)
	option(unittests "unittests" OFF)
	get_filename_component(_PARENT_DIR ${CMAKE_CURRENT_SOURCE_DIR} DIRECTORY)
	set_property(GLOBAL PROPERTY GLOBAL_FETCHDEPS_BASE ${_PARENT_DIR}/al2o3 )
	include(FetchContent)
	FetchContent_Declare( al2o3 GIT_REPOSITORY https://github.com/DeanoC/al2o3 GIT_TAG master )
	FetchContent_GetProperties(al2o3)
	if(NOT al2o3_POPULATED)
		FetchContent_Populate(al2o3)
		add_subdirectory(${al2o3_SOURCE_DIR} ${al2o3_BINARY_DIR})
	endif()
	INIT_AL2O3(${CMAKE_CURRENT_SOURCE_DIR})
endif ()

SET_MIN_VERSIONS()
set(BaseInterfaceName utils_gameappshell)
set(ImplName basic)
set(LibName ${BaseInterfaceName}_impl_${ImplName})
project(${LibName})

set(Interface
		)
set(Src
		)
if (APPLE)
	list(APPEND Src apple/macapp.hpp)
	list(APPEND Src apple/macapp.mm)
endif()
if (WIN32)
	list(APPEND Src windows/windows.cpp)
endif ()

set(Deps
		al2o3_platform
		al2o3_os
		utils_gameappshell_interface
		)
ADD_LINK_TIME_IMPL(${BaseInterfaceName} ${ImplName} "${Interface}" "${Src}" "${Deps}")
if (APPLE)
	add_compile_definitions(${LibName} METAL)
	target_compile_options(${LibName} PRIVATE -fobjc-arc)
	target_link_libraries(${LibName} PRIVATE stdc++ "-framework Foundation" "-framework Cocoa" objc)
	target_link_libraries(${LibName} PRIVATE "-framework Metal -framework MetalKit")
endif ()

if(BUILD_TESTS)
	set( Tests
			runner.cpp
			)
	set( TestDeps
			al2o3_catch2
			utils_simple_logmanager)
	ADD_LIB_GUITESTS(${LibName} "${Interface}" "${Tests}" "${TestDeps}" utils_gameappshell_interface)
endif()
