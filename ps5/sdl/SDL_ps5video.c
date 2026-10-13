/*
 * Super Mario Sunshine for the PlayStation 5 - SDL2's video driver for the console.
 *
 * The console has one output and no windows: this gives SDL one display and
 * lets it keep its window bookkeeping (size, flags, events) for a window that
 * is the whole screen. Its OpenGL calls answer for the console: the "library"
 * is the PS5 OpenGL SDK, linked into the title, whose EGL has one window
 * surface, the screen (native window 0). One window, one context.
 *
 * The display's size is what the SDK is asked to present at before EGL starts:
 * 3840x2160 unless SDL_PS5_DISPLAY=WIDTHxHEIGHT in the environment says
 * 2560x1440 or 1920x1080. The console scales it to what the television takes.
 *
 * The context may be made current on any one thread at a time: the game hands
 * it from the thread that made the window to its render thread.
 *
 * After the Vulkan driver of the Ghostship port, and the EGL sequence of the
 * SDK's own SDL2 bridge (integration/SDL2/SDL_ps5g19.c).
 * SPDX-License-Identifier: Zlib
 */
#include "SDL_internal.h"

#ifdef SDL_VIDEO_DRIVER_PS5

#include "video/SDL_sysvideo.h"
#include "events/SDL_events_c.h"
#include "events/SDL_keyboard_c.h"
#include "events/SDL_mouse_c.h"

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <ps5_opengl_display_modes.h>

#include "platform.h"

static EGLDisplay ps5_display = EGL_NO_DISPLAY;
static EGLConfig ps5_config;
static EGLSurface ps5_surface = EGL_NO_SURFACE;
static EGLContext ps5_context = EGL_NO_CONTEXT;
static SDL_Window *ps5_window;
static int ps5_interval = 1;

static int PS5_EGLError(const char *operation)
{
    return SDL_SetError("PS5 %s: EGL error 0x%04x", operation, (unsigned)eglGetError());
}

static int PS5_VideoInit(_THIS)
{
    SDL_DisplayMode mode;
    int w = 3840, h = 2160;
    const char *size = SDL_getenv("SDL_PS5_DISPLAY");

    if (size && SDL_sscanf(size, "%dx%d", &w, &h) == 2 &&
        ((w == 3840 && h == 2160) || (w == 2560 && h == 1440) || (w == 1920 && h == 1080))) {
        say("video: %dx%d from SDL_PS5_DISPLAY", w, h);
    } else {
        w = 3840;
        h = 2160;
    }
    ps5_display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (ps5_display == EGL_NO_DISPLAY) {
        return PS5_EGLError("eglGetDisplay");
    }
    if (!eglSetDisplayModePS5(ps5_display, w, h) || !eglSetDisplayRefreshPS5(ps5_display, 60)) {
        say("video: the output stays at the SDK's default, EGL error 0x%04x", (unsigned)eglGetError());
        w = 1920;
        h = 1080;
    }
    if (!eglInitialize(ps5_display, NULL, NULL)) {
        ps5_display = EGL_NO_DISPLAY;
        return PS5_EGLError("eglInitialize");
    }
    say("video: OpenGL presents at %dx%d", w, h);
    SDL_zero(mode);
    mode.format = SDL_PIXELFORMAT_ABGR8888;
    mode.w = w;
    mode.h = h;
    mode.refresh_rate = 60;
    if (SDL_AddBasicVideoDisplay(&mode) < 0) {
        return -1;
    }
    return 0;
}

static int PS5_SetDisplayMode(_THIS, SDL_VideoDisplay *display, SDL_DisplayMode *mode)
{
    return 0; /* the output stays as it is */
}

