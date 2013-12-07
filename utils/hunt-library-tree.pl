#!/usr/bin/env perl
use strict;
use warnings;

my %libs;
my @libpath;
@libpath = split /:/, $ENV{"LD_LIBRARY_PATH"} if(defined($ENV{"LD_LIBRARY_PATH"}));
push @libpath, "/lib";

sub getlibs {
	my $search = shift;
	my $elf = shift;
#	warn $elf;
	my @res = `readelf -a $elf | grep NEEDED`;
	for my $y(@res) {
		chomp $y;
		if($y =~ /\[(lib[\w._-]+\.so.*)\]/) {
			my $x = $1;
			if(!defined $libs{$x}) {
				$libs{$x} = 1;
				if(! -e $x) {
					for my $lp(@libpath) {
						if( -e $lp . "/" . $x) {
							$x = $lp . "/" . $x;
							last;
						}
					}
				}
				if(! -e $x) {
					print "error: lib $x not found\n";
					next;
				}
				getlibs($search, $x);
			}
		}
	}
	@res = `readelf -a $elf | grep $search`;
	for(@res) {
		print "$elf : $_";
	}
}

die "syntax: $0 searchterm elf" unless defined $ARGV[1];
getlibs($ARGV[0], $ARGV[1]);
for (keys %libs) {
	print $_, "\n";
}
