/**
 * @file util.c
 * @brief Timing and stdin helpers shared by all builds.
 **/

#ifndef _WIN32
#define _POSIX_C_SOURCE 200809L// clock_gettime under strict -std=c23
#endif

#include <stdio.h>
#include <string.h>
#include <time.h>
#if defined _WIN32
#include <windows.h>
#endif

#include "util.h"


void read_stdin(const char *guide, char *buffer, size_t bufsize)
{
  printf("%s", guide);
  if (fgets(buffer, (int)bufsize, stdin) != NULL) {
    size_t len = strlen(buffer);
    if (len > 0 && buffer[len - 1] == '\n') {
      buffer[len - 1] = '\0';// strip newline
    }
  }
}

// ----------------------------------------------------------------------------
// utilities: time

long time_in_ms()
{
  // return time in milliseconds, for benchmarking the model speed
  struct timespec time;
  clock_gettime(CLOCK_REALTIME, &time);
  return time.tv_sec * 1000 + time.tv_nsec / 1000000;
}
