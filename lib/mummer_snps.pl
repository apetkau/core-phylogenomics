#!/usr/bin/env perl

use warnings;
use strict;

use Getopt::Long;

my ($nucmer,$delta_filter,$reference,$contig,$vcf,$show_snps,$mummer2vcf,$bgzip,$tabix);
GetOptions('s|nucmer-path=s' => \$nucmer,
	   'b|delta-filter-path=s' => \$delta_filter,
	   'r|reference=s' => \$reference,
	   'contig=s' => \$contig,
	   'out-vcf=s' => \$vcf,
	   'show-snps-path=s' => \$show_snps,
           'mummer2vcf=s' => \$mummer2vcf,
	   'bgzip-path=s' => \$bgzip,
	   'tabix-path=s' => \$tabix);

die "Error: no nucmer path not defined" if (not defined $nucmer);
die "Error: no delta_filter path defined" if (not defined $delta_filter);
die "Error: no show_snps path defined" if (not defined $show_snps);
die "Error: no mummer2vcf path defined" if (not defined $mummer2vcf);
die "Error: no bgzip path defined" if (not defined $bgzip);
die "Error: no tabix path defined" if (not defined $tabix);
die "Error: reference not defined" if (not defined $reference);
die "Error: no reference exists" if (not -e $reference);
die "Error: contig not defined" if (not defined $contig);
die "Error: contig does not exist" if (not -e $contig);
die "Error: no out-vcf defined" if (not defined $vcf);

my $command = "$nucmer --prefix=snps \"$reference\" \"$contig\"";
print "Running $command\n";
system($command) == 0 or die "Could not run $command";

my $delta_out= 'snps.delta';
my $filter_out = 'snps.filter';

die "Error: no output from nucmer was produced" if (not -e $delta_out);

$command = "$delta_filter -r -q $delta_out > $filter_out";
print "Running $command\n";
system($command) == 0 or die "Could not run $command";

die "Error: no output from delta-filter was produced" if (not -e $filter_out);

my $snp_coords = 'snps_coords.tsv';
$command = "$show_snps -ClrT $filter_out > $snp_coords";
print "Running $command\n";
system($command) == 0 or die "Could not run $command";

die "Error: no output from show-snps was produced" if (not -e $snp_coords);

#run the script to convert into a
$command = "$mummer2vcf -t SNP $snp_coords > $vcf";
print "Running $command\n";
system($command) == 0 or die "Could not run $command";

die "Error: no output vcf file=$vcf produced" if (not -e $vcf);
$command = "$bgzip -f \"$vcf\"";
print "Running $command\n";
system($command) == 0 or die "Could not run $command";
$command = "$tabix -f -p vcf \"$vcf.gz\"";
print "Running $command\n";
system($command) == 0 or die "Could not run $command";

die "Error: no output bgzip/tabix vcf file=$vcf.gz produced" if (not -e "$vcf.gz");

#time to cleanup temp files
unlink $delta_out;
unlink $filter_out;
unlink $snp_coords;

