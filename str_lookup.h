#ifndef __STR_LOOKUP_H
#define __STR_LOOKUP_H
/*
  String to integer lookup map
*/
//struct end_lookup_c {
//  int depth;
//  int type[26]; // only allow looking up alphabetic strings
//};

struct mid_lookup_c {
  int depth;
  int type[26];
  void *down[26]; // goes to either another mid_lookup or an end_lookup
};

struct str_lookup_c {
  struct mid_lookup_c *root;
  int type[26]; // one character checks
  int maxlen;
};

struct mid_lookup_c * mid_lookup__new( int depth );
struct str_lookup_c * str_lookup__new();
//struct end_lookup_c * end_lookup__new( int depth );

void str_lookup__add_str_mid(    struct mid_lookup_c *mid, char *str, int strlen, int type, int depth );
void str_lookup__add_str(        struct str_lookup_c *self, char *str, int strlen, int type );
int  str_lookup__find_str(       struct str_lookup_c *self, char *str, int strlen );
int  str_lookup__find_str_mid(   struct mid_lookup_c *mid, char *str, int strlen );

void str_lookup__dump( struct str_lookup_c *self );

void mid_lookup__dump( struct mid_lookup_c *mid );
#endif