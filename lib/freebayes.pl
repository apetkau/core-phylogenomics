#!/usr/bin/env perl

use warnings;
use strict;

use Getopt::Long;
use FindBin;

my $script_dir = $FindBin::Bin;
my $filter_path = "$script_dir/filterVcf.pl";

die "Error: no $filter_path exists" if (not -e $filter_path);

my ($freebayes_params,$freebayes,$reference,$bam,$vcf,$bgzip,$tabix,$vcf_split,$min_coverage);
GetOptions('f|freebayes-path=s' => \$freebayes,
	   'r|reference=s' => \$reference,
	   'bam=s' => \$bam,
	   'out-vcf=s' => \$vcf,
	   'out-vcf-split=s' => \$vcf_split,
	   'min-coverage=i' => \$min_coverage,
	   'freebayes-params=s' => \$freebayes_params,
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
if (defined $freebayes_params)
{
	if ($freebayes_params =~ /--min-coverage/ or $freebayes_params =~ /-!/)
	{
		die "do not set --min-coverage in freebayes-params it is set using the --min-coverage parameter";
	}
}
else
{
	die "Error: no freebayes-params set";
}
die "Error: min-coverage not defined" if (not defined $min_coverage);
die "Error: min-coverage=$min_coverage not valid" if ($min_coverage !~ /^\d+$/);

my $command =
"$freebayes ".
	    # input and output
            "--bam $bam ".
            "--vcf $vcf ".
            "--fasta-reference $reference ".
	    "--min-coverage $min_coverage ".$freebayes_params;

print "Running $command\n";
system($command) == 0 or die "Could not run $command";

die "Error: no output vcf file=$vcf produced" if (not -e $vcf);

$command = "$filter_path --noindels \"$vcf\" -o \"$vcf_split\"";
print "Running $command\n";
system($command) == 0 or die "Could not run $command";

die "Error: no split vcf file=$vcf_split produced" if (not -e $vcf_split);

my $vcf_bgzip = "$vcf_split.gz";

$command = "$bgzip -f \"$vcf_split\"";
print "Running $command\n";
system($command) == 0 or die "Could not run $command";
$command = "$tabix -f -p vcf \"$vcf_bgzip\"";
print "Running $command\n";
system($command) == 0 or die "Could not run $command";

die "Error: no output bgzip/tabix vcf file=$vcf_bgzip produced" if (not -e "$vcf_bgzip");
