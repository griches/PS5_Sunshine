# Super Mario Sunshine for PlayStation 5

[![stars](https://img.shields.io/github/stars/griches/PS5_Sunshine?style=flat)](https://github.com/griches/PS5_Sunshine/stargazers)
[![release](https://img.shields.io/github/v/release/griches/PS5_Sunshine)](https://github.com/griches/PS5_Sunshine/releases/latest)
[![licence](https://img.shields.io/badge/licence-GPL--3.0-blue)](LICENSING.md)

A PS5 homebrew port of **[sms-pc-port](https://github.com/chasem-dev/sms-pc-port)**,
the native PC port of Super Mario Sunshine by **[chasem-dev](https://github.com/chasem-dev)**.

> ## All of the hard work here is chasem-dev's
>
> [sms-pc-port](https://github.com/chasem-dev/sms-pc-port) is what makes this
> possible: a complete, native port of the GameCube game, with its own
> platform, sound, input and graphics layers, 60 and 120 frames a second,
> widescreen, texture packs and a great deal more, built on the
> [decompilation](https://github.com/chasem-dev/sms-english) it carries. This
> repository adds only what a PS5 needs on top of it: a patch of about 1,000
> lines, the console's drivers and a build recipe. If you enjoy this, the
> thanks belong there. **Please star and support
> [chasem-dev/sms-pc-port](https://github.com/chasem-dev/sms-pc-port).**

The game runs natively on the console, at 3840x2160 and 60 frames a second,
drawn with OpenGL through the [PS5 OpenGL SDK](https://github.com/blackbearreloaded/ps5-opengl)
(Mesa over the console's own GPU interface).

It needs a PS5 that already runs homebrew, and **your own disc image of the
game** (North America, `GMSE01`). No game code, game data, Nintendo artwork,
Sony software or keys are included here.

This is an unofficial port. It is not part of sms-pc-port and is not supported
by it: **please do not take PS5 problems to chasem-dev.** Report them
[here](https://github.com/griches/PS5_Sunshine/issues).

## This is an early release: 0.9.0

**It is not fully tested.** It was brought up and played on one console over a
single day (2026-10-13), through the opening, Delfino Plaza and the first
episode of Bianco Hills. Everything after that is unplayed on a PS5. Expect
faults; several serious ones were found and fixed only by playing, and there
will be more further into the game. Keep a copy of your save.

New in 0.9.0: sms-pc-port's save states (L1 + R1) and its faster wipe into the
map, from its revision of 2026-10-14, and a builder kit that no longer needs
Docker.

## How to get it: the builder kit

A built title holds the game's own code, so none is offered here. The
[release](https://github.com/griches/PS5_Sunshine/releases/latest) is a
**builder kit**: everything of a build except that code. On your own computer
it downloads the public source code, compiles it and links the title. One
command, about 5 to 20 minutes, on a Mac with Apple silicon, on Linux, or on
Windows in WSL. No Docker: on Ubuntu and WSL the compiler, LLVM 22, comes from
LLVM's own packages (apt.llvm.org); on a Mac it and the build tools are fetched
from their own releases the first time, checked, and kept for next time.

1. Download `sunshine-ps5-kit-<version>.zip` from the
   [releases page](https://github.com/griches/PS5_Sunshine/releases/latest) and unzip it.
2. Get your computer ready once (a Mac: Apple's Command Line Tools; Windows: WSL
   and LLVM 22; the kit's README has the commands), then open a terminal in the
   kit's folder and run `./make-title.sh`.
3. Copy the folder it makes, `out/PPSA99312`, to `/data/homebrew/` on the console (FTP).
4. Copy your own disc image (`.iso`, `.gcm` or `.ciso`) into that folder, beside `eboot.bin`.

The kit's own [README](ps5/kit/README.md) has every step, the controls, the
settings menu, the steps for Windows and what to do when something goes wrong.

**Never share the folder the kit makes, or its `eboot.bin`.**

## Status

Tested on one console (PS5, firmware 13.60) on 2026-10-13 and 2026-10-14, with the North
American disc (`GMSE01`, revision 0). "Seen" means it ran there and was
watched by a person playing, looked at in the console's own screenshots, or
read in the title's log. Nothing else is claimed.

| Area | Seen on the console | Not yet verified |
| --- | --- | --- |
| Start-up | The logos, the opening movie, the title screen, file select; a saved file loaded | A new game from an empty memory card |
| Rendering | 3840x2160; Delfino Plaza and Bianco Hills episode 1 look right; the plaza's gates show their movie of the level beyond | Everything past Bianco Hills episode 1; a comparison with a GameCube |
| Frame rate | A locked 60 frames a second (16.7 ms) in the plaza and Bianco Hills, at 2160p, with the HD texture pack | Later, heavier areas; a long session |
| Loading | Delfino Plaza in about 5 seconds with the console-sized HD pack; a "LOADING..." notice during long loads | |
| Input | Walking, jumping, the camera, FLUDD, menus, the DualSense's own button prompts | Every button in play; rumble; a second controller |
| Settings | The touch pad's menu: inverted FLUDD aim and camera, camera shake, the performance overlay, resolution, frame rate; choices kept across a restart | Every row; the cheats below them |
| Saving | A save made earlier loads | Saving in play, checked after a restart |
| Save states | Saving with L1 + R1 in a level, the pause menu's list with pictures, loading a state, and loading after a restart | States across many levels; a state from another build (loads the position only, by design) |
| The map (R1) | The wipe into it, now quick | |
| Sound | Music, effects and the movies' sound play | A careful listen for faults |
| Texture packs | The UHD pack and the HD extras, sized for the console (see below) | Other packs |
| Memory | Two levels and back without running out, with the console-sized pack | Many levels in one session |
| Builder kit | Built without Docker on a Mac (Apple silicon, macOS's own tools) and on Linux (arm64), and the Mac's title played on the console. On x86-64 Linux: LLVM's build fetched and run, a game file compiled identically, `eboot.bin` made byte for byte the same | A whole build on Windows (WSL) or x86-64 Linux; the `--docker` route |

### Known problems

- **Only the start of the game has been played.** Anything from Bianco Hills
  episode 2 onward is untested on a PS5.
- **Large texture packs must be shrunk.** The console's driver needs about ten
  times a texture's size in memory. The UHD pack as published made loads take
  17 seconds and ran the console out of memory in the second level. The kit
  makes a console-sized copy for you.
- **Camera shake is off to begin with.** The game's earthquakes (a boss
  landing, a building rising) are strong on a large screen. Turn them back on
  in the settings menu if you want the original feel.
- **Save states belong to the build that saved them.** L1 + R1 saves one in a
  level, and loads one from the pause menu (sms-pc-port's own). A state loads
  exactly only in the build that saved it: after a rebuild it puts Mario back
  where he was and keeps the progress, but the level starts afresh. Keep a
  copy of your memory card save as well.

## What the console needed

For the curious, and for anyone porting something similar. All of it is in
[`ps5/patches/sms-pc-port.patch`](ps5/patches/sms-pc-port.patch) and `ps5/`.

- **Where the game's memory goes.** The game wants its 64 MiB at address
  `0x80000000`, where a PS5 title's C library is loaded. It lives at
  `0xC0000000` instead, and two places in the game that test addresses against
  the GameCube's layout had to learn that (one of them silently switched off
  every material animation, so the plaza's gates never showed their movie).
- **Graphics.** OpenGL 4.6 from the PS5 OpenGL SDK, through SDL2 with a video
  driver for the console's EGL. The SDK's runtime is rebuilt with its helper
  threads on and a larger buffer arena ([`ps5/opengl/build-runtime.sh`](ps5/opengl/build-runtime.sh)).
- **Speed.** Reading single pixels back from the screen, which the game does
  every frame, is done through small late copies instead of a full-frame
  read; full-screen passes are drawn as two triangles, which the driver can
  batch.
- **A leak that only a console shows.** A pixel count the game leaves running
  (while Mario sleeps, for one) took a new GPU query at every pause and never
  gave them back. On the PS5 that filled the driver's buffer arena and halved
  the frame rate within minutes. It is bounded now.
- **Threads.** The game's video decoder runs below its main thread and was
  starved whenever a frame had no time to spare; the main thread now gives the
  others a turn.
- **Save states.** sms-pc-port finds the game's global variables for a state
  in the link map after linking. The console's title is linked by lld and
  loaded at an address of its own choosing, so the map is read with lld's
  layout and the ranges are written at link addresses, which the game slides
  by where it was loaded.
- **The console's own menu.** The touch pad's button opens settings a PS5 has
  no keyboard or launcher for.

## Building it yourself

The port is built on Linux (an arm64 or x86-64 machine or VM) with LLVM 22,
[PS5_PayloadSDK](https://github.com/mihawk-99/PS5_PayloadSDK),
[PS5_Vulkan](https://github.com/mihawk-99/PS5_Vulkan) (for its link recipe and
tools; no Vulkan driver is linked) and the PS5 OpenGL SDK 1.0.2.

```sh
git clone https://github.com/griches/PS5_Sunshine.git && cd PS5_Sunshine
git clone https://github.com/chasem-dev/sms-pc-port.git vendor/sms-pc-port
git -C vendor/sms-pc-port checkout c8fb4a3e81a2176588574395302ecf862f9a440a   # see ps5/kit: REVISIONS
git -C vendor/sms-pc-port submodule update --init decomp
export PS5_VULKAN_DIR=/path/to/PS5_Vulkan PS5_OPENGL_PREFIX=/path/to/ps5-opengl-sdk/sdk
ps5/tools/build.sh           # applies the patch, builds dist/PPSA99312/
ps5/tools/package-kit.sh     # the builder kit, dist/kit/
```

`ps5/tools/setup-source.sh --save` writes changes made under
`vendor/sms-pc-port` back to the patch.

## Credits

- **[chasem-dev](https://github.com/chasem-dev)**, for
  [sms-pc-port](https://github.com/chasem-dev/sms-pc-port) and the
  [decompilation](https://github.com/chasem-dev/sms-english) it builds, and
  for the [HD texture extras](https://github.com/chasem-dev/sms-hd-texture-extras).
  This port is theirs with a console's worth of glue.
- **BlackBearReloaded**, for the [PS5 OpenGL SDK](https://github.com/blackbearreloaded/ps5-opengl).
- **Mihawk**, for [PS5_Vulkan](https://github.com/mihawk-99/PS5_Vulkan),
  [PS5_PayloadSDK](https://github.com/mihawk-99/PS5_PayloadSDK) and the PS5
  Vulkan Template this port's platform layer comes from.
- **qashto and razius**, for the
  [Super Mario Sunshine UHD Texture Pack](https://github.com/qashto/Super_Mario_Sunshine_UHD_Texture_Pack).
- The [SDL](https://github.com/libsdl-org/SDL) and [Mesa](https://www.mesa3d.org/) projects,
  and [Kenney](https://kenney.nl/) for the button prompt artwork.

## Licence

GPL-3.0 as built; each part keeps its own licence. [`LICENSING.md`](LICENSING.md)
says which covers what, and what is not covered at all: the game, texture
packs and trademarks.

Super Mario Sunshine is Nintendo's. This project is not affiliated with,
endorsed or sponsored by Nintendo or Sony Interactive Entertainment.
