/**
 * @file run_int8_BASELINE.h
 */

#ifndef RUN_INT8_BASELINE_H
#define RUN_INT8_BASELINE_H

#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef struct {
    int8_t *q;  // INT8 values
    float *s;   // group scales
} QuantizedTensor;

extern int GS;

void quantize(QuantizedTensor *qx, float *x, int n);
void dequantize(QuantizedTensor *qx, float *x, int n);
void matmul(float *out, QuantizedTensor *x,
            QuantizedTensor *w, int n, int d);

#endif// RUN_INT8_BASELINE_H
