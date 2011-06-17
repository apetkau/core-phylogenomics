#!/usr/bin/perl

use strict;
open IN, "snp.report.txt";
my %locuscounter;
while (<IN>) {
	$_ =~ /snps(\d+)/;
	$locuscounter{$1}++;
}
for my $id (sort {$locuscounter{$b} <=> $locuscounter{$a}} keys %locuscounter) {
print "snps$id.aln.trimmed has $locuscounter{$id} snps\n";
}

