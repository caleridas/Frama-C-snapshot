/* Generated by Frama-C */
#include "stdio.h"
#include "stdlib.h"
typedef unsigned char uint8;
int main(void)
{
  int __retres;
  __e_acsl_memory_init((int *)0,(char ***)0,(size_t)8);
  uint8 x = (unsigned char)0;
  /*@ assert x ≡ 0; */
  __e_acsl_assert((int)x == 0,(char *)"Assertion",(char *)"main",
                  (char *)"x == 0",9);
  __retres = 0;
  return __retres;
}


