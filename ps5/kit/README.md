# Super Mario Sunshine for the PlayStation 5: builder kit

This kit builds a native PS5 version of Super Mario Sunshine (GameCube) on
your own computer, for a PS5 that has homebrew enabled. It plays **your own
copy** of the game, from your own disc image, at 4K and 60 frames a second.

You run one command. Your computer does the rest in about 5 to 20 minutes.

> **There is no game in this kit.** No game code, no game data, nothing of
> Nintendo's. The build fetches the public source code it needs and compiles
> it on your machine, and you supply the disc image. What the kit makes is
> yours alone: **never share the folder it produces, or its `eboot.bin`.**

---

## Before you start

You need three things.

**1. A PS5 that runs homebrew**, with:

- etaHEN (or an equivalent)
- ShadowMountPlus, which shows folders in `/data/homebrew` as games
- an FTP server running on the console

**2. Your disc image of the game.** The North American release (`GMSE01`,
revision 0), as `.iso`, `.gcm` or Dolphin's `.ciso`. Other regions are not
supported.

**3. A computer** (Windows, macOS or Linux) with:

- [Docker Desktop](https://www.docker.com/products/docker-desktop/), installed and running
- an internet connection (the build downloads a compiler and the source code)
- about 4 GB of free disk space
- 8 GB of memory or more

---

## Step 1: Unzip the kit

Unzip `sunshine-ps5-kit-<version>.zip` anywhere. You get a folder with this
`README.md`, `make-title.sh` and the rest of the kit in it.

## Step 2: Start Docker

Open Docker Desktop and wait until it says it is running.

## Step 3: Build the title

Open a terminal **in the kit's folder** and run the command for your system.

**macOS or Linux**

```sh
./make-title.sh
```

**Windows (PowerShell)**

```powershell
docker build -t sunshine-ps5-kit .
docker run --rm -v ${PWD}\out:/out sunshine-ps5-kit /out
```

(If you use WSL, the macOS and Linux command works there instead.)

### What you will see

| Stage | What it does | How long |
| --- | --- | --- |
| First run only | Builds the container; downloads a compiler (about 1 GB) | a few minutes |
| `fetching` | Downloads the PC port and the decompilation from GitHub | a minute |
| `configuring` | Prepares the build | under a minute |
| `compiling the game's code` | Compiles about 600 files for the PS5. **This is the long one.** | 3 to 15 minutes |
| `linking` | Joins it to the kit's parts and makes `eboot.bin` | under a minute |

It is finished when it prints the path of a folder ending in `PPSA99312`.

## Step 4: Copy it to the PS5

The result is the folder `out/PPSA99312` inside the kit's folder (about 50 MB).

With an FTP program (FileZilla, Cyberduck, WinSCP), connect to your PS5 and
copy that **whole folder** into `/data/homebrew/`. Then copy **your disc
image** into it, beside `eboot.bin`, so that you end up with:

```text
/data/homebrew/PPSA99312/eboot.bin
/data/homebrew/PPSA99312/sce_sys/
/data/homebrew/PPSA99312/sce_module/
/data/homebrew/PPSA99312/res/
/data/homebrew/PPSA99312/licenses/
/data/homebrew/PPSA99312/GMSE01.iso        (your disc image; any name)
```

## Step 5: Play

"Super Mario Sunshine" appears on the PS5's home screen. Start it like any game.

| DualSense | In the game |
| --- | --- |
| Cross | A (jump, confirm) |
| Circle | B (dive, back) |
| Square | X |
| Triangle | Y (first-person view) |
| R1 | Z |
| L2, R2 | L, R (R sprays FLUDD) |
| Options | Start (pause, map) |
| Touch pad button | **Settings** |
| Sticks, D-pad | as on a GameCube |

The prompts the game shows on screen are the DualSense's own.

### The settings menu

Press the touch pad's button at any time. The D-pad moves and changes, Cross
steps through a row's choices, Circle or the touch pad closes it.

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
the PC port's cheats (god mode, infinite lives and so on).

Your saves and settings are kept on the console in
`/data/homebrew/PPSA99312/userdata/`.

---

## Optional: HD textures

The port loads texture packs made for the Dolphin emulator. One command
downloads the [Super Mario Sunshine UHD Texture Pack](https://github.com/qashto/Super_Mario_Sunshine_UHD_Texture_Pack)
(by qashto and razius) and the [HD texture extras](https://github.com/chasem-dev/sms-hd-texture-extras)
(by chasem-dev) from their authors and makes a copy sized for the console:

**macOS or Linux**

```sh
./make-texture-pack.sh
```

**Windows (PowerShell)**

```powershell
docker run --rm --entrypoint python3 -v ${PWD}\out:/out sunshine-ps5-kit /kit/tools/get-texture-pack.py /out
```

It downloads about 1 GB, needs about 5 GB of free disk space while it works,
and leaves `out/textures` (1.3 GB). Copy that folder to the console as:

```text
/data/homebrew/PPSA99312/mods/textures/
```

The packs are not part of this kit and are not stored with it: they belong to
their authors, and the copy you make is for your own use.

**Why a console-sized copy?** The console's graphics driver needs about ten
times a texture's size in memory and takes texture data slowly. With the pack
as published (images up to 8192 pixels), Delfino Plaza took 17 seconds to load
and a second level ran the console out of memory. With nothing larger than
2048 pixels the plaza loads in about 5 seconds. Any other Dolphin pack can be
shrunk the same way with `tools/shrink-texture-pack.py SOURCE DEST`.

---

## If something goes wrong

**"docker was not found"**
Docker Desktop is not installed, or not running. Start it and try again.

**The fetch fails**
The build needs to reach github.com the first time. Check the connection and
run the command again.

**The build stops part way with "Killed", or Docker closes**
It ran out of memory. Either give Docker more (Docker Desktop > Settings >
Resources), or run fewer compilers at once:

```sh
JOBS=4 ./make-title.sh
```

On Windows, add `-e JOBS=4` after `docker run --rm`.

**It was interrupted**
Run the same command again. It carries on from where it stopped.

**The game does not appear on the PS5**
Check the folder is exactly `/data/homebrew/PPSA99312/` with `eboot.bin`
directly inside it (not `PPSA99312/PPSA99312/`), and that ShadowMountPlus is
running.

**It starts and closes at once**
The disc image is missing, or is not the North American release. It must be
in `/data/homebrew/PPSA99312/`, beside `eboot.bin`.

## Updating to a newer kit

Unzip the new kit, build again, and copy the new `out/PPSA99312` over the old
one on the console. Your saves, settings, disc image and texture packs are
left alone.

## Without Docker (Linux only)

If you already have LLVM 22 (clang, lld, llvm tools), CMake, Ninja, git,
Python 3, `patch`, a C++ compiler and the zlib development headers:

```sh
./build-title.sh
```

---

## What is in the kit

| Path | What |
| --- | --- |
| `make-title.sh`, `Dockerfile` | Runs the build in a container. |
| `build-title.sh` | The build itself: fetch, patch, compile, link. |
| `lib/` | The port's own compiled parts: the platform layer, the graphics layer, SDL2. |
| `opengl/` | The PS5 OpenGL SDK's driver, as this port links it. |
| `vulkan/` | PS5_Vulkan's link recipe and the tool that makes `eboot.bin` (no Vulkan driver). |
| `sdk/` | The payload SDK's compiler wrappers, headers, libraries and link scripts. |
| `ps5/` | The console's patch to the PC port, the link script, the title's icon and pictures. |
| `make-texture-pack.sh`, `tools/` | Downloads an HD texture pack and sizes it for the console. |
| `REVISIONS`, `SOURCES.txt`, `LICENSING.md`, `licenses/` | What the build fetches, where each part's source is, and its licence. |

The project, with what works, what does not, and how the port is made:
<https://github.com/griches/PS5_Sunshine>

This project is not affiliated with, endorsed or sponsored by Nintendo or Sony
Interactive Entertainment.
