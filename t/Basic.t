#!/usr/bin/perl -w

use strict;

use Test::More tests => 24;

use_ok( 'HTML::Bare', qw/htmlin/ );

my $xml;
my $root;
my $simple;

( $xml, $root, $simple ) = reparse( "<xml><node>val</node></xml>" );
is( $root->{xml}->{node}->{value}, 'val', 'normal node value reading' );#1
is( $simple->{node}, 'val', 'simple - normal node value reading' );#2

( $xml, $root, $simple ) = reparse( "<xml><node/></xml>" );
is( ref( $root->{xml}->{node} ), 'HASH', 'existence of blank node' );#3
is( $simple->{node}, '', 'simple - existence of blank node' );#4

( $xml, $root, $simple ) = reparse( "<xml><node att=12>val</node></xml>" );
is( $root->{xml}->{node}->{att}->{value}, '12', 'reading of attribute value' );#5
is( $simple->{node}{att}, '12', 'simple - reading of attribute value' );#6

( $xml, $root, $simple ) = reparse( "<xml><node att=\"12\">val</node></xml>" );
is( $root->{xml}->{node}->{att}->{value}, '12', 'reading of " surrounded attribute value' );#7
is( $simple->{node}{att}, '12', 'simple - reading of " surrounded attribute value' );#8

( $xml, $root, $simple ) = reparse( "<xml><node att>val</node></xml>" );
is( $root->{xml}{node}{att}{value}, '1', "reading of value of standalone attribute" );#9
is( $simple->{node}{att}, '1', "simple - reading of value of standalone attribute" );#10
    
( $xml, $root, $simple ) = reparse( "<xml><node><![CDATA[<cval>]]></node></xml>" );
is( $root->{xml}->{node}->{value}, '<cval>', 'reading of cdata' );#11
is( $simple->{node}, '<cval>', 'simple - reading of cdata' );#12

( $xml, $root, $simple ) = reparse( "<xml><node>a</node><node>b</node></xml>" );
is( $root->{xml}->{node}->[1]->{value}, 'b', 'multiple node array creation' );#13
is( $simple->{node}[1], 'b', 'simple - multiple node array creation' );#14

( $xml, $root, $simple ) = reparse( "<xml><multi_node/><node>a</node></xml>" );
is( $root->{xml}->{node}->[0]->{value}, 'a', 'use of multi_' );#15
is( $simple->{node}[0], 'a', 'simple - use of multi_' );#16

# note output of this does not work
( $xml, $root ) = new HTML::Bare( text => "<xml><node>val<a/></node></xml>" );
is( $root->{xml}->{node}->{value}, 'val', 'basic mixed - value before' );#17
#is( $simple->{xml}{node}[0], 'val', 'simple - basic mixed - value before' );

# note output of this does not work
( $xml, $root ) = new HTML::Bare( text => "<xml><node><a/>val</node></xml>" );
is( $root->{xml}->{node}->{value}, 'val', 'basic mixed - value after' );#18

( $xml, $root, $simple ) = reparse( "<xml><!--test--></xml>",1  );
is( $root->{xml}->{comment}, 'test', 'loading a comment' );#19

# test node addition
( $xml, $root ) = new HTML::Bare( text => "<xml></xml>" );
$xml->add_node( $root, 'item', name => 'bob' );
is( ref( $root->{'item'}[0]{'name'} ), 'HASH', 'node addition' );#20
is( $root->{'item'}[0]{'name'}{'value'}, 'bob', 'node addition' );#21

# test cyclic equalities
cyclic( "<xml><b><!--test--></b><c/><c/></xml>", 'comment' );#22
cyclic( "<xml><a><![CDATA[cdata]]></a></xml>", 'cdata' ); #23 with cdata

my $text = '<xml><node>checkval</node></xml>';
( $xml, $root ) = new HTML::Bare( text => $text );
my $i = $root->{'xml'}{'node'}{'_i'}-1;
my $z = $root->{'xml'}{'node'}{'_z'}-$i+1;
#is( substr( $text, $i, $z ), '<node>checkval</node>', '_i and _z vals' );

# saving test
( $xml, $root ) = HTML::Bare->new( file => 't/test.xml' );
$xml->save();

sub reparse {
  my $text = shift;
  my $nosimp = shift;
  my ( $xml, $root ) = new HTML::Bare( text => $text );
  my $a = $xml->html( $root );
  ( $xml, $root ) = new HTML::Bare( text => $a );
  my $simple = $nosimp ? 0 : htmlin( $text );
  return ( $xml, $root, $simple );
}

sub cyclic {
  my ( $text, $name ) = @_;
  ( $xml, $root ) = new HTML::Bare( text => $text );
  my $a = $xml->html( $root );
  ( $xml, $root ) = new HTML::Bare( text => $a );
  my $b = $xml->html( $root );
  is( $a, $b, "cyclic - $name" );
}

# test bad closing tags
# we need to a way to ensure that something dies... ?
