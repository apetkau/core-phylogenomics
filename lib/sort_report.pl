#!/usr/bin/perl

use strict;
use Getopt::Long;

sub usage
{
    print "Usage: sort_report.pl -i <report file>\n";
}

my $input_file;

GetOptions('i|input=s' => \$input_file) or die "Invalid options\n".usage;

die "Report file not defined\n".usage if (not defined $input_file);
die "Report file does not exists\n".usage if (not -e $input_file);

open IN, $input_file;
my %locuscounter;

while (<IN>) {
	$_ =~ /snps(\d+)/;
	$locuscounter{$1}++;
}

for my $id (sort {$locuscounter{$b} <=> $locuscounter{$a}} keys %locuscounter) {
    print "snps$id.aln.trimmed has $locuscounter{$id} snps\n";
}
