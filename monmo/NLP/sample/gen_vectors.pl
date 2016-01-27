#!/usr/bin/env perl
#---------------------------------------------
# testdata.pl - ????
# 
#   Copyright (C) 2013 rakuten 
#     by  <hiroaki.kubota@mail.rakuten.com> 
#     Date : 2013/07/03
#---------------------------------------------

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;

use locale;
use POSIX qw(setlocale strftime mktime LC_ALL floor);

my $l    = setlocale(LC_ALL,"C");
my $d = strftime "%d/%b/%Y:%H:%M:%S", localtime( time() );

my $FMT =<<_EOF_
{ _id: %d , loc: {x: %3.2f, y: %3.2f, z: %3.2f } }
_EOF_
;

my $FMT2 =<<_EOF_
{ _id: %d , loc: {x: %3.2f, y: %3.2f } }
_EOF_
;

my $FMT3 =<<_EOF_
{ _id: %d , loc: {x: %3.2f, z: %3.2f } }
_EOF_
;

my $FMT4 =<<_EOF_
{ _id: %d , loc: {y: %3.2f, z: %3.2f } }
_EOF_
;

my $NUM = 10000;
$NUM = int($ARGV[0]) if $ARGV[0];

my $REV = 32;
sub myrand  {
		my ($base) = @_;
		my $rev = 0;
		for ( my $i = 0 ; $i < $REV ; $i ++ ) {
				$rev = $rev + rand();
		}
		my $val = $base + ($rev / $REV) - 0.5;
		return 1 if $val >= 1;
		return 0 if $val <= 0;
		return $val;
}

my $DIV = 2;
LOOP:
for ( my $i = 0 ; ; ) {
		for ( my $a = 0 ; $a < $DIV; $a++ ) {
				for ( my $b = 0 ; $b < $DIV; $b++ ) {
						for ( my $c = 0 ; $c < $DIV; $c++ ) {
								{
										my $x = myrand((($a/$DIV) + (0.5/$DIV))) * 200 - 100;
										my $y = myrand((($b/$DIV) + (0.5/$DIV))) * 200 - 100;
										my $z = myrand((($c/$DIV) + (0.5/$DIV))) * 200 - 100;
										my $w = $i / $NUM;
										my $s = rand();
										printf("${FMT}",$i,$x,$y,$z);
										if ( ++$i >= $NUM ) {
												last LOOP;
										}
								}
								{
										my $x = myrand((($a/$DIV) + (0.5/$DIV))) * 200 - 100;
										my $y = myrand((($b/$DIV) + (0.5/$DIV))) * 200 - 100;
										my $w = $i / $NUM;
										my $s = rand();
										printf("${FMT2}",$i,$x,$y);
										if ( ++$i >= $NUM ) {
												last LOOP;
										}
								}
								{
										my $x = myrand((($a/$DIV) + (0.5/$DIV))) * 200 - 100;
										my $y = myrand((($b/$DIV) + (0.5/$DIV))) * 200 - 100;
										my $w = $i / $NUM;
										my $s = rand();
										printf("${FMT3}",$i,$x,$y);
										if ( ++$i >= $NUM ) {
												last LOOP;
										}
								}
								{
										my $x = myrand((($a/$DIV) + (0.5/$DIV))) * 200 - 100;
										my $y = myrand((($b/$DIV) + (0.5/$DIV))) * 200 - 100;
										my $w = $i / $NUM;
										my $s = rand();
										printf("${FMT4}",$i,$x,$y);
										if ( ++$i >= $NUM ) {
												last LOOP;
										}
								}
						}
				}
		}
}
#my $X = 4000;
#my $Y = 4000;
#my $XRATIO = 360.0 / $X;
#my $YRATIO = 360.0 / $Y;
#my $i = 0;
#for ( my $y = 0 ; $y <= $Y ; $y++ ) {
#		for ( my $x = 0 ; $x <= $X ; $x++ ) {
#				printf("${FMT}",$i,$x*$XRATIO-180,$y*$YRATIO-180,$x*$y % 10,$i/1000);
#				$i++;
#		}
#}

__END__
=head1 NAME

testdata.pl - ???? 

=head1 SYNOPSIS

testdata.pl  [options] [???]

=head1 OPTIONS

=over 18

=item -y

Auto 'y' answar.

=item -help

View help document.

=back

=head1 TODO

=over 18

=item 

=back

=cut
