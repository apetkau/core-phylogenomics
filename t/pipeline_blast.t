#!/usr/bin/env perl

use warnings;
use strict;

use FindBin;
use Test::More;
use File::Temp 'tempdir';

my $script_dir = $FindBin::Bin;
my $pipeline_bin = "$script_dir/../perl_bin/snp_phylogenomics_control.pl";

$ENV{'PERL5LIB'} = "$script_dir/../lib:$script_dir/../cpanlib/perl5:".$ENV{'PERL5LIB'};

my $blast_dir = "$script_dir/data/pipeline/blast";
my $tmp_dir = "$script_dir/tmp";

opendir(my $blast_h,$blast_dir) or die "Could not open $blast_dir: $!";
my @job_dirs = sort grep {$_ !~ /^\./} readdir($blast_h);
closedir($blast_h);

print "### Testing BLAST Version of Pipeline ###\n";
for my $job (@job_dirs)
{
	print "\n### Testing $job ###\n";

	my $job_out = tempdir('snp_blast_pipelineXXXXXX', CLEANUP => 1, DIR => $tmp_dir) or die "Could not create temp directory";
	my $job_out_dir = "$job_out/out";

	my $input_dir = "$blast_dir/$job/input";
	my $output_dir = "$blast_dir/$job/output";

	my $expected_pseudoalign_file = "$output_dir/pseudoalign.phy";
	my $expected_report_file = "$output_dir/main.report";

	my $input_groups = "$input_dir/groups.txt";
	my $input_fasta = "$input_dir/fasta";

	my $command = "$pipeline_bin --mode blast --input-dir $input_fasta --hsp-length 10 --output $job_out_dir --processors 1";

	print "\tRunning pipeline for $input_dir ...";
	if (not (system("$command 2>&1 1>$job_out/log.txt") == 0))
	{
		print STDERR "Error executing command \"$command\"\n";
		print STDERR "See log file $job_out/log.txt\n";
		system("cat $job_out/log.txt");
		die;
	}
	print "done\n";

	my $actual_pseudoalign_file = "$job_out_dir/pseudoalign/pseudoalign.phy";

	ok(-e "$job_out_dir/pseudoalign/main.report", "main.report exists");
	ok(-e "$job_out_dir/pseudoalign/snp.report.txt", "snp.report.txt exists");
	ok(-e "$job_out_dir/phylogeny/pseudoalign.phy_phyml_tree.txt", "phyml tree exists");
	ok(-e "$job_out_dir/phylogeny/pseudoalign.phy_phyml_tree.txt.pdf", "phyml tree pdf exists");
	ok(-e "$job_out_dir/log/current", "log/current exists");
	ok(-e "$job_out_dir/run.properties", "run.properties exists");
	ok(-e $actual_pseudoalign_file, "pseudoalign.phy file exists");

	        my $test_command = "diff $expected_pseudoalign_file $actual_pseudoalign_file";
        my $results = `$test_command`;
        my $return_value = $?;
        if ($return_value != 0 or (defined $results and $results ne ''))
        {
                fail("expected file $expected_pseudoalign_file differs from actual file $actual_pseudoalign_file : diff\n");
                print STDERR $results;
        }
        else
        {
                pass("expected file $expected_pseudoalign_file eq actual file $actual_pseudoalign_file");
        }
}

done_testing();
