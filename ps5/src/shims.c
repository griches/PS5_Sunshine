/*
 * Super Mario Sunshine for the PlayStation 5 - libc names no module a title loads exports.
 *
 * The SDK's stubs let these link, but the import is null at run time and its
 * first call jumps to address 0. tools/link-title.sh binds each name to its
 * ps5dl_ answer here (its `shims` list must name every function below).
 *
 * SPDX-License-Identifier: MIT
 */
#include <errno.h>

/* Nothing a title writes to is a terminal: its output goes to klog. */
int
ps5dl_isatty(int fd)
{
   (void)fd;
   errno = ENOTTY;
   return 0;
}

/* One user, and no privilege to drop (SDL asks whether the process is setuid). */
int
ps5dl_getresuid(unsigned *real, unsigned *effective, unsigned *saved)
{
   *real = *effective = *saved = 0;
   return 0;
}

int
ps5dl_getresgid(unsigned *real, unsigned *effective, unsigned *saved)
{
   *real = *effective = *saved = 0;
   return 0;
}

/* No list of loaded modules to walk (Borealis's crash report names the module
 * of each frame with it): it reports addresses, which run-title.py symbolises. */
int
ps5dl_dl_iterate_phdr(int (*callback)(void *, unsigned long, void *), void *data)
{
   (void)callback;
   (void)data;
   return 0;
}

/* Files belong to no one in particular. */
int
ps5dl_fchown(int fd, unsigned owner, unsigned group)
{
   (void)fd;
   (void)owner;
   (void)group;
   return 0;
}

/* A title is one process: nothing can be started from it (SDL's process API,
 * Borealis's "restart" and "open a URL"). */
int
ps5dl_fork(void)
{
   errno = ENOSYS;
   return -1;
}

int
ps5dl_vfork(void)
{
   errno = ENOSYS;
   return -1;
}

int
ps5dl_execlp(const char *file, const char *argument, ...)
{
   (void)file;
   (void)argument;
   errno = ENOSYS;
   return -1;
}

int
ps5dl_setsid(void)
{
   errno = ENOSYS;
   return -1;
}

/* FreeBSD's _PC_NAME_MAX and _PC_PATH_MAX; no other limit is known. */
long
ps5dl_pathconf(const char *path, int name)
{
   (void)path;
   switch (name) {
   case 4:
      return 255;
   case 5:
      return 1024;
   default:
      errno = EINVAL;
      return -1;
   }
}

/* The network is not used: addresses have no names. */
int
ps5dl_getnameinfo(const void *address, unsigned length, char *host, unsigned host_size, char *service,
                  unsigned service_size, int flags)
{
   (void)address;
   (void)length;
   (void)host;
   (void)host_size;
   (void)service;
   (void)service_size;
   (void)flags;
   return 4; /* EAI_FAIL */
}

const char *
ps5dl_gai_strerror(int code)
{
   (void)code;
   return "name resolution is not available";
}

/* lstat does not work for a title (anything but a missing file's ENOENT made
 * std::filesystem::symlink_status report an occupied path, so Aurora refused to
 * create the memory card's save, and SQLite refused to open its databases). A
 * title's folders hold no symbolic links: stat answers the same. */
struct stat;
int stat(const char *path, struct stat *out);

int
ps5dl_lstat(const char *path, struct stat *out)
{
   return stat(path, out);
}

/* No /tmp for a title: a scratch file in its own folder, gone when it is closed. */
#include <stdio.h>
#include <unistd.h>

FILE *
ps5dl_tmpfile(void)
{
   static int serial;
   char path[64];
   snprintf(path, sizeof path, "/app0/userdata/.tmp-%d", __atomic_fetch_add(&serial, 1, __ATOMIC_RELAXED));
   FILE *file = fopen(path, "w+");
   if (file)
      unlink(path);
   return file;
}

