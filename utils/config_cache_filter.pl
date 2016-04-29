#!/usr/bin/env perl
use strict; use warnings;
use File::Slurp;

sub check {
	chomp;
	if(/^#/ || $_ eq "") {
	} elsif(/^([\w_]+)=.*?\'(.*?)\'/) {
		my $a = $1;
		my $b = $2;
		return ($a, $b);
	} elsif(/^([\w_]+)=(.*?)/) {
		my $a = $1;
		my $b = $2;
		return ($a, $b);
	} else {
		print STDERR "no match ! $_\n";
		#exit(1);
	}
	return (undef, undef);
}

my (%h, %l);

while(<>) {
	my ($a, $b) = check($_);
	if(defined($a)) {
		$h{$a} = defined($h{$a}) ? $h{$a} + 1 : 1;
		$l{$a} = $b if (defined($b));
	}
}

my @sorted = sort { $h{$a} <=> $h{$b} } keys %h;
for (@sorted) {
	print "$_ : $h{$_}\n";
}

my %h2;
my @templ = read_file("/lib/config.cache") or die("couldnt find config.cache");
for(@templ) {
	my ($a, $b) = check($_);
	if(defined($a)) {
		$h2{$a} = 1;
	}
}

for(@sorted) {
	print "missing: $_". "=" . (defined($l{$_}) ? $l{$_} : "") . " <- last value : count $h{$_}\n", if(!defined($h2{$_}));
}

