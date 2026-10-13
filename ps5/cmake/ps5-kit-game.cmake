# Super Mario Sunshine for the PlayStation 5 - the builder kit's share of the build: the game's code alone.
#
# kit/build-title.sh configures the PC port (fetched and patched on the machine
# that runs it) with the payload SDK's toolchain and this file as
# CMAKE_PROJECT_sms_port_INCLUDE, then builds the one target sms_game: the
# archive of the game's own code, which is the part a kit cannot bring. The
# flags are the ones ps5-game.cmake gives the full build, so the archive is the
# one the kit's other objects were linked with when it was tested.
#
# SPDX-License-Identifier: MIT

if(NOT PS5_KIT_DIR)
	message(FATAL_ERROR "ps5-kit-game.cmake: PS5_KIT_DIR is not set (use the kit's build-title.sh)")
endif()

add_compile_options(-ffunction-sections -fdata-sections -fno-omit-frame-pointer)
set(CMAKE_C_COMPILER_LAUNCHER sh ${PS5_KIT_DIR}/ps5/tools/cc-init-array.sh)
set(CMAKE_CXX_COMPILER_LAUNCHER sh ${PS5_KIT_DIR}/ps5/tools/cc-init-array.sh)
set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)
set(BUILD_SHARED_LIBS OFF)
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)
set(SMS_ARCH 64 CACHE STRING "" FORCE)
set(SMS_GX_BUILD_TESTS OFF CACHE BOOL "" FORCE)

# The port's other targets are configured but never built here: SDL2 only has
# to exist by name for them.
if(NOT TARGET SDL2::SDL2)
	add_library(SDL2::SDL2 INTERFACE IMPORTED GLOBAL)
endif()
