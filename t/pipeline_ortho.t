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
if (not GetOptions('t|tmp-dir=s' => \$tmp_dir,
		   'k|keep-tmp' => \$keep_tmp))
{
        die usage;
}

die "no tmp-dir defined\n".usage if (not defined $tmp_dir);
die "tmp-dir does not exist\n".usage if (not (-e $tmp_dir));

$keep_tmp = 0 if (not defined $keep_tmp);

my $ortho_dir = "$script_dir/data/pipeline/ortho";

opendir(my $ortho_h,$ortho_dir) or die "Could not open $ortho_dir: $!";
my @job_dirs = sort grep {$_ !~ /^\./} readdir($ortho_h);
closedir($ortho_h);

print "### Testing OrthoMCL Version of Pipeline ###\n";
for my $job (@job_dirs)
{
	print "\n### Testing $job ###\n";

	my $job_out = tempdir('snp_ortho_pipelineXXXXXX', CLEANUP => (not $keep_tmp), DIR => $tmp_dir) or die "Could not create temp directory";
	print "results temp dir=$job_out\n" if ($keep_tmp);
	my $job_out_dir = "$job_out/out";

	my $input_dir = "$ortho_dir/$job/input";
	my $output_dir = "$ortho_dir/$job/output";

	my $expected_pseudoalign_file = "$output_dir/pseudoalign.phy";
	my $expected_report_file = "$output_dir/main.report";

	my $input_groups = "$input_dir/groups.txt";
	my $input_fasta = "$input_dir/fasta";

	my $command = "$pipeline_bin --mode orthomcl --input-dir $input_fasta --output $job_out_dir ".
			"--orthomcl-groups $input_groups";

	print "Running pipeline for $input_dir ...";
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
