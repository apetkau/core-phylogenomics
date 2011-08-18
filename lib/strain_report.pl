#!/usr/bin/perl
use strict;

open IN, "snp.report.txt";
my @report = <IN>;
close IN;

for my $row (@report) {
	my @fields = split "\t", $row;

#   0  'column 1: C(T) from snps1.aln.trimmed in:'
#   1  ' 356908'
#	2  'C6706'
#	3  'M662'
#	4  'N16961'
#	5  '93 93 93 93 93 93 93 93 93 93 93 93 93 93 0 93 93 93 93 93 93 93 93 93 93 93 93

my $wait;
	my $quals = pop @fields;
	my $locusline = shift @fields;
	my ($locus) = $locusline =~ /(snps\d+\.aln\.trimmed)/;
	my $wait;
}	
