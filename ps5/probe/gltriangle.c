/*
 * Super Mario Sunshine for the PlayStation 5 - OpenGL as the game will use it.
 *
 * First the low-memory checks (memprobe.c), which leave 64 MiB at 0x20000000
 * and a pool at 0x40000000 mapped. Then an OpenGL 3.3 core context
 * at 3840x2160 through the PS5 OpenGL SDK's EGL, made on the main thread and
 * handed to a second thread whose stack is in the low pool, as the PC port
 * hands its context to a render thread. That thread draws a turning triangle
 * for five seconds and counts the frames.
 *
 * SPDX-License-Identifier: MIT
 */
#include <math.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GL/gl.h>
#include <ps5_opengl_display_modes.h>

#include "platform.h"

#define PROBE_NO_MAIN
#include "memprobe.c"

static EGLDisplay display;
static EGLSurface surface;
static EGLContext context;

static GLuint
compile_shader(GLenum type, const char *source)
{
   GLint compiled = GL_FALSE;
   GLuint shader = glCreateShader(type);

   glShaderSource(shader, 1, &source, NULL);
   glCompileShader(shader);
   glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
   if (!compiled) {
      char log[512];
      GLsizei length = 0;
      glGetShaderInfoLog(shader, sizeof(log), &length, log);
      say("shader compile failed: %.*s", length, log);
      return 0;
   }
   return shader;
}

static void *
render_thread(void *argument)
{
   static const char *vertex_source =
      "#version 330 core\n"
      "layout(location=0) in vec2 position;\n"
      "uniform float angle;\n"
      "void main() {\n"
      "   float c = cos(angle), s = sin(angle);\n"
      "   gl_Position = vec4((c * position.x - s * position.y) * 9.0 / 16.0, s * position.x + c * position.y, 0.0, 1.0);\n"
      "}\n";
   static const char *fragment_source =
      "#version 330 core\n"
      "layout(location=0) out vec4 color;\n"
      "void main() { color = vec4(1.0, 0.8, 0.1, 1.0); }\n";
   static const GLfloat vertices[] = { -0.5f, -0.5f, 0.5f, -0.5f, 0.0f, 0.6f };
   int local = 0;

   (void)argument;
   say("render thread: a local at %p", (void *)&local);
   if (!eglMakeCurrent(display, surface, surface, context)) {
      say("render thread: eglMakeCurrent failed, EGL error %#x", eglGetError());
      return NULL;
   }
   say("GL_VERSION %s", (const char *)glGetString(GL_VERSION));
   say("GL_RENDERER %s", (const char *)glGetString(GL_RENDERER));
   say("GLSL %s", (const char *)glGetString(GL_SHADING_LANGUAGE_VERSION));
   GLint value = 0;
   glGetIntegerv(GL_MAX_TEXTURE_SIZE, &value);
   say("GL_MAX_TEXTURE_SIZE %d", value);
   glGetIntegerv(GL_MAX_SAMPLES, &value);
   say("GL_MAX_SAMPLES %d", value);

   GLuint program = glCreateProgram();
   GLuint vertex = compile_shader(GL_VERTEX_SHADER, vertex_source);
   GLuint fragment = compile_shader(GL_FRAGMENT_SHADER, fragment_source);
   GLint linked = GL_FALSE;
   glAttachShader(program, vertex);
   glAttachShader(program, fragment);
   glLinkProgram(program);
   glGetProgramiv(program, GL_LINK_STATUS, &linked);
   say("program linked: %d", linked);
   GLint angle = glGetUniformLocation(program, "angle");

   GLuint array = 0, buffer = 0;
   glGenVertexArrays(1, &array);
   glBindVertexArray(array);
   glGenBuffers(1, &buffer);
   glBindBuffer(GL_ARRAY_BUFFER, buffer);
   glBufferData(GL_ARRAY_BUFFER, sizeof vertices, vertices, GL_STATIC_DRAW);
   glEnableVertexAttribArray(0);
   glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, NULL);
   say("buffer map check: a mapped buffer is at %p", glMapBuffer(GL_ARRAY_BUFFER, GL_READ_ONLY));
   glUnmapBuffer(GL_ARRAY_BUFFER);

   EGLint width = 0, height = 0;
   eglQuerySurface(display, surface, EGL_WIDTH, &width);
   eglQuerySurface(display, surface, EGL_HEIGHT, &height);
   say("surface %dx%d", width, height);
   glViewport(0, 0, width, height);
   glUseProgram(program);

   double start = now_seconds(), last = start;
   int frames = 0, total = 0;
   while (now_seconds() - start < 5.0) {
      double now = now_seconds();
      glClearColor(0.1f, 0.45f, 0.85f, 1.0f);
      glClear(GL_COLOR_BUFFER_BIT);
      glUniform1f(angle, (float)(now - start));
      glDrawArrays(GL_TRIANGLES, 0, 3);
      if (!eglSwapBuffers(display, surface)) {
         say("eglSwapBuffers failed, EGL error %#x", eglGetError());
         break;
      }
      frames++;
      total++;
      if (now - last >= 1.0) {
         say("%d frames in %.2f s", frames, now - last);
         frames = 0;
         last = now;
      }
   }
   uint8_t pixel[4] = { 0 };
   glReadPixels(width / 2, height / 2, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixel);
   say("%d frames in all, GL error %#x, the centre pixel is %d,%d,%d,%d", total, glGetError(), pixel[0], pixel[1],
       pixel[2], pixel[3]);
   eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
   return (void *)1;
}

