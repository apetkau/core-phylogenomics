#!/usr/bin/perl

use strict;
use warnings;

use FindBin;

$ENV{'PERL5LIB'} = "/opt/rocks/lib/perl5/site_perl/5.10.1"
    .((defined $ENV{'PERL5LIB'}) ? ':'.$ENV{'PERL5LIB'} : '');

use lib $FindBin::Bin.'/../lib';

use File::Basename qw(basename dirname);
use File::Copy qw(copy move);
use File::Path qw(rmtree);
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
my $output_opt;
my $pid_cutoff_opt;
my $hsp_length_opt;
my $input_files;

my $resubmit_opt;
my $start_stage_opt;
my $end_stage_opt;
my $tmp_dir_opt;

if (!GetOptions(
    'p|pid-cutoff=f' => \$pid_cutoff_opt,
    'i|input-file=s@' => \$input_files,
    'h|hsp-length=i' => \$hsp_length_opt,
    'o|output=s' => \$output_opt,
    't|tmp-dir=s' => \$tmp_dir_opt,
    'processors=i' => \$processors_opt))
{
    die "$!";
}

die "Error: invalid tmp-dir" if (not defined $tmp_dir_opt);
die "Error: invalid tmp-dir=$tmp_dir_opt" if (not -d $tmp_dir_opt);
die "Error: invalid output" if (not defined $output_opt);
die "Error: invalid pid-cutoff" if (defined $pid_cutoff_opt and $pid_cutoff_opt !~ /\d+\.?\d*/);
die "Error: invalid hsp-length" if (defined $hsp_length_opt and $hsp_length_opt !~ /\d+/);
die "Error: invalid processors" if ((not defined $processors_opt) or $processors_opt !~ /\d+/);
die "Error: no input files" if (not defined $input_files or @$input_files <= 0);
foreach my $file (@$input_files)
{
    die "Error: input file is not defined" if (not defined $file);
    die "Error: input file=$file does not exist" if (not -e $file);
}
my $output_dir = $output_opt;
my $tmp_dir = $tmp_dir_opt;

my $tmp_output_dir = tempdir('core_snp.XXXXXX', DIR => $tmp_dir);
my $input_dir = "$tmp_output_dir/galaxy.input";
mkdir($input_dir) or die "Could not make directory $input_dir: $!";

foreach my $file (@$input_files)
{
    my $file_name = basename($file);
    copy($file,"$input_dir/$file_name.fasta") or die "Could not copy $file to $input_dir: $!";
}

my $pseudoalign_out_file = "$tmp_output_dir/pseudoalign/pseudoalign.phy";
my $pseudoalign_done_file = "$tmp_output_dir/stages/pseudoalign.done";

my $pipeline_control_command = "$script_dir/snp_phylogenomics_control.pl --output \"$tmp_output_dir\" --processors $processors_opt -v -v -v --force-output-dir --input-dir \"$input_dir\"";
$pipeline_control_command .= " --pid-cutoff $pid_cutoff_opt" if (defined $pid_cutoff_opt);
$pipeline_control_command .= " --hsp-length $hsp_length_opt" if (defined $hsp_length_opt);
print "Executing: $pipeline_control_command\n";
system("$pipeline_control_command") == 0 or die "Error in command $pipeline_control_command";
if (-e $pseudoalign_done_file)
{
	move($pseudoalign_out_file, $output_dir);
}
else
{
	die "Error: file $pseudoalign_done_file does not exist, some error has occured";
}

rmtree($tmp_output_dir) or die "Could not delete $tmp_output_dir: $!";
