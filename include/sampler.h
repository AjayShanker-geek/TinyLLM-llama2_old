/**
 * @file sampler.h
 * @brief The Sampler, which takes logits and returns a sampled token sampling can be done in a few ways: greedy argmax,
 * sampling, top-p sampling
 */

#ifndef SAMPLER_H
#define SAMPLER_H

typedef struct
{
  float prob;
  int index;
} ProbIndex;// struct used when sorting probabilities during top-p sampling

typedef struct
{
  int vocab_size;
  ProbIndex *probindex;// buffer used in top-p sampling
  float temperature;
  float topp;
  unsigned long long rng_state;
} Sampler;

#endif// SAMPLER_H
