# Super Mario Sunshine for the PlayStation 5 - what the console adds to the PC port's own build.
#
# tools/build.sh configures vendor/sms-pc-port itself with the payload SDK's
# toolchain, and names this file as CMAKE_PROJECT_sms_port_INCLUDE: CMake
# includes it right after the project() call, before the build reads its
# options and looks for its dependencies. It provides:
#
#   SDL2     .deps/SDL2, patched (tools/setup-sdl.sh), with the drivers in ps5/sdl
#   OpenGL   the PS5 OpenGL SDK's headers (its libraries are linked by tools/link-title.sh)
#   options  the console's choices among the port's own
#
# and makes the executable's link the console's (tools/link-title.sh).
# Only the top-level project gets this (CMAKE_PROJECT_<name>_INCLUDE).
#
# SPDX-License-Identifier: MIT

foreach(required PS5_PORT_DIR PS5_VULKAN_DIR SDL_DIR PS5_OPENGL_PREFIX)
	if(NOT ${required})
		message(FATAL_ERROR "ps5-game.cmake: ${required} is not set (use ps5/tools/build.sh)")
	endif()
endforeach()
set(ps5 ${PS5_PORT_DIR}/ps5)

# -fno-omit-frame-pointer: the console's crash backtraces are frame-pointer walks.
add_compile_options(-ffunction-sections -fdata-sections -fno-omit-frame-pointer)
# An init array, in the order the source has: tools/cc-init-array.sh has the reason
set(CMAKE_C_COMPILER_LAUNCHER sh ${ps5}/tools/cc-init-array.sh)
set(CMAKE_CXX_COMPILER_LAUNCHER sh ${ps5}/tools/cc-init-array.sh)
set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)
set(BUILD_SHARED_LIBS OFF)
# no C++ modules anywhere: the toolchain has no dependency scanner
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

# The platform archive, by its file and not its target: it is linked whole into the title (below)
set(ps5_platform_archive ${CMAKE_BINARY_DIR}/libps5_platform.a)

# The console: klog, the pad, and the libc names a title cannot import
add_library(ps5_platform STATIC ${ps5}/src/platform.c ${ps5}/src/shims.c ${ps5}/src/startup.c)
target_include_directories(ps5_platform PUBLIC ${ps5}/src)
file(READ ${ps5}/sce_sys/param.json param_json)
string(JSON PS5_TITLE_NAME GET "${param_json}" localizedParameters en-US titleName)
target_compile_definitions(ps5_platform PRIVATE "PS5_TITLE_NAME=\"${PS5_TITLE_NAME}\"")
set_target_properties(ps5_platform PROPERTIES ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})

# OpenGL: the SDK's EGL and GL headers, for SDL's video driver
set(SDL_PS5_OPENGL_INCLUDE_DIR ${PS5_OPENGL_PREFIX}/include CACHE INTERNAL "")

# SDL2: threads, time and files as a FreeBSD has them; video, input and audio from ps5/sdl
set(SDL_PS5_PORT_DIR ${ps5}/sdl CACHE INTERNAL "")
set(SDL_PS5_PLATFORM_DIR ${ps5}/src CACHE INTERNAL "")
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(SDL2_DISABLE_SDL2MAIN ON CACHE BOOL "" FORCE)
set(SDL2_DISABLE_INSTALL ON CACHE BOOL "" FORCE)
set(SDL2_DISABLE_UNINSTALL ON CACHE BOOL "" FORCE)
foreach(off SDL_SHARED SDL_TEST SDL_TESTS
		SDL_X11 SDL_WAYLAND SDL_KMSDRM SDL_RPI SDL_VIVANTE SDL_OFFSCREEN SDL_DUMMYVIDEO SDL_DIRECTFB
		SDL_OPENGL SDL_OPENGLES SDL_VULKAN SDL_RENDER
		SDL_OSS SDL_ALSA SDL_JACK SDL_ESD SDL_ARTS SDL_NAS SDL_PIPEWIRE SDL_PULSEAUDIO SDL_SNDIO SDL_FUSIONSOUND
		SDL_DISKAUDIO SDL_DUMMYAUDIO SDL_LIBSAMPLERATE
		SDL_DBUS SDL_IBUS SDL_LIBUDEV SDL_HIDAPI SDL_HIDAPI_LIBUSB SDL_HIDAPI_JOYSTICK SDL_VIRTUAL_JOYSTICK
		SDL_SYSTEM_ICONV SDL_LIBICONV SDL_RPATH SDL_SENSOR SDL_HAPTIC SDL_POWER)
	set(${off} OFF CACHE BOOL "" FORCE)
endforeach()
# (SDL_OPENGL is SDL's switch for a desktop's libGL: ps5/patches/sdl.patch turns
# OpenGL on for the console itself)
add_subdirectory(${SDL_DIR} ${CMAKE_BINARY_DIR}/SDL2 EXCLUDE_FROM_ALL)
target_include_directories(ps5_platform PRIVATE ${SDL_DIR}/include)
if(NOT TARGET SDL2::SDL2)
	add_library(SDL2::SDL2 ALIAS SDL2-static)
endif()
# <SDL.h> and <SDL2/SDL.h> both: the build tree has its headers under include/SDL2
set(SDL2_INCLUDE_DIRS ${CMAKE_BINARY_DIR}/SDL2/include ${CMAKE_BINARY_DIR}/SDL2/include/SDL2
	${CMAKE_BINARY_DIR}/SDL2/include-config-release)
include_directories(${SDL2_INCLUDE_DIRS})

# The port's options, as the console has them: no self-tests (they are host programs)
set(SMS_ARCH 64 CACHE STRING "" FORCE)
set(SMS_GX_BUILD_TESTS OFF CACHE BOOL "" FORCE)

# The link: every object and archive CMake would hand the linker goes to the
# console's recipe instead (the platform layer, the CRT, OpenGL, the fake SELF)
set(CMAKE_CXX_LINK_EXECUTABLE
	"bash ${ps5}/tools/link-title.sh ${CMAKE_BINARY_DIR} ${PS5_VULKAN_DIR} ${PS5_PAYLOAD_SDK} --whole-archive ${ps5_platform_archive} --no-whole-archive <LINK_FLAGS> <OBJECTS> <LINK_LIBRARIES>")
# (the start-up constructor in the platform archive has no caller: hence whole)

# The platform archive is named by its file in the link, so the game does not
# depend on it by itself (the game's target exists once its CMakeLists.txt has run)
function(ps5_late_fixes)
	add_dependencies(sms ps5_platform)
	set_property(TARGET sms APPEND PROPERTY LINK_DEPENDS ${ps5_platform_archive})
endfunction()
cmake_language(DEFER DIRECTORY ${CMAKE_SOURCE_DIR} CALL ps5_late_fixes)
