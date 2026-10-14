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
game** (North America, `GMSE01`): the title is compiled from the
decompilation and reads everything else (models, levels, sound, movies) from
your disc. No game data, Nintendo artwork, Sony software or keys are included.

This is an unofficial port. It is not part of sms-pc-port and is not supported
by it: **please do not take PS5 problems to chasem-dev.** Report them
[here](https://github.com/griches/PS5_Sunshine/issues).

## This is an early release: 0.10.0

**It is not fully tested.** It was brought up and played on one console over a
single day (2026-10-13), through the opening, Delfino Plaza and the first
episode of Bianco Hills. Everything after that is unplayed on a PS5. Expect
faults; several serious ones were found and fixed only by playing, and there
will be more further into the game. Keep a copy of your save.

New in 0.10.0: a ready-made title (copy it over and add your disc), and the HD
texture pack goes in as its authors publish it, with the console sizing its
largest images itself.

## Installing

You need a PS5 that runs homebrew, with etaHEN (or an equivalent),
ShadowMountPlus (which shows folders in `/data/homebrew` as games) and an FTP
server, and **your own disc image** of the North American release (`GMSE01`,
revision 0) as `.iso`, `.gcm` or Dolphin's `.ciso`. Other regions are not
supported.

1. Download `Sunshine-PS5-v<version>.zip` from the
   [releases page](https://github.com/griches/PS5_Sunshine/releases/latest) and unzip it.
2. With an FTP program (FileZilla, Cyberduck, WinSCP), copy the **whole
   `PPSA99312` folder** into `/data/homebrew/` on the console.
3. Copy your disc image into that folder, beside `eboot.bin`:

```text
/data/homebrew/PPSA99312/eboot.bin
/data/homebrew/PPSA99312/sce_sys/
/data/homebrew/PPSA99312/sce_module/
/data/homebrew/PPSA99312/res/
/data/homebrew/PPSA99312/licenses/
/data/homebrew/PPSA99312/GMSE01.iso        (your disc image; any name)
```

"Super Mario Sunshine" appears on the home screen. If it does not, check the
folder is exactly `/data/homebrew/PPSA99312/` with `eboot.bin` directly inside
it (not `PPSA99312/PPSA99312/`), and that ShadowMountPlus is running. If it
starts and closes at once, the disc image is missing or is not the North
American one.

To update, copy the new release's `PPSA99312` folder over the old one. Your
saves, settings, disc image and texture packs are left alone.

## Playing

| DualSense | In the game |
| --- | --- |
| Cross | A (jump, confirm) |
| Circle | B (dive, back) |
| Square | X |
| Triangle | Y (first-person view) |
| R1 | Z |
| L1 + R1 | **Save state** (in a level); in the pause menu, the list of save states to load |
| L2, R2 | L, R (R sprays FLUDD) |
| Options | Start (pause, map) |
| Touch pad button | **Settings** |
| Sticks, D-pad | as on a GameCube |

The prompts the game shows on screen are the DualSense's own.

**Settings.** Press the touch pad's button at any time. The D-pad moves and
changes, Cross steps through a row's choices, Circle or the touch pad closes it.

| Row | What it does |
| --- | --- |
| Invert FLUDD Aim X / Y | flips the left stick while you aim FLUDD |
| Invert Camera X / Y | flips the right stick's camera |
| Camera Shake | OFF, HALF or FULL: the game's earthquakes (off to begin with) |
| Performance Overlay | OFF, MINIMAL (the frame rate alone) or FULL |
| Heat Haze | the heat shimmer |
| Resolution \* | 960p, 1440p, 1920p or 2160p |
| Frame Rate \* | 30 or 60 |
| Picture \* | 4:3 or 16:9 |
| Smoothing (FXAA) \* | on or off |

Rows marked \* take effect the next time you start the game. Below them are
the PC port's cheats (god mode, infinite lives and so on). Saves and settings
are kept in `/data/homebrew/PPSA99312/userdata/`.

**Save states.** Hold L1 and press R1 in a level to save the moment. Pause
(Options) and press L1 + R1 again to see your save states, with a picture of
each, and load one. They are kept in `userdata/savestates`. A state loads
exactly only in the release that saved it; with a newer release, older states put
Mario back where he was in that level and keep your progress, but the level
starts afresh.

## HD textures (optional)

The port loads texture packs made for the Dolphin emulator. The one it was
tested with is the
[Super Mario Sunshine UHD Texture Pack](https://github.com/qashto/Super_Mario_Sunshine_UHD_Texture_Pack)
(by qashto and razius), with chasem-dev's
[HD texture extras](https://github.com/chasem-dev/sms-hd-texture-extras):

1. Download `GMS.7z` from the UHD pack's
   [release 2.1.1](https://github.com/qashto/Super_Mario_Sunshine_UHD_Texture_Pack/releases/tag/2.1.1)
   and `sms-hd-texture-extras-1.1.1.zip` from the extras'
   [release 1.1.1](https://github.com/chasem-dev/sms-hd-texture-extras/releases/tag/v1.1.1).
2. Unpack both on your computer (7-Zip on Windows; a Mac opens the `.7z` with
   The Unarchiver or `tar -xf GMS.7z`).
3. Copy them to the console so that you have:

```text
/data/homebrew/PPSA99312/mods/textures/GMS/                     (the GMS folder from GMS.7z's Textures folder)
/data/homebrew/PPSA99312/mods/textures/sms-hd-texture-extras/   (the extras' zip, unpacked)
```

The packs are not part of this project and are not stored by it: they belong
to their authors.

**The first visit to each area is slower.** The UHD pack's largest images
(4096 to 16384 pixels) are more than the console's graphics driver can hold,
so the title halves each one to 2048 pixels or less the first time it is used
and keeps the result in `userdata/.cache`. After that, loads read the small
copy. Deleting that folder only means the work is done again.

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
| Loading | Delfino Plaza in about 6 seconds with the HD pack (9 the first time, while its largest images are halved); a "LOADING..." notice during long loads | |
| Input | Walking, jumping, the camera, FLUDD, menus, the DualSense's own button prompts | Every button in play; rumble; a second controller |
| Settings | The touch pad's menu: inverted FLUDD aim and camera, camera shake, the performance overlay, resolution, frame rate; choices kept across a restart | Every row; the cheats below them |
| Saving | A save made earlier loads | Saving in play, checked after a restart |
| Save states | Saving with L1 + R1 in a level, the pause menu's list with pictures, loading a state, and loading after a restart | States across many levels; a state from another build (loads the position only, by design) |
| The map (R1) | The wipe into it, now quick | |
| Sound | Music, effects and the movies' sound play | A careful listen for faults |
| Texture packs | The UHD pack and the HD extras as published, their largest images halved on the console (see below) | Other packs |
| Memory | Two levels and back without running out, with the HD pack at the sizes the console uses | Bianco Hills since the console does the halving itself; many levels in one session |

### Known problems

- **Only the start of the game has been played.** Anything from Bianco Hills
  episode 2 onward is untested on a PS5.
- **Camera shake is off to begin with.** The game's earthquakes (a boss
  landing, a building rising) are strong on a large screen. Turn them back on
  in the settings menu if you want the original feel.
- **Save states belong to the release that saved them.** L1 + R1 saves one in a
  level, and loads one from the pause menu (sms-pc-port's own). A state loads
  exactly only in the release that saved it: in a newer one it puts Mario back
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
git -C vendor/sms-pc-port checkout c8fb4a3e81a2176588574395302ecf862f9a440a   # the revision SOURCE.txt names
git -C vendor/sms-pc-port submodule update --init decomp
export PS5_VULKAN_DIR=/path/to/PS5_Vulkan PS5_OPENGL_PREFIX=/path/to/ps5-opengl-sdk/sdk
ps5/tools/build.sh             # applies the patch, builds dist/PPSA99312/
ps5/tools/package-release.sh   # the release archive, dist/Sunshine-PS5-v<version>.zip
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