int
main(void)
{
   static const EGLint config_attributes[] = {
      EGL_SURFACE_TYPE, EGL_WINDOW_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
      EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
      EGL_DEPTH_SIZE, 24, EGL_NONE,
   };
   static const EGLint context_attributes[] = {
      EGL_CONTEXT_MAJOR_VERSION_KHR, 3, EGL_CONTEXT_MINOR_VERSION_KHR, 3,
      EGL_CONTEXT_OPENGL_PROFILE_MASK_KHR, EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT_KHR, EGL_NONE,
   };
   EGLConfig config;
   EGLint count = 0, major = 0, minor = 0;
   int status = 1;

   platform_init("Sunshine");
   memprobe();

   say("gltriangle: start");
   display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
   say("eglSetDisplayModePS5(3840x2160) %d, refresh 60 %d", eglSetDisplayModePS5(display, 3840, 2160),
       eglSetDisplayRefreshPS5(display, 60));
   if (!eglInitialize(display, &major, &minor)) {
      say("eglInitialize failed, EGL error %#x", eglGetError());
      goto out;
   }
   say("EGL %d.%d", major, minor);
   if (!eglBindAPI(EGL_OPENGL_API) || !eglChooseConfig(display, config_attributes, &config, 1, &count) || count != 1) {
      say("no EGL config, EGL error %#x", eglGetError());
      goto out;
   }
   surface = eglCreateWindowSurface(display, config, (EGLNativeWindowType)0, NULL);
   context = eglCreateContext(display, config, EGL_NO_CONTEXT, context_attributes);
   if (surface == EGL_NO_SURFACE || context == EGL_NO_CONTEXT) {
      say("no surface or context, EGL error %#x", eglGetError());
      goto out;
   }
   /* Current here first, then let go, as the port does before its render thread takes it */
   say("eglMakeCurrent on the main thread: %d", eglMakeCurrent(display, surface, surface, context));
   say("eglSwapInterval(1): %d", eglSwapInterval(display, 1));
   eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);

   pthread_attr_t attributes;
   pthread_t thread;
   void *result = NULL;
   pthread_attr_init(&attributes);
   if (memprobe_pool)
      pthread_attr_setstack(&attributes, (char *)memprobe_pool + (16u << 20), 8u << 20);
   if (pthread_create(&thread, &attributes, render_thread, NULL) == 0)
      pthread_join(thread, &result);
   status = result ? 0 : 1;
   void *heap = malloc(1 << 20);
   say("after OpenGL: malloc(1 MiB) %p", heap);
out:
   say("gltriangle: done");
   say("exit status %d", status);
   catchReturnFromMain(status);
   return status;
}
