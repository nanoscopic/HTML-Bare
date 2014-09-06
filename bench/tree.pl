#!/usr/bin/perl

print <<END;
Native Perl Tree Parsers

END
  print `perl onetree.pl 23`;
my $file = $ARGV[0] || 'test.xml';
for my $i ( 0..22 ) {
  print `perl onetree.pl $i $file 1`
}
