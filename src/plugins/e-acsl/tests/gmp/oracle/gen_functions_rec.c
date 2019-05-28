/* Generated by Frama-C */
#include "stdio.h"
#include "stdlib.h"
/*@ logic ℤ f1(ℤ n) = n ≤ 0? 0: f1(n - 1) + n;
 */
/*@ logic ℤ f2(ℤ n) = n < 0? 1: (f2(n - 1) * f2(n - 2)) / f2(n - 3);
 */
int __gen_e_acsl_f2_2(long n);

int __gen_e_acsl_f2(int n);

/*@ logic ℤ g(ℤ n) = 0;
 */
int __gen_e_acsl_g_5(long n);

int __gen_e_acsl_g(int n);

/*@ logic ℤ f3(ℤ n) = n > 0? g(n) * f3(n - 1) - 5: g(n + 1);
 */
int __gen_e_acsl_f3_2(long n);

int __gen_e_acsl_f3(int n);

/*@
logic ℤ f4(ℤ n) =
  n < 100? f4(n + 1): (n < 0x7fffffffffffffffL? 0x7fffffffffffffffL: 6);

*/
unsigned long __gen_e_acsl_f4_2(long n);

unsigned long __gen_e_acsl_f4(int n);

int main(void)
{
  int __retres;
  __e_acsl_memory_init((int *)0,(char ***)0,(size_t)8);
  /*@ assert f2(7) ≡ 1; */
  {
    int __gen_e_acsl_f2_14;
    __gen_e_acsl_f2_14 = __gen_e_acsl_f2(7);
    __e_acsl_assert(__gen_e_acsl_f2_14 == 1,(char *)"Assertion",
                    (char *)"main",(char *)"f2(7) == 1",26);
  }
  /*@ assert f3(6) ≡ -5; */
  {
    int __gen_e_acsl_f3_6;
    __gen_e_acsl_f3_6 = __gen_e_acsl_f3(6);
    __e_acsl_assert(__gen_e_acsl_f3_6 == -5,(char *)"Assertion",
                    (char *)"main",(char *)"f3(6) == -5",28);
  }
  /*@ assert f4(9) > 0; */
  {
    unsigned long __gen_e_acsl_f4_6;
    __gen_e_acsl_f4_6 = __gen_e_acsl_f4(9);
    __e_acsl_assert(__gen_e_acsl_f4_6 > 0UL,(char *)"Assertion",
                    (char *)"main",(char *)"f4(9) > 0",30);
  }
  __retres = 0;
  return __retres;
}

unsigned long __gen_e_acsl_f4_2(long n)
{
  unsigned long __gen_e_acsl_if_6;
  if (n < 100L) {
    unsigned long __gen_e_acsl_f4_4;
    __gen_e_acsl_f4_4 = __gen_e_acsl_f4_2(n + 1L);
    __gen_e_acsl_if_6 = __gen_e_acsl_f4_4;
  }
  else {
    unsigned long __gen_e_acsl_if_5;
    if (n < 9223372036854775807L) __gen_e_acsl_if_5 = 9223372036854775807UL;
    else __gen_e_acsl_if_5 = 6UL;
    __gen_e_acsl_if_6 = __gen_e_acsl_if_5;
  }
  return __gen_e_acsl_if_6;
}

unsigned long __gen_e_acsl_f4(int n)
{
  unsigned long __gen_e_acsl_if_8;
  if (n < 100) {
    unsigned long __gen_e_acsl_f4_5;
    __gen_e_acsl_f4_5 = __gen_e_acsl_f4_2(n + 1L);
    __gen_e_acsl_if_8 = __gen_e_acsl_f4_5;
  }
  else {
    unsigned long __gen_e_acsl_if_7;
    if ((long)n < 9223372036854775807L) __gen_e_acsl_if_7 = 9223372036854775807UL;
    else __gen_e_acsl_if_7 = 6UL;
    __gen_e_acsl_if_8 = __gen_e_acsl_if_7;
  }
  return __gen_e_acsl_if_8;
}