/* ------------------------------------------------------------------ the clock
 * clock_gettime is a system call on the console (about a microsecond: a sampled
 * render thread spent a fifth of its busy time in it, for the runtime's own
 * profiler, which timestamps every operation and is "cheap enough to stay on"
 * where the clock is read in user space). The monotonic clocks are served here
 * from the CPU's timestamp counter instead: anchored to the kernel's clock,
 * anchored again once a second (so a deadline computed from this clock and
 * handed to the kernel, as a timed wait is, stays within microseconds), with
 * the counter's rate measured between anchors, and never going backwards.
 * Every other clock is the kernel's.
 *
 * This belongs in the platform layer (PS5_PayloadSDK), for every title: it is
 * here until it is there. */
#include <stdatomic.h>
#include <stdint.h>
#include <time.h>

int sceKernelClockGettime(int clock, struct timespec *out);
uint64_t sceKernelGetTscFrequency(void);

#define PS5_CLOCK_MONOTONIC 4
#define PS5_CLOCK_MONOTONIC_PRECISE 11
#define PS5_CLOCK_MONOTONIC_FAST 12

static _Atomic uint32_t clock_sequence;      /* odd while an anchor is being written */
static atomic_flag clock_anchoring = ATOMIC_FLAG_INIT;
static uint64_t clock_anchor_tsc, clock_anchor_ns, clock_anchor_kernel_ns, clock_rate;
static _Atomic uint64_t clock_next_anchor;   /* in counter ticks; 0 before the first */
static _Atomic uint64_t clock_last_ns;

static uint64_t
clock_kernel_ns(void)
{
   struct timespec t;
   sceKernelClockGettime(PS5_CLOCK_MONOTONIC, &t);
   return (uint64_t)t.tv_sec * 1000000000ull + (uint64_t)t.tv_nsec;
}

static void
clock_anchor(void)
{
   if (atomic_flag_test_and_set(&clock_anchoring))
      return; /* another thread is at it */
   const uint64_t kernel = clock_kernel_ns();
   const uint64_t tsc = __builtin_ia32_rdtsc();
   uint64_t rate = clock_rate ? clock_rate : sceKernelGetTscFrequency();
   uint64_t now = kernel;
   if (clock_anchor_tsc) {
      const uint64_t ticks = tsc - clock_anchor_tsc, ns = kernel - clock_anchor_kernel_ns;
      if (ns > 500000000ull) {
         /* the counter's rate as the kernel's clock saw it; a wild value (a counter that
          * differs between cores) is not taken */
         const uint64_t measured = (uint64_t)((unsigned __int128)ticks * 1000000000ull / ns);
         if (measured > rate - rate / 100 && measured < rate + rate / 100)
            rate = measured;
      }
      const uint64_t estimate = clock_anchor_ns + (uint64_t)((unsigned __int128)ticks * 1000000000ull / clock_rate);
      if (estimate > now)
         now = estimate; /* never backwards: the kernel's clock catches up */
   }
   atomic_fetch_add(&clock_sequence, 1);
   clock_anchor_tsc = tsc;
   clock_anchor_ns = now;
   clock_anchor_kernel_ns = kernel;
   clock_rate = rate;
   atomic_fetch_add(&clock_sequence, 1);
   atomic_store(&clock_next_anchor, tsc + rate);
   atomic_flag_clear(&clock_anchoring);
}

