/*
 * Copyright (c) 2011 Tim Felgentreff, Philipp Tessenow
 * Copyright (c) 2006-2008 NVIDIA, Corporation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <X11/Xlib.h>
#include "NVCtrlLib.h"

#define CONFIG_FILE "nv-dpy-daemon.run"
#define MAX_DEVICES 5

static Bool setup(Display** dpy, int* screen);
static inline int GetNvXScreen(Display *dpy);
static char** identifier(Display* dpy, int display_device, int screen);

int main(int argc, char *argv[]) {
  Display *dpy;
  Bool ret;
  int screen, display_devices[2];
  char* environment = getenv("XDG_CONFIG_HOME");
  char* configuration;

  if (environment == NULL) {
    // no XDG_CONFIG_HOME set, default is $HOME/.config/
    environment = getenv("HOME");
    configuration = (char*)calloc(sizeof(char), strlen(environment)
				  + strlen(CONFIG_FILE)
				  + strlen("/.config/") + 1);
    strcpy(configuration, environment);
    strcat(configuration, "/.config/");
  } else {
    configuration = (char*)calloc(sizeof(char), strlen(environment)
				  + strlen(CONFIG_FILE) + 1);
  }
  strcat(configuration, CONFIG_FILE);
  printf("Using callback file %s\n", configuration);

  ret = setup(&dpy, &screen);
  if (!ret) {
    return 1;
  }

  ret = XNVCTRLQueryAttribute(dpy, screen, 0,
			      NV_CTRL_PROBE_DISPLAYS, &display_devices[0]);
  if (!ret) {
    fprintf(stderr, "Failed to query the enabled Display Devices.\n\n");
    return 1;
  }

  while (True) {
    usleep(2 * 1000 * 1000);
    /*
     * first, probe for new display devices; while
     * NV_CTRL_CONNECTED_DISPLAYS reports what the NVIDIA X driver
     * believes is currently connected to the GPU,
     * NV_CTRL_PROBE_DISPLAYS forces the driver to redetect what
     * is connected.
     */
    ret = XNVCTRLQueryAttribute(dpy, screen, 0,
				NV_CTRL_PROBE_DISPLAYS, &display_devices[0]);
    if (display_devices[0] != display_devices[1]) {
      display_devices[1] = display_devices[0];
      char** strs = identifier(dpy, display_devices[0], screen);
      strs[0] = configuration; // First argument is the executable, by convention
      if (fork() == 0) { // Child
	execv(configuration, strs);
	fprintf(stderr, "An error occured executing the daemon callback file\n");
	return 0;
      }
      int i = 1;
      while(strs[i] != NULL) {
#ifdef DEBUG
	printf("%d: \"%s\"\n", i, strs[i]);
#endif
	free(strs[i++]);
      }
    }
  }

  return 0;
}

/*****************************************************************************/
/* utility functions */
/*****************************************************************************/

static char** identifier(Display* dpy, int display_device, int screen) {
  char** identifier = (char**)calloc(sizeof(char*), MAX_DEVICES + 2);
  int mask, i = 1;
  Bool ret;
  for (mask = 1; mask < (1 << 24); mask <<= 1) {
    if (!(display_device & mask)) {
      continue;
    }
    char* str;
    ret = XNVCTRLQueryTargetStringAttribute(dpy, NV_CTRL_TARGET_TYPE_X_SCREEN, screen,
					    mask, NV_CTRL_STRING_DISPLAY_DEVICE_NAME,
					    &str);
    if (ret && i <= MAX_DEVICES) {
      identifier[i++] = str;
    }
  }
  return identifier;
}

/*
 * Open a display connection, and make sure the NV-CONTROL X
 * extension is present on the screen we want to use.
 */  
static Bool setup(Display** dpy, int* screen) {
  int major, minor;
  Bool ret;

  *dpy = XOpenDisplay(NULL);
  if (!(*dpy)) {
    fprintf(stderr, "Cannot open display '%s'.\n\n", XDisplayName(NULL));
    return False;
  }

  *screen = GetNvXScreen(*dpy);
  if (*screen == -1) {
    return False;
  }

  ret = XNVCTRLQueryVersion(*dpy, &major, &minor);
  if (ret != True) {
    fprintf(stderr, "The NV-CONTROL X extension does not exist "
	    "on '%s'.\n\n", XDisplayName(NULL));
    return False;
  }

  return True;
}

/*
 * nv-control-screen.h - trivial helper for NV-CONTROL sample clients: use
 * the default screen if it is an NVIDIA X screen.  If it isn't, then look
 * for the first NVIDIA X screen.  Abort if no NVIDIA X screens are found.
 */
static inline int GetNvXScreen(Display *dpy) {
  int defaultScreen, screen;

  defaultScreen = DefaultScreen(dpy);

  if (XNVCTRLIsNvScreen(dpy, defaultScreen)) {
    return defaultScreen;
  }

  for (screen = 0; screen < ScreenCount(dpy); screen++) {
    if (XNVCTRLIsNvScreen(dpy, screen)) {
      printf("Default X screen %d is not an NVIDIA X screen.  "
	     "Using X screen %d instead.\n",
	     defaultScreen, screen);
      return screen;
    }
  }

  fprintf(stderr, "Unable to find any NVIDIA X screens; aborting.\n");
  return -1;
}
