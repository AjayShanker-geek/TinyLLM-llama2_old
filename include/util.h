/**
 * @file util.h
 * @brief Timing and stdin helpers shared by all builds.
 **/

#ifndef UTIL_H
#define UTIL_H

#include <stddef.h>

// Monotonic wall-clock time, for benchmarking (unaffected by system clock changes)
// double time_in_seconds();
long time_in_ms();

// Read a line from stdin into buffer, up to but not including \n
void read_stdin(const char *guide, char *buffer, size_t bufsize);

#endif// UTIL_H
