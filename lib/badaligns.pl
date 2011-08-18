#!/usr/bin/perl
use strict;

open IN, "badaligns.txt";
my @baddies = <IN>;
for my  $baddie (@baddies) {
	my ($badalign) = $baddie =~ /^(snps\d+\.aln\.trimmed)/;
	`mv $badalign badaligns`;
}
