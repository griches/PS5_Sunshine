# Licences

The repository as a whole is offered under the GNU General Public License,
version 3 ([`LICENSE`](LICENSE)). Its files come from projects under several
licences, each compatible with that; every source file names its own in its
header, and may also be used under that licence alone.

| Path | Licence | Text |
| --- | --- | --- |
| `ps5/tools/png-to-title-dds.py` (encoder from PS5 RetroArch, by Mihawk) | GPL-3.0-or-later | [`licenses/GPL-3.0.txt`](licenses/GPL-3.0.txt) |
| `ps5/src/platform.c`, `ps5/src/platform.h` and the tools taken from the PS5 Vulkan Template (by Mihawk) | MIT | [`licenses/MIT.txt`](licenses/MIT.txt) |
| The rest of `ps5/src/`, `ps5/tools/`, `ps5/cmake/`, `ps5/opengl/`, `ps5/probe/` and `ps5/art/` (written for this port) | MIT | [`licenses/MIT.txt`](licenses/MIT.txt) |
| `ps5/sdl/` (SDL2 drivers for the console) and `ps5/patches/sdl.patch` | Zlib, as SDL | [`licenses/Zlib.txt`](licenses/Zlib.txt) |
| `ps5/patches/sms-pc-port.patch` | MIT, as sms-pc-port | [`licenses/MIT.txt`](licenses/MIT.txt) |
| `ps5/art/kenney/` and the button prompts in `ps5/res/prompts/` made from it (Kenney's input prompts) | CC0-1.0 | in `ps5/art/kenney/` |

## What is built from elsewhere

Nothing below is stored in this repository; the build takes each from its own
project, under that project's licence.

| Part | Project | Licence |
| --- | --- | --- |
| The PC port: the platform, sound, input and graphics layers the game runs on | [sms-pc-port](https://github.com/chasem-dev/sms-pc-port) | MIT |
| The game's code | [sms-english](https://github.com/chasem-dev/sms-english), a decompilation of Super Mario Sunshine | published as CC0-1.0; see below |
| The OpenGL driver | the [PS5 OpenGL SDK](https://github.com/blackbearreloaded/ps5-opengl) (Mesa over the console's GPU interface) | GPL-3.0-or-later (the SDK); MIT (Mesa) |
| Windowing, input and sound | [SDL2](https://github.com/libsdl-org/SDL) | Zlib |
| The link recipe, the C runtime start-up and the fake-SELF tool | [PS5_Vulkan](https://github.com/mihawk-99/PS5_Vulkan) | GPL-3.0 |
| The platform layer and SDK | [PS5_PayloadSDK](https://github.com/mihawk-99/PS5_PayloadSDK), a fork of ps5-payload-dev/sdk | GPL-3.0 |
| Smaller libraries | stb, bcdec, xxHash | each its own, all permissive |

## The release

A release (`ps5/tools/package-release.sh`) is the built title folder: its
`eboot.bin` links the parts above and is distributed under GPL-3.0 as a whole,
with `SOURCE.txt` naming the repository and revision of each part and
`licenses/` holding their licence texts. The game's code in it is compiled from
the decompilation; nothing from a disc is in it.

## What is not covered

- **The game.** Super Mario Sunshine, its disc image and everything on it
  belong to Nintendo. None of it is in this repository or in a release, and no
  licence above covers it; the title plays your own disc image.
- **Texture packs.** The port can load Dolphin-format texture packs. None is in
  this repository or in a release; each belongs to its authors.
- **Artwork.** `ps5/art/icon0-source.png` and `ps5/art/pic-source.png` (a harbour
  town on a sunny island), and the `ps5/sce_sys/icon0.png`, `pic0.dds` and
  `pic1.dds` made from them, are the port's own: made for it by Gary Riches with
  an image generator. Nothing in them is Nintendo's, and no licence above is
  claimed for them beyond their use with this port.
- **Trademarks.** "Super Mario Sunshine", "Mario", "GameCube" and "Nintendo" are
  trademarks of Nintendo. "PlayStation", "PS5" and "DualSense" are trademarks of
  Sony Interactive Entertainment. They are used here only to say what this
  software works with. This project is not affiliated with, endorsed or
  sponsored by either.
