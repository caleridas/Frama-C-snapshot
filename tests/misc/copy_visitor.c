/* run.config
   OPT: -check -copy -val -print -journal-disable
 */
struct S {
  int a;
  int b;
};
struct S s = {.a = 1, .b=2};

/*@
  requires \valid(s);
  assigns s->a;
*/
int f(struct S* s){
  s->a=2;
  return s->b;
}

/*@ assigns s.a; */
int main () {
  s.a = 2;
  /*@ assert s.a == 2; */
  f(&s);
  return 0;
}