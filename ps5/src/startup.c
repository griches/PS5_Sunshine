/*
 * Super Mario Sunshine for the PlayStation 5 - what runs before the game's main.
 *
 * The game's main is the PC port's own (vendor/sms-pc-port/src/port_main.cpp),
 * so the console's start-up is a constructor: standard error into klog and the
 * shell's splash dismissed, and where a title may keep its files.
 *
 * A title sees its own folder (/app0, which is /data/homebrew/<TITLE_ID>) and
 * nothing else of /data:
 *
 *   /app0/<name>.iso       your own disc image of Super Mario Sunshine (USA, GMSE01),
 *                          as .iso, .gcm or .ciso: the first one found is played
 *   /app0/settings.txt     the PC port's settings file (optional)
 *   /app0/userdata/        the memory card (card-a/), logs, screenshots
 *   /app0/mods/            texture packs and language packs, as on a PC
 *   /app0/env.txt          optional: NAME=value lines for the environment
 *
 * The PC port takes its options from the environment: what the console wants
 * different from a PC is set here, unless env.txt or settings.txt says otherwise.
 *
 * SPDX-License-Identifier: MIT
 */
#include <SDL_stdinc.h>

#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "platform.h"

/* Both copies of the environment: the console's libc keeps what setenv sets
 * apart from the `environ` SDL copies. */
static void
set(const char *name, const char *value, int overwrite)
{
   setenv(name, value, overwrite);
   SDL_setenv(name, value, overwrite);
}

/* The game leaves through exit() from many places: the shell is asked to close
 * the title, as when main returns. Without that the console shows a title that
 * ended by itself as crashed. */
void catchReturnFromMain(int status);

static void
leave(void)
{
   static int left;

   if (!left++) {
      say("exit status 0");
      catchReturnFromMain(0);
   }
}

static int
is_disc_image(const char *name)
{
   const char *dot = strrchr(name, '.');

   return dot && (!strcasecmp(dot, ".iso") || !strcasecmp(dot, ".gcm") || !strcasecmp(dot, ".ciso"));
}

/* The first disc image in the title's folder */
static void
find_disc(void)
{
   DIR *folder = opendir("/app0");
   struct dirent *entry;
   char path[512];

   if (!folder)
      return;
   while ((entry = readdir(folder)) != NULL) {
      if (!is_disc_image(entry->d_name))
         continue;
      snprintf(path, sizeof path, "/app0/%s", entry->d_name);
      set("SMS_DISC_IMAGE", path, 0);
      say("disc image: %s", path);
      break;
   }
   closedir(folder);
   if (!getenv("SMS_DISC_IMAGE"))
      say("no disc image in the title's folder: copy your GMSE01 .iso, .gcm or .ciso beside eboot.bin");
}

__attribute__((constructor)) static void
ps5_startup(void)
{
   platform_init(PS5_TITLE_NAME);
   atexit(leave);
   mkdir("/app0/userdata", 0777);
   mkdir("/app0/userdata/card-a", 0777);
   /* PS5 DevLoop's grab takes the title's pictures from here, and removes them */
   mkdir("/app0/userdata/screenshots", 0777);
   chmod("/app0/userdata/screenshots", 0777);

   FILE *file = fopen("/app0/env.txt", "r");
   if (file) {
      char line[512];
      while (fgets(line, sizeof line, file)) {
         line[strcspn(line, "\r\n")] = 0;
         char *equals = strchr(line, '=');
         if (line[0] == '#' || !equals || equals == line)
            continue;
         *equals = 0;
         set(line, equals + 1, 1);
         say("env.txt: %s=%s", line, equals + 1);
      }
      fclose(file);
   }

   /* SMS_PS5_LOG_FILE=path in env.txt: the log into a file, for a console with
      no klog server to read it from (FTP fetches it while the title runs) */
   if (getenv("SMS_PS5_LOG_FILE") && freopen(getenv("SMS_PS5_LOG_FILE"), "w", stderr))
      setvbuf(stderr, NULL, _IOLBF, 0);

   /* What the in-game settings menu saved (the touch pad's button): env.txt's lines win */
   file = fopen("/app0/userdata/ps5-settings.txt", "r");
   if (file) {
      char line[512];
      while (fgets(line, sizeof line, file)) {
         line[strcspn(line, "\r\n")] = 0;
         char *equals = strchr(line, '=');
         if (line[0] == '#' || !equals || equals == line)
            continue;
         *equals = 0;
         set(line, equals + 1, 0);
      }
      fclose(file);
   }

   /* Where the port's files are, for a title with no working directory or home */
   set("HOME", "/app0/userdata", 0);
   set("XDG_DATA_HOME", "/app0/userdata", 0);
   set("SMS_SETTINGS", "/app0/settings.txt", 0);
   set("SMS_SAVE_DIR", "/app0/userdata/card-a", 0);
   set("SMS_BINDINGS", "/app0/bindings.txt", 0);
   /* ... and the folders the port looks for beside itself */
   struct stat status;
   if (stat("/app0/mods/textures", &status) == 0)
      set("SMS_TEXTURE_PACKS", "/app0/mods/textures", 0);
   /* A texture pack's share of the console's graphics memory. The driver holds
      each replacement at about ten times the size the port counts for it
      (measured: 10 MiB of the 11.7 GiB of direct memory per MiB held), so the
      PC's budget of 1536 cannot fit: the title died at about 1,070. From 512
      the oldest are let go, which keeps about 3 GiB spare through a load. */
   set("SMS_TEXTURE_PACK_MB", "512", 0);
   /* ... and the largest images it can take: the UHD pack's 4096 to 16384
      pixel files are halved to 2048 (or less) the first time each is used, and
      kept so in userdata/.cache, so the pack goes in as its authors publish it */
   set("SMS_TEXTURE_PACK_MAX_SIZE", "3072", 0);
   if (stat("/app0/mods/hd-cutscenes", &status) == 0)
      set("SMS_HD_CUTSCENES", "/app0/mods/hd-cutscenes", 0);
   find_disc();

   /* The console's choices among the port's options: the whole 16:9 screen, at
    * 4.5 times the GameCube's 480 lines (2160; Delfino Plaza holds 60 frames a
    * second there, and the settings menu offers less), paced by the display */
   set("SMS_FULLSCREEN", "1", 0);
   set("SMS_WIDESCREEN", "16:9", 0);
   set("SMS_WIDESCREEN_HUD", "edges", 0);   /* the HUD at the screen's edges, not a 4:3 frame's */
   set("SMS_CAMERA_SHAKE", "0", 0);          /* the quakes are strong on a large screen: off unless the menu says */
   set("SMS_GX_SCALE", "4.5", 0);
   set("SMS_VSYNC", "1", 0);
   /* DualSense buttons in the game's text and on the FLUDD gauge, when the title has their picture */
   if (stat("/app0/res/prompts/playstation.png", &status) == 0) {
      set("SMS_BUTTON_PROMPTS", "playstation", 0);
      set("SMS_BUTTON_PROMPT_DIR", "/app0/res/prompts", 0);
   }
}