int __gen_e_acsl_f2_2(long n)
{
  int __gen_e_acsl_if;
  if (n < 0L) __gen_e_acsl_if = 1;
  else {
    int __gen_e_acsl_f2_4;
    int __gen_e_acsl_f2_6;
    int __gen_e_acsl_f2_8;
    __gen_e_acsl_f2_4 = __gen_e_acsl_f2_2(n - 1L);
    __gen_e_acsl_f2_6 = __gen_e_acsl_f2_2(n - 2L);
    __gen_e_acsl_f2_8 = __gen_e_acsl_f2_2(n - 3L);
    __e_acsl_assert(__gen_e_acsl_f2_8 != 0,(char *)"RTE",(char *)"f2_2",
                    (char *)"division_by_zero: __gen_e_acsl_f2_8 != 0",10);
    /*@ assert Eva: division_by_zero: __gen_e_acsl_f2_8 ≢ 0; */
    /*@ assert
        Eva: signed_overflow:
          -2147483648 ≤ __gen_e_acsl_f2_4 * __gen_e_acsl_f2_6;
    */
    /*@ assert
        Eva: signed_overflow:
          __gen_e_acsl_f2_4 * __gen_e_acsl_f2_6 ≤ 2147483647;
    */
    /*@ assert
        Eva: signed_overflow:
          (int)(__gen_e_acsl_f2_4 * __gen_e_acsl_f2_6) / __gen_e_acsl_f2_8
          ≤ 2147483647;
    */
    __gen_e_acsl_if = (__gen_e_acsl_f2_4 * __gen_e_acsl_f2_6) / __gen_e_acsl_f2_8;
  }
  return __gen_e_acsl_if;
}

int __gen_e_acsl_f2(int n)
{
  int __gen_e_acsl_if_2;
  if (n < 0) __gen_e_acsl_if_2 = 1;
  else {
    int __gen_e_acsl_f2_9;
    int __gen_e_acsl_f2_11;
    int __gen_e_acsl_f2_13;
    __gen_e_acsl_f2_9 = __gen_e_acsl_f2_2(n - 1L);
    __gen_e_acsl_f2_11 = __gen_e_acsl_f2_2(n - 2L);
    __gen_e_acsl_f2_13 = __gen_e_acsl_f2_2(n - 3L);
    __e_acsl_assert(__gen_e_acsl_f2_13 != 0,(char *)"RTE",(char *)"f2",
                    (char *)"division_by_zero: __gen_e_acsl_f2_13 != 0",10);
    /*@ assert Eva: division_by_zero: __gen_e_acsl_f2_13 ≢ 0; */
    /*@ assert
        Eva: signed_overflow:
          -2147483648 ≤ __gen_e_acsl_f2_9 * __gen_e_acsl_f2_11;
    */
    /*@ assert
        Eva: signed_overflow:
          __gen_e_acsl_f2_9 * __gen_e_acsl_f2_11 ≤ 2147483647;
    */
    /*@ assert
        Eva: signed_overflow:
          (int)(__gen_e_acsl_f2_9 * __gen_e_acsl_f2_11) / __gen_e_acsl_f2_13
          ≤ 2147483647;
    */
    __gen_e_acsl_if_2 = (__gen_e_acsl_f2_9 * __gen_e_acsl_f2_11) / __gen_e_acsl_f2_13;
  }
  return __gen_e_acsl_if_2;
}

int __gen_e_acsl_g_5(long n)
{
  int __retres = 0;
  return __retres;
}

int __gen_e_acsl_g(int n)
{
  int __retres = 0;
  return __retres;
}

int __gen_e_acsl_f3_2(long n)
{
  int __gen_e_acsl_if_3;
  if (n > 0L) {
    int __gen_e_acsl_g_4;
    int __gen_e_acsl_f3_4;
    __gen_e_acsl_g_4 = __gen_e_acsl_g((int)n);
    __gen_e_acsl_f3_4 = __gen_e_acsl_f3_2(n - 1L);
    __gen_e_acsl_if_3 = __gen_e_acsl_g_4 * __gen_e_acsl_f3_4 - 5;
  }
  else {
    int __gen_e_acsl_g_6;
    __gen_e_acsl_g_6 = __gen_e_acsl_g_5(n + 1L);
    __gen_e_acsl_if_3 = __gen_e_acsl_g_6;
  }
  return __gen_e_acsl_if_3;
}

int __gen_e_acsl_f3(int n)
{
  int __gen_e_acsl_if_4;
  if (n > 0) {
    int __gen_e_acsl_g_2;
    int __gen_e_acsl_f3_5;
    __gen_e_acsl_g_2 = __gen_e_acsl_g(n);
    __gen_e_acsl_f3_5 = __gen_e_acsl_f3_2(n - 1L);
    __gen_e_acsl_if_4 = __gen_e_acsl_g_2 * __gen_e_acsl_f3_5 - 5;
  }
  else {
    int __gen_e_acsl_g_8;
    __gen_e_acsl_g_8 = __gen_e_acsl_g_5(n + 1L);
    __gen_e_acsl_if_4 = __gen_e_acsl_g_8;
  }
  return __gen_e_acsl_if_4;
}

