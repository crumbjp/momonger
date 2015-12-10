#!/usr/bin/env perl
#---------------------------------------------
# testdata.pl - ????
# 
#   Copyright (C) 2013 rakuten 
#     by  <hiroaki.kubota@mail.rakuten.com> 
#     Date : 2013/07/03
#---------------------------------------------
use utf8;
use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;

use locale;
use POSIX qw(setlocale strftime mktime LC_ALL floor);

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $DIRNAME = 'data/ipadic-2.7.0';

GetOptions(
  'ipadic' => \$DIRNAME
		);


my $l    = setlocale(LC_ALL,"C");
my $d = strftime "%d/%b/%Y:%H:%M:%S", localtime( time() );

my $FMT =<<_EOF_
{ _id: %d , loc: [ %3.2f , %3.2f ],	weight: %3.2f,  score: %3.2f }
_EOF_
;

sub parsedic{
		my ($fname) = @_;
		print STDERR "  - $fname\n";
		open(my $fp,"<:encoding(euc-jp)","$fname");
		while(my $line = <$fp> ){
				my $org = $line;
				$line =~ s/\(//g;
				$line =~ s/\)/\f/g;
				if (! ($line =~ s/^品詞 +([^\f]+)//) ) {
						die $line . $org;
				}
				my $types = $1;
				if (! ($line =~ s/^[ \f]*見出し語 +([^ ]+) +(\d+)//) ) {
						die $line . $org;
				}
				my $word  = $1;
				my $cost = $2;
				if ( ! ($line =~ /^[ \f]*読み +([^\f]+)/) ) {
						die $line . $org;
				}
				my $prons  = $1;
				$types =~ s/ +/","/g;
				
				$prons =~ s/^{//g;
				$prons =~ s/}$//g;
				$prons =~ s/\//","/g;
				print "{w:\"$word\",c:$cost,p:[\"$prons\"],t:[\"$types\"]}\n";
		}
}

opendir(my $dir,$DIRNAME);
while ( my $fname = readdir($dir) ) {
		if ( $fname eq 'Onebyte.dic' ) {
				next;
		}
		if ( $fname =~ /.dic$/ ) {
				parsedic("$DIRNAME/$fname" );
		}
}

