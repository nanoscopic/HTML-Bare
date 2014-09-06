#!/usr/bin/perl -w

use strict;

use Test::More qw(no_plan);

use_ok( 'HTML::Bare' );

my ( $ob, $root ) = HTML::Bare->new( text => qq{
<a>
 <b>
  <c />
 </b>
 <a>test</a>
</a>} ); 
ok( $root, "Got some root" );
my $val = $root->{'a'}{'a'}{'value'};
is( $val, 'test', "Got the right value" );

( $ob, $root ) = HTML::Bare->new( text => qq{
<a>
 <b>
  <c />
  <c />
 </b>
 <a>test</a>
</a>} ); 
ok( $root, "Got some root" );
$val = $root->{'a'}{'a'}{'value'};
is( $val, 'test', "Got the right value" );
my $c_count = scalar @{$root->{'a'}{'b'}{'c'}};
is( $c_count, 2, "Got right count" );
