#!/usr/bin/env perl

use warnings;
use strict;

use Getopt::Long;
use FindBin;

my $script_dir = $FindBin::Bin;
my $filter_path = "$script_dir/filterVcf.pl";

die "Error: no $filter_path exists" if (not -e $filter_path);

my ($freebayes,$reference,$bam,$vcf,$bgzip,$tabix,$vcf_split);
GetOptions('f|freebayes-path=s' => \$freebayes,
	   'r|reference=s' => \$reference,
	   'bam=s' => \$bam,
	   'out-vcf=s' => \$vcf,
	   'out-vcf-split=s' => \$vcf_split,
	   'bgzip-path=s' => \$bgzip,
	   'tabix-path=s' => \$tabix);

die "Error: no freebayes path defined" if (not defined $freebayes);
die "Error: no bgzip path defined" if (not defined $bgzip);
die "Error: no tabix path defined" if (not defined $tabix);
die "Error: reference not defined" if (not defined $reference);
die "Error: no reference exists" if (not -e $reference);
die "Error: bam not defined" if (not defined $bam);
die "Error: bam does not exist" if (not -e $bam);
die "Error: no out-vcf defined" if (not defined $vcf);
die "Error: no out-vcf-split defined" if (not defined $vcf_split);

my $command =
"$freebayes ".
	    # input and output
            "--bam $bam ".
            "--vcf $vcf ".
            "--fasta-reference $reference ".
	    # reporting
	    "--pvar 0 ". # Report sites if the probability that there is a polymorphism at the site is greater than N.  default: 0.0001

	    # population model
	    "--ploidy 1 ". # Sets the default ploidy for the analysis to N.  default: 2

	    # allele scope
	    "--no-mnps ". # Ignore multi-nuceotide polymorphisms, MNPs.

	    # indel realignment
	    "--left-align-indels ". # Left-realign and merge gaps embedded in reads. default: false

	    # input filters
	        "--min-mapping-quality 30 ". # Exclude alignments from analysis if they have a mapping quality less than Q.  default: 30
                "--min-base-quality 30 ". # Exclude alleles from analysis if their supporting base quality is less than Q.  default: 20
                "--indel-exclusion-window 5 ".# Ignore portions of alignments this many bases from a putative insertion or deletion allele.  default: 0
                "--min-alternate-fraction 0.75 ".# Require at least this fraction of observations supporting an alternate allele within a single individual in the in order to evaluate the position.  default: 0.0
                "--min-coverage 12 "; # Require at least this coverage to process a site.  default: 0

print "Running $command\n";
system($command) == 0 or die "Could not run $command";

die "Error: no output vcf file=$vcf produced" if (not -e $vcf);

$command = "$filter_path --noindels \"$vcf\" -o \"$vcf_split\"";
print "Running $command\n";
system($command) == 0 or die "Could not run $command";

die "Error: no split vcf file=$vcf_split produced" if (not -e $vcf_split);

my $vcf_bgzip = "$vcf_split.gz";

$command = "$bgzip \"$vcf_split\"";
print "Running $command\n";
system($command) == 0 or die "Could not run $command";
$command = "$tabix -p vcf \"$vcf_bgzip\"";
print "Running $command\n";
system($command) == 0 or die "Could not run $command";

die "Error: no output bgzip/tabix vcf file=$vcf_bgzip produced" if (not -e "$vcf_bgzip");
