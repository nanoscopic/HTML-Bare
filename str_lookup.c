#include"str_lookup.h"
#include<stdlib.h>
#include<memory.h>

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

/*struct end_lookup_c *end_lookup__new( int depth ) {
  int size = sizeof( struct end_lookup_c );
  struct end_lookup_c *self = (struct end_lookup_c *) malloc( size );
  memset( (char *) self, 0, size );
  self->depth = depth;
  return self;
}*/

void str_lookup__add_str_mid( struct mid_lookup_c *mid, char *str, int strlen, int type, int depth ) {
  char char1 = str[0]-'a';
  if( strlen == 2 ) { // we will be pointing to an end node
    if( !(mid->down[ char1 ]) ) {
      //mid->down[ char1 ] = end_lookup__new( depth );
      mid->down[ char1 ] = mid_lookup__new( depth );
    }
    //struct end_lookup_c *end = ( struct end_lookup_c *) mid->down[ char1 ];
    struct mid_lookup_c *end = ( struct mid_lookup_c *) mid->down[ char1 ];
    end->type[ str[1]-'a' ] = type;
    return;
  }
  if( !mid->down[ char1 ] ) {
    mid->down[ char1 ] = mid_lookup__new( depth );
  }
  str_lookup__add_str_mid( (struct mid_lookup_c *) mid->down[ char1 ], str+1, strlen-1, type, depth+1 );
}

void str_lookup__add_str( struct str_lookup_c * self, char *str, int strlen, int type ) {
  //int strlen = strlen( str );
  if( strlen == 1 ) {
    self->type[ str[0]-'a' ] = type;
    return;
  }
  str_lookup__add_str_mid( self->root, str, strlen, type, 1 );
}

int str_lookup__find_str( struct str_lookup_c *self, char *str, int strlen ) {
  //int strlen = strlen( str );
  printf("Looking for [%.*s]\n", strlen, str );
  if( strlen == 1 ) {
    int a = self->type[ str[0]-'a' ];
    printf("Found %i\n", a );
    return a;
  }
  int a = str_lookup__find_str_mid( self->root, str, strlen );
  printf("Found %i\n", a );
  return a;
}

int str_lookup__find_str_mid( struct mid_lookup_c *mid, char *str, int strlen ) {
  if( strlen == 2 ) { // we will be pointing to an end node
    //struct end_lookup_c *end = mid->down[ str[0] ];
    struct mid_lookup_c *end = mid->down[ str[0]-'a' ];
    if( !end ) return 0;
    return end->type[ str[1]-'a' ];
  }
  mid = mid->down[ str[ 0 ]-'a' ];
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