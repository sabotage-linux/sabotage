#!/usr/bin/env perl

# to be used in combination with the output of config_log_extractor.pl

use strict;
use warnings;

my $file = $ARGV[0] or die "need filename";
my @fc = `cat $file`;

my $cc = "";
my @oc;
my $cstart = 0;
for(@fc) {
	if(!$cstart) {
		if(/^\/\//) {
			if(/gcc (.*)?>/) {
				$cc = "gcc " . $1 ;
			}
			next;
		} else {
			$cstart = 1;
			goto add;		
		}
	}
	add:
	push @oc, $_;
}

die "no compiler commandline found" if $cc eq "";
print "$cc\n";
open(my $fh, ">", "conftest.c") or die "cannot open output file";
for (@oc) {
	print { $fh } $_;
}

close($fh);
system("$cc") ;
my $ret = system("./conftest");
print "ret: " . ($ret >> 8) . ", $?\n";

