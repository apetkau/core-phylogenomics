#!/usr/bin/env perl

use warnings;
use strict;

use FindBin;
use Test::More;
use File::Temp 'tempdir';
use File::Spec;

my $script_dir = $FindBin::Bin;

$ENV{'PERL5LIB'} = "$script_dir/../lib:$script_dir/../cpanlib/lib/perl5:".$ENV{'PERL5LIB'};

my $pseudoaligner = "$script_dir/../lib/pseudoaligner.pl";

my $input_dir = "$script_dir/data/pseudoalign";
my $output_dir = tempdir('pseudoalign_testXXXXXXXX', CLEANUP => 1, DIR => File::Spec->tmpdir) or die "Could not create temp dir";

opendir(my $in_h,$input_dir) or die "Could not open $input_dir: $!";
my @in_files = sort { $a <=> $b } grep {$_ !~ /^\./} readdir($in_h);
closedir($in_h);

print "Testing all input pseudoalignments in $input_dir\n";
for my $file (@in_files)
{
	my $test_dir = "$input_dir/$file";
	my $test_out_dir = "$output_dir/$file";
	my $actual_align_file = "$test_out_dir/pseudoalign.phy";
	my $expected_align_file = "$test_dir/pseudoalign.phy";
	my $actual_report_file = "$test_out_dir/snp.report.txt";
	my $expected_report_file = "$test_dir/snp.report.txt";

	print "\n### Testing $test_dir ###\n";
	die "Expected pseudoalign file=$expected_align_file does not exist" if (not -e $expected_align_file);
	die "Expected report file=$expected_report_file does not exist" if (not -e $expected_report_file);

	mkdir "$test_out_dir" or die "Could not mkdir $test_out_dir";

	#Pseudoaligner::run($test_dir, $test_out_dir,"/dev/null", undef);
	my $command = "$pseudoaligner -i $test_dir -o $test_out_dir -l /dev/null";
	system($command) == 0 or die "Could not execute $command\n";
	
	my $test_command = "diff $expected_align_file $actual_align_file";
	my $results = `$test_command`;
	if (defined $results and $results ne '')
	{
		fail("expected file $expected_align_file differs from actual file $actual_align_file : diff\n");
		print STDERR $results;
	}
	else
	{
		pass("expected file $expected_align_file eq actual file $actual_align_file");
	}

	$test_command = "diff $expected_report_file $actual_report_file";
	$results = `$test_command`;
	if (defined $results and $results ne '')
	{
		fail("expected file $expected_report_file differs from actual file $actual_report_file : diff\n");
		print STDERR $results;
	}
	else
	{
		pass("expected file $expected_report_file eq actual file $actual_report_file");
	}
}

done_testing();
