#!/usr/bin/perl

use strict;
use warnings;

use FindBin;

$ENV{'PERL5LIB'} = "/opt/rocks/lib/perl5/site_perl/5.10.1:".$ENV{'PERL5LIB'};

use lib $FindBin::Bin.'/../lib';

use File::Basename qw(basename dirname);
use File::Copy qw(copy move);
use File::Path qw(remove_tree);
use File::Temp qw(tempdir);
use Getopt::Long;

my $script_dir = $FindBin::Bin;

my $verbose = 0;

my $pid_cutoff_default = 99;
my $hsp_length_default = 400;

############
##  MAIN  ##
############

my $verbose_opt;
my $processors_opt;
my $input_fasta_opt;
my $help_opt;
my $strain_count_opt;
my $input_dir_opt;
my $keep_files_opt;
my $output_opt;
my $pid_cutoff_opt;
my $hsp_length_opt;

my $resubmit_opt;
my $start_stage_opt;
my $end_stage_opt;
my $tmp_dir_opt;

if (!GetOptions(
    'o|output=s' => \$output_opt,
    't|tmp-dir=s' => \$tmp_dir_opt))
{
    die "$!";
}

die "Error: invalid tmp-dir" if (not defined $tmp_dir_opt);
die "Error: invalid tmp-dir=$tmp_dir_opt" if (not -d $tmp_dir_opt);
die "Error: invalid output" if (not defined $output_opt);
my $output_dir = $output_opt;
my $tmp_dir = $tmp_dir_opt;

my $tmp_output_dir = tempdir('core_snp.XXXXXX', DIR => $tmp_dir);

my $pseudoalign_out_file = "$tmp_output_dir/pseudoalign/pseudoalign.phy";
my $pseudoalign_done_file = "$tmp_output_dir/stages/pseudoalign.done";

my $pipeline_control_command = "$script_dir/snp_phylogenomics_control.pl --output \"$tmp_output_dir\" --input-dir \"$script_dir/../sample\" --processors 480";
system("$pipeline_control_command") == 0 or die "Error in command $pipeline_control_command";
if (-e $pseudoalign_done_file)
{
	move($pseudoalign_out_file, $output_dir);
}
else
{
	die "Error: file $pseudoalign_done_file does not exist, some error has occured";
}

remove_tree($tmp_output_dir) or die "Could not delete $tmp_output_dir: $!";