static void PS5_VideoQuit(_THIS)
{
    if (ps5_display == EGL_NO_DISPLAY) {
        return;
    }
    eglMakeCurrent(ps5_display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    if (ps5_context != EGL_NO_CONTEXT) {
        eglDestroyContext(ps5_display, ps5_context);
        ps5_context = EGL_NO_CONTEXT;
    }
    if (ps5_surface != EGL_NO_SURFACE) {
        eglDestroySurface(ps5_display, ps5_surface);
        ps5_surface = EGL_NO_SURFACE;
    }
    eglTerminate(ps5_display);
    ps5_display = EGL_NO_DISPLAY;
}

static void PS5_PumpEvents(_THIS)
{
}

static int PS5_CreateWindow(_THIS, SDL_Window *window)
{
    if (window->flags & SDL_WINDOW_OPENGL) {
        const EGLint attributes[] = {
            EGL_SURFACE_TYPE, EGL_WINDOW_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
            EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
            EGL_DEPTH_SIZE, _this->gl_config.depth_size,
            EGL_STENCIL_SIZE, _this->gl_config.stencil_size, EGL_NONE
        };
        EGLint count = 0, width = 0, height = 0;

        if (ps5_window) {
            return SDL_SetError("PS5: one OpenGL window, the screen");
        }
        if (!eglChooseConfig(ps5_display, attributes, &ps5_config, 1, &count) || count != 1) {
            return PS5_EGLError("eglChooseConfig");
        }
        ps5_surface = eglCreateWindowSurface(ps5_display, ps5_config, (EGLNativeWindowType)0, NULL);
        if (ps5_surface == EGL_NO_SURFACE) {
            return PS5_EGLError("eglCreateWindowSurface");
        }
        ps5_window = window;
        if (eglQuerySurface(ps5_display, ps5_surface, EGL_WIDTH, &width) &&
            eglQuerySurface(ps5_display, ps5_surface, EGL_HEIGHT, &height)) {
            say("video: the screen's surface is %dx%d", (int)width, (int)height);
        }
    }
    /* The window is the screen, and always has the pad's focus */
    SDL_SetKeyboardFocus(window);
    SDL_SetMouseFocus(window);
    return 0;
}

static void PS5_DestroyWindow(_THIS, SDL_Window *window)
{
    if (window != ps5_window) {
        return;
    }
    ps5_window = NULL;
    eglMakeCurrent(ps5_display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    if (ps5_surface != EGL_NO_SURFACE) {
        eglDestroySurface(ps5_display, ps5_surface);
        ps5_surface = EGL_NO_SURFACE;
    }
}

static void PS5_SetWindowPosition(_THIS, SDL_Window *window)
{
}

static void PS5_SetWindowSize(_THIS, SDL_Window *window)
{
    /* The size stays the display's */
}

static void PS5_SetWindowFullscreen(_THIS, SDL_Window *window, SDL_VideoDisplay *display, SDL_bool fullscreen)
{
}

static int PS5_GL_LoadLibrary(_THIS, const char *path)
{
    return 0; /* linked into the title */
}

static void PS5_GL_UnloadLibrary(_THIS)
{
}

static void *PS5_GL_GetProcAddress(_THIS, const char *name)
{
    return (void *)eglGetProcAddress(name);
}

static int PS5_GL_MakeCurrent(_THIS, SDL_Window *window, SDL_GLContext context)
{
    EGLSurface surface = context ? ps5_surface : EGL_NO_SURFACE;

    if (!eglMakeCurrent(ps5_display, surface, surface, context ? (EGLContext)context : EGL_NO_CONTEXT)) {
        return PS5_EGLError("eglMakeCurrent");
    }
    return 0;
}

static SDL_GLContext PS5_GL_CreateContext(_THIS, SDL_Window *window)
{
    const int core = _this->gl_config.profile_mask == SDL_GL_CONTEXT_PROFILE_CORE;
    const EGLint attributes[] = {
        EGL_CONTEXT_MAJOR_VERSION_KHR, _this->gl_config.major_version,
        EGL_CONTEXT_MINOR_VERSION_KHR, _this->gl_config.minor_version,
        EGL_CONTEXT_OPENGL_PROFILE_MASK_KHR,
        core ? EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT_KHR : EGL_CONTEXT_OPENGL_COMPATIBILITY_PROFILE_BIT_KHR,
        EGL_NONE
    };

    if (window != ps5_window || ps5_context != EGL_NO_CONTEXT) {
        SDL_SetError("PS5: one OpenGL context, for the screen's window");
        return NULL;
    }
    if (!eglBindAPI(EGL_OPENGL_API)) {
        PS5_EGLError("eglBindAPI");
        return NULL;
    }
    ps5_context = eglCreateContext(ps5_display, ps5_config, EGL_NO_CONTEXT, attributes);
    if (ps5_context == EGL_NO_CONTEXT) {
        PS5_EGLError("eglCreateContext");
        return NULL;
    }
    if (PS5_GL_MakeCurrent(_this, window, (SDL_GLContext)ps5_context) < 0) {
        eglDestroyContext(ps5_display, ps5_context);
        ps5_context = EGL_NO_CONTEXT;
        return NULL;
    }
    say("video: OpenGL %d.%d %s context", _this->gl_config.major_version, _this->gl_config.minor_version,
        core ? "core" : "compatibility");
    return (SDL_GLContext)ps5_context;
}

static void PS5_GL_DeleteContext(_THIS, SDL_GLContext context)
{
    if (context && (EGLContext)context == ps5_context) {
        eglDestroyContext(ps5_display, ps5_context);
        ps5_context = EGL_NO_CONTEXT;
    }
}

static int PS5_GL_SetSwapInterval(_THIS, int interval)
{
    if (interval < 0) {
        return SDL_SetError("PS5: no adaptive vsync");
    }
    if (!eglSwapInterval(ps5_display, interval ? 1 : 0)) {
        return PS5_EGLError("eglSwapInterval");
    }
    ps5_interval = interval ? 1 : 0;
    return 0;
}

static int PS5_GL_GetSwapInterval(_THIS)
{
    return ps5_interval;
}

static int PS5_GL_SwapWindow(_THIS, SDL_Window *window)
{
    return eglSwapBuffers(ps5_display, ps5_surface) ? 0 : PS5_EGLError("eglSwapBuffers");
}

static void PS5_DeleteDevice(_THIS)
{
    SDL_free(_this);
}

static SDL_VideoDevice *PS5_CreateDevice(void)
{
    SDL_VideoDevice *device = (SDL_VideoDevice *)SDL_calloc(1, sizeof(SDL_VideoDevice));
    if (!device) {
        SDL_OutOfMemory();
        return NULL;
    }
    device->VideoInit = PS5_VideoInit;
    device->VideoQuit = PS5_VideoQuit;
    device->SetDisplayMode = PS5_SetDisplayMode;
    device->PumpEvents = PS5_PumpEvents;
    device->CreateSDLWindow = PS5_CreateWindow;
    device->DestroyWindow = PS5_DestroyWindow;
    device->SetWindowPosition = PS5_SetWindowPosition;
    device->SetWindowSize = PS5_SetWindowSize;
    device->SetWindowFullscreen = PS5_SetWindowFullscreen;
    device->GL_LoadLibrary = PS5_GL_LoadLibrary;
    device->GL_UnloadLibrary = PS5_GL_UnloadLibrary;
    device->GL_GetProcAddress = PS5_GL_GetProcAddress;
    device->GL_CreateContext = PS5_GL_CreateContext;
    device->GL_MakeCurrent = PS5_GL_MakeCurrent;
    device->GL_DeleteContext = PS5_GL_DeleteContext;
    device->GL_SetSwapInterval = PS5_GL_SetSwapInterval;
    device->GL_GetSwapInterval = PS5_GL_GetSwapInterval;
    device->GL_SwapWindow = PS5_GL_SwapWindow;
    device->free = PS5_DeleteDevice;
    device->quirk_flags = VIDEO_DEVICE_QUIRK_FULLSCREEN_ONLY;
    return device;
}

VideoBootStrap PS5_bootstrap = {
    "ps5", "PlayStation 5 video driver",
    PS5_CreateDevice,
    NULL /* no ShowMessageBox implementation */
};

#endif /* SDL_VIDEO_DRIVER_PS5 */
