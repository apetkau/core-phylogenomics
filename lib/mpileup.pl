#!/usr/bin/env perl

use warnings;
use strict;

use Getopt::Long;

my ($samtools,$bcftools,$reference,$bam,$vcf,$bgzip,$tabix);
GetOptions('s|samtools-path=s' => \$samtools,
	   'b|bcftools-path=s' => \$bcftools,
	   'r|reference=s' => \$reference,
	   'bam=s' => \$bam,
	   'out-vcf=s' => \$vcf,
	   'bgzip-path=s' => \$bgzip,
	   'tabix-path=s' => \$tabix);

die "Error: no samtools path not defined" if (not defined $samtools);
die "Error: no bcftools path defined" if (not defined $bcftools);
die "Error: no bgzip path defined" if (not defined $bgzip);
die "Error: no tabix path defined" if (not defined $tabix);
die "Error: reference not defined" if (not defined $reference);
die "Error: no reference exists" if (not -e $reference);
die "Error: bam not defined" if (not defined $bam);
die "Error: bam does not exist" if (not -e $bam);
die "Error: no out-vcf defined" if (not defined $vcf);

my $command = "$samtools mpileup -uf \"$reference\" \"$bam\" | $bcftools view -cg - > \"$vcf\"";
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