int
ps5dl_clock_gettime(int clock, struct timespec *out)
{
   if (clock != PS5_CLOCK_MONOTONIC && clock != PS5_CLOCK_MONOTONIC_PRECISE && clock != PS5_CLOCK_MONOTONIC_FAST)
      return sceKernelClockGettime(clock, out) == 0 ? 0 : -1;
   uint64_t ns;
   for (;;) {
      const uint64_t tsc = __builtin_ia32_rdtsc();
      if (tsc >= atomic_load_explicit(&clock_next_anchor, memory_order_relaxed))
         clock_anchor();
      const uint32_t sequence = atomic_load(&clock_sequence);
      if (sequence & 1)
         continue;
      const uint64_t anchor_tsc = clock_anchor_tsc, anchor_ns = clock_anchor_ns, rate = clock_rate;
      if (atomic_load(&clock_sequence) != sequence || !rate)
         continue;
      const uint64_t ticks = tsc >= anchor_tsc ? tsc - anchor_tsc : 0;
      ns = anchor_ns + (uint64_t)((unsigned __int128)ticks * 1000000000ull / rate);
      break;
   }
   uint64_t last = atomic_load_explicit(&clock_last_ns, memory_order_relaxed);
   while (ns > last && !atomic_compare_exchange_weak(&clock_last_ns, &last, ns)) {
   }
   if (ns < last)
      ns = last;
   out->tv_sec = (time_t)(ns / 1000000000ull);
   out->tv_nsec = (long)(ns % 1000000000ull);
   return 0;
}

/* A title has no working directory: getcwd and realpath are refused (EPERM), and
 * std::filesystem's canonical, absolute and relative are built on them. The
 * title's own folder answers as the working directory, and a path is resolved
 * by its text, since a title's folders hold no symbolic links. */
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#define PS5_HOME "/app0"

char *
ps5dl_getcwd(char *buffer, size_t size)
{
   if (!buffer) {
      if (size == 0)
         size = 1024;
      buffer = malloc(size);
      if (!buffer)
         return NULL;
   }
   if (size < sizeof PS5_HOME) {
      errno = ERANGE;
      return NULL;
   }
   memcpy(buffer, PS5_HOME, sizeof PS5_HOME);
   return buffer;
}

char *
ps5dl_realpath(const char *path, char *resolved)
{
   char full[1024], out[1024];
   struct stat status;
   size_t length = 0;

   if (!path || !*path) {
      errno = path ? ENOENT : EINVAL;
      return NULL;
   }
   if ((size_t)snprintf(full, sizeof full, "%s%s", path[0] == '/' ? "" : PS5_HOME "/", path) >= sizeof full) {
      errno = ENAMETOOLONG;
      return NULL;
   }
   /* "." dropped, ".." takes the component before it, slashes once each */
   for (const char *part = full; *part;) {
      size_t size;
      while (*part == '/')
         part++;
      size = strcspn(part, "/");
      if (size == 2 && part[0] == '.' && part[1] == '.') {
         while (length > 0 && out[--length] != '/')
            ;
      } else if (size > 0 && !(size == 1 && part[0] == '.')) {
         out[length++] = '/';
         memcpy(out + length, part, size);
         length += size;
      }
      part += size;
   }
   if (length == 0)
      out[length++] = '/';
   out[length] = 0;
   if (stat(out, &status) != 0) {
      errno = ENOENT;
      return NULL;
   }
   if (!resolved) {
      resolved = malloc(1024);
      if (!resolved)
         return NULL;
   }
   memcpy(resolved, out, length + 1);
   return resolved;
}

/* No symbol names on the console (the port's draw trace asks for its callers'):
 * none, which its callers take as "no names". */
char **
ps5dl_backtrace_symbols(void *const *frames, int count)
{
   (void)frames;
   (void)count;
   return 0;
}

/* Standard output has nowhere to go in a title, and the platform layer's klog
 * capture is of the stream stderr alone. The OpenGL SDK's driver reports are
 * printed to standard output: tools/link-title.sh wraps the calls that write
 * there, and they write to stderr instead. */
#include <stdarg.h>

int
__wrap_vprintf(const char *format, va_list arguments)
{
   return vfprintf(stderr, format, arguments);
}

int
__wrap_printf(const char *format, ...)
{
   va_list arguments;
   va_start(arguments, format);
   const int written = vfprintf(stderr, format, arguments);
   va_end(arguments);
   return written;
}

int
__wrap_puts(const char *text)
{
   return fprintf(stderr, "%s\n", text);
}

int
__wrap_putchar(int character)
{
   return fputc(character, stderr);
}
