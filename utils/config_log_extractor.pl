#!/usr/bin/env perl
use strict;
use warnings;
use File::Slurp;

my $n = 0;
my $state = 0;
my @arr;
my $test = "";

while(<>) {
	if($state < 2 && /^configure:(\d+): checking (.+)$/) {
		$n = $1;
		$test = $2;
		$state = 1;
		@arr = ();
		push @arr, "//$_";
	}
	elsif($state == 1) {
		push @arr, "//$_";
		$state = 2, print "test failed: $test" if(/^configure: failed program was:/);
	}
	elsif($state == 2) {
		if(! /^\|/) {
			my $outfile = sprintf("configure_fail%06d.c", $n);
			write_file $outfile, @arr;
			print " -> $outfile\n";
			@arr = ();
			$state = 0;
		} else {
			push @arr, substr( $_ , 1);
		}
	}
	
}

__END__

