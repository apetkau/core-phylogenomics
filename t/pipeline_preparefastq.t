#!/usr/bin/env perl

use warnings;
use strict;

use FindBin;
use Test::More;
use File::Temp 'tempdir';
use Getopt::Long;

my $script_dir = $FindBin::Bin;
my $pipeline_bin = "$script_dir/../perl_bin/snp_phylogenomics_control.pl";

my $old_env = $ENV{'PERL5LIB'};
$ENV{'PERL5LIB'} = "$script_dir/../lib:$script_dir/../cpanlib/lib/perl5:";
$ENV{'PERL5LIB'} .= $old_env if (defined $old_env);

sub usage
{
        return "Usage: $0 --tmp-dir [tmp_directory] [--keep-tmp]\n";
}

### MAIN ###

my $tmp_dir;
my $keep_tmp;
if (not GetOptions('t|tmp-dir=s' => \$tmp_dir,'k|keep-tmp' => \$keep_tmp))
{
        die usage;
}

die "no tmp-dir defined\n".usage if (not defined $tmp_dir);
die "tmp-dir does not exist\n".usage if (not (-e $tmp_dir));

$keep_tmp = 0 if (not defined $keep_tmp);

my $fastq_dir = "$script_dir/data/pipeline/prepare-fastq";

opendir(my $mapping_h,$fastq_dir) or die "Could not open $fastq_dir: $!";
my @job_dirs = sort grep {$_ !~ /^\./} readdir($mapping_h);
closedir($mapping_h);

print "### Testing Prepare Fastq Version of Pipeline ###\n";
for my $job (@job_dirs)
{
	print "\n### Testing $job ###\n";

	my $job_out = tempdir('snp_mapping_prepare_fastqXXXXXX', CLEANUP => (not $keep_tmp), DIR => $tmp_dir) or die "Could not create temp directory";
	my $job_out_dir = "$job_out/out";

	my $input_dir = "$fastq_dir/$job/input";
	my $output_dir = "$fastq_dir/$job/output";

	my $input_fastq = "$input_dir/fastq";
	my $input_reference = "$input_dir/reference.fasta";
	my $config_file = "$input_dir/settings.conf";

	my $command = "$pipeline_bin --mode prepare-fastq --input-dir $input_fastq --output $job_out_dir ".
			"--reference $input_reference --config $config_file";

	print "\tRunning pipeline for $input_dir ...";
	if (not (system("$command 2>&1 1>$job_out/log.txt") == 0))
	{
		print STDERR "Error executing command \"$command\"\n";
		print STDERR "See log file $job_out/log.txt\n";
		system("cat $job_out/log.txt");
		die;
	}
	print "done\n";

	my $actual_cleaned_fastq_dir = "$job_out_dir/cleaned_fastq";

	ok(-e "$job_out_dir/log/current", "log/current exists");
	ok(-e "$job_out_dir/run.properties", "run.properties exists");
	ok(-e "$actual_cleaned_fastq_dir", "cleaned fastq dir exists");
	ok(-e "$job_out_dir/downsampled_fastq", 'downsampled directory exists');
	ok(-e "$job_out_dir/log/current/fastqc.out", 'fastqc ran');
	ok(-e "$job_out_dir/fastqc/fastqc_stats.csv", 'fastqc stats exist');

	opendir(my $dh,$actual_cleaned_fastq_dir);
	my @actual_out_fastq = grep {/\.fastq$/} readdir($dh);
	closedir($dh);

	for my $fastq (@actual_out_fastq)
	{
		my $actual_fastq_file = "$actual_cleaned_fastq_dir/$fastq";
		my $expected_fastq_file = "$output_dir/$fastq";
		my $test_command = "diff $actual_fastq_file $expected_fastq_file";
		my $results = `$test_command`;
		my $return_value = $?;

	        if ($return_value != 0 or (defined $results and $results ne ''))
        	{
                	fail("expected file $expected_fastq_file differs from actual file $actual_fastq_file : diff\n");
	                print STDERR $results;
	        }
	        else
	        {
	                pass("expected file $expected_fastq_file eq actual file $actual_fastq_file");
	        }
	}
}

done_testing();
