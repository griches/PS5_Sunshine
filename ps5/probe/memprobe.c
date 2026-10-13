/*
 * Super Mario Sunshine for the PlayStation 5 - what the console gives a title
 * below 4 GiB.
 *
 * The PC port keeps every address the game can see in 32 bits: its memory at
 * 0x80000000, thread stacks and a few buffers below 2 GiB, statics in the
 * executable. This title asks the console for each of those and says what it
 * got, then leaves.
 *
 * SPDX-License-Identifier: MIT
 */
#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <ucontext.h>
#include <unistd.h>

#include "platform.h"

void catchReturnFromMain(int status);

static int static_data = 1;
static char static_bss[4096];

static const char *
flag_names(int flags)
{
   static char text[96];

   text[0] = 0;
   if (flags & MAP_FIXED)
      strcat(text, "FIXED ");
#ifdef MAP_EXCL
   if (flags & MAP_EXCL)
      strcat(text, "EXCL ");
#endif
#ifdef MAP_32BIT
   if (flags & MAP_32BIT)
      strcat(text, "32BIT ");
#endif
   if (!text[0])
      strcat(text, "hint ");
   return text;
}

/* Map, write every page, read it back, and (unless kept) unmap. */
static void *
try_map(uintptr_t want, size_t size, int flags, int keep)
{
   void *p = mmap((void *)want, size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON | flags, -1, 0);

   if (p == MAP_FAILED) {
      say("mmap %#zx at %#lx %s-> failed, errno %d (%s)", size, (unsigned long)want, flag_names(flags), errno,
          strerror(errno));
      return NULL;
   }
   volatile uint8_t *bytes = p;
   size_t bad = 0;
   for (size_t at = 0; at < size; at += 4096)
      bytes[at] = (uint8_t)(at >> 12);
   for (size_t at = 0; at < size; at += 4096)
      bad += bytes[at] != (uint8_t)(at >> 12);
   say("mmap %#zx at %#lx %s-> %p%s, %zu bad pages", size, (unsigned long)want, flag_names(flags), p,
       (uintptr_t)p == want ? " (as asked)" : "", bad);
   if (!keep)
      munmap(p, size);
   return p;
}

static void *
low_thread(void *argument)
{
   volatile char local[256];

   local[0] = 1;
   say("thread: a local at %p, argument %p", (void *)local, argument);
   uintptr_t where = (uintptr_t)local;
   return (void *)where;
}

static volatile int fault_seen;
static volatile uintptr_t fault_address;

static void
on_fault(int number, siginfo_t *info, void *context)
{
   ucontext_t *uc = context;

   (void)number;
   fault_seen = 1;
   fault_address = (uintptr_t)info->si_addr;
   /* step over the faulting store: mov %al,(%rdx) is two bytes */
   uc->uc_mcontext.mc_rip += 2;
}

/* The pool below 2 GiB that memprobe leaves mapped, for a caller's own low stacks */
void *memprobe_pool;

#ifdef PROBE_NO_MAIN
int
memprobe(void)
#else
int
main(void)
#endif
{
   int local = 0;

#ifndef PROBE_NO_MAIN
   platform_init("Sunshine");
#endif
   say("memprobe: start");
   void *heap = malloc(1 << 20);
   say("code %p, static data %p, bss %p, stack local %p, malloc(1 MiB) %p", (void *)(uintptr_t)low_thread,
       (void *)&static_data, (void *)static_bss, (void *)&local, heap);
#ifdef MAP_32BIT
   say("MAP_32BIT is %#x", MAP_32BIT);
#else
   say("MAP_32BIT is not defined");
#endif
#ifdef MAP_EXCL
   say("MAP_EXCL is %#x", MAP_EXCL);
#endif

   /* The game's memory: 64 MiB. Never MAP_FIXED: the console's kernel does not
    * honour MAP_EXCL, and the title's own libc.prx is mapped at 0x80000000 (the
    * first run of this probe replaced it and the title died in libc). A hint is
    * taken when the range is free. */
   const size_t mem1 = 64u << 20;
   try_map(0x80000000u, mem1, 0, 0);
   void *game = try_map(0x20000000u, mem1, 0, 1);

   /* Anything below 2 GiB, as the port's low allocator asks */
#ifdef MAP_32BIT
   try_map(0, 8u << 20, MAP_32BIT, 0);
#endif
   for (uintptr_t at = 0x10000000u; at < 0x80000000u; at += 0x10000000u)
      try_map(at, 8u << 20, 0, 0);
   /* ... and between 2 and 4 GiB */
   for (uintptr_t at = 0x90000000u; at < 0xF0000001u; at += 0x20000000u)
      try_map(at, 8u << 20, 0, 0);
   /* A large block low down: the stacks' pool, 128 MiB */
   void *pool = try_map(0x40000000u, 128u << 20, 0, 1);
   if ((uintptr_t)pool != 0x40000000u)
      pool = NULL;

   /* A thread on a stack below 2 GiB */
   if (pool) {
      pthread_attr_t attributes;
      pthread_t thread;
      void *result = NULL;

      pthread_attr_init(&attributes);
      int set = pthread_attr_setstack(&attributes, pool, 8u << 20);
      int made = pthread_create(&thread, &attributes, low_thread, pool);
      if (!made)
         pthread_join(thread, &result);
      say("low stack %p..%p: setstack %d, create %d, the thread's local %p (%s)", pool,
          (void *)((char *)pool + (8u << 20)), set, made, result,
          (uintptr_t)result >= (uintptr_t)pool && (uintptr_t)result < (uintptr_t)pool + (8u << 20)
             ? "inside" : "OUTSIDE");
   }

   /* A fault handler that reads the context and resumes, as the port's does */
   if (game) {
      struct sigaction action;

      memset(&action, 0, sizeof action);
      action.sa_sigaction = on_fault;
      action.sa_flags = SA_SIGINFO;
      int installed = sigaction(SIGSEGV, &action, NULL) | sigaction(SIGBUS, &action, NULL);
      int protect = mprotect(game, 4096, PROT_READ);
      volatile uint8_t *target = game;
      if (!protect)
         __asm__ volatile("movb %%al, (%%rdx)" : : "a"(1), "d"(target) : "memory");
      say("fault handler: sigaction %d, mprotect %d, fault seen %d at %#lx", installed, protect, fault_seen,
          (unsigned long)fault_address);
      mprotect(game, 4096, PROT_READ | PROT_WRITE);
   }

   memprobe_pool = pool;
   say("memprobe: done");
#ifndef PROBE_NO_MAIN
   say("exit status 0");
   catchReturnFromMain(0);
#endif
   return 0;
}
