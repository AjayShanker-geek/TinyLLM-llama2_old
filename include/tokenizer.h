/**
 * @file tokenizer.h
 * @brief Byte Pair Encoding (BPE) tokenizer shared by all builds, translates strings <-> tokens.
 **/

#ifndef TOKENIZER_H
#define TOKENIZER_H

#include <stdint.h>

typedef struct
{
  char *str;
  int id;
} TokenIndex;

typedef struct
{
  char **vocab;
  float *vocab_scores;
  TokenIndex *sorted_vocab;
  int vocab_size;
  unsigned int max_token_length;
  unsigned char byte_pieces[512];// stores all single-byte strings
} Tokenizer;

void build_tokenizer(Tokenizer *t, char *tokenizer_path, int vocab_size);
void free_tokenizer(Tokenizer *t);
char *decode(Tokenizer *t, int prev_token, int token);
void safe_printf(char *piece);
int str_lookup(char *str, TokenIndex *sorted_vocab, int vocab_size);
void encode(Tokenizer *t, char *text, int8_t bos, int8_t eos, int *tokens, int *n_tokens);

#endif// TOKENIZER_H
