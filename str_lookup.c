#include"str_lookup.h"
#include<stdlib.h>
#include<stdio.h>
#include<memory.h>
//#define DEBUG

struct mid_lookup_c * mid_lookup__new( int depth ) {
  int size = sizeof( struct mid_lookup_c );
  struct mid_lookup_c *self = (struct mid_lookup_c *) malloc( size );
  memset( (char *) self, 0, size );
  self->depth = depth;
  return self;
}

struct str_lookup_c* str_lookup__new() {
  int size = sizeof( struct str_lookup_c );
  struct str_lookup_c *self = (struct str_lookup_c *) malloc( size );
  memset( (char *) self, 0, size );
  self->root = mid_lookup__new( 1 );
  return self;
}

void str_lookup__add_str_mid( struct mid_lookup_c *mid, char *str, int strlen, int type, int depth ) {
  char let1 = str[0];
  if( let1 < 'a' || let1 > 'z' ) return;
  char n1 = let1-'a';
  if( !(mid->down[ n1 ]) ) {
    mid->down[ n1 ] = mid_lookup__new( depth );
  }
  if( strlen == 2 ) { // we will be pointing to an end node
    struct mid_lookup_c *end = ( struct mid_lookup_c *) mid->down[ n1 ];
    char let2 = str[1];
    if( let2 < 'a' || let2 > 'z' ) return;
    end->type[ let2-'a' ] = type;
    return;
  }
  str_lookup__add_str_mid( (struct mid_lookup_c *) mid->down[ n1 ], str+1, strlen-1, type, depth+1 );
}

void str_lookup__add_str( struct str_lookup_c * self, char *str, int strlen, int type ) {
  char let1 = str[0];
  if( let1 < 'a' || let1 > 'z' ) return;
  if( strlen == 1 ) {
    self->type[ let1-'a' ] = type;
    return;
  }
  str_lookup__add_str_mid( self->root, str, strlen, type, 1 );
}

int str_lookup__find_str( struct str_lookup_c *self, char *str, int strlen ) {
  #ifdef DEBUG
  printf("1 Looking for [%.*s]\n", strlen, str );
  #endif
  if( strlen == 1 ) {
    char let = str[0];
    if( let >= 'A' && let <= 'Z' ) { let -= 'A'; let += 'a'; }
    if( let < 'a' || let > 'z' ) return 0;
    int a = self->type[ let-'a' ];
    #ifdef DEBUG
    printf("Found %i\n", a );
    #endif
    return a;
  }
  int a = str_lookup__find_str_mid( self->root, str, strlen );
  return a;
}

int str_lookup__find_str_mid( struct mid_lookup_c *mid, char *str, int strlen ) {
  #ifdef DEBUG
  printf("2 Looking for [%.*s]\n", strlen, str );
  #endif
  if( strlen == 2 ) { // we will be pointing to an end node
    char let1 = str[0];
    if( let1 >= 'A' && let1 <= 'Z' ) { let1 -= 'A'; let1 += 'a'; }
    if( let1 < 'a' || let1 > 'z' ) return 0;
    struct mid_lookup_c *end = mid->down[ let1-'a' ];
    if( !end ) return 0;
    
    char let2 = str[1];
    if( let2>= 'A' && let2 <= 'Z' ) { let2 -= 'A'; let2 += 'a'; }
    if( let2 < 'a' || let2 > 'z' ) return 0;
    int a = end->type[ let2 - 'a' ];
    #ifdef DEBUG
    printf("Found %i\n", a );
    #endif
    return a;
  }
  char let = str[0];
  if( let >= 'A' && let <= 'Z' ) { let -= 'A'; let += 'a'; }
  if( let < 'a' || let > 'z' ) return 0;
  mid = mid->down[ let-'a' ];
  if( !mid ) return 0;
  return str_lookup__find_str_mid( mid, str+1, strlen-1 );
}

void str_lookup__dump( struct str_lookup_c *self ) {
  mid_lookup__dump( self->root );
}

void mid_lookup__dump( struct mid_lookup_c *mid ) {
  int i;
  for( i=0;i<26;i++ ) {
    if( mid->type[ i ] ) {
      printf( "Type - %c = %i\n", i + 'a', mid->type[ i ] ); 
    }
  }
  for( i=0;i<26;i++ ) {
    if( mid->down[ i ] ) {
      printf( "Down - %c\n[\n", i + 'a' );
      mid_lookup__dump( mid->down[ i ] );
      printf("]\n");
    }
  }
}