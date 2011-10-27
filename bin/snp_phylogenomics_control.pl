#!/usr/bin/perl

use strict;
use warnings;

use FindBin;

use lib $FindBin::Bin.'/../lib';

use File::Basename qw(basename dirname);
use File::Copy qw(copy move);
use File::Path qw(rmtree);
use Getopt::Long;
use Pipeline;

my $script_dir = $FindBin::Bin;

my $verbose = 0;
my $keep_files = 0;

my $pid_cutoff_default = 99;
my $hsp_length_default = 400;

sub usage
{
    print "Usage: ".basename($0)." [Options]\n\n";
    print "Options:\n";
    print "\t-r|--resubmit [job_dir]:  Resubmits an already run job through the pipeline.\n";
    print "\t\tUses options --start-stage and --end-stage to determine stages to submit to.\n";
    print "\t--start-stage:  The starting stage to resubmit to (only when performing a resubmission).\n";
    print "\t\tWill resubmit from beginning if not defined.\n";
    print "\t--end-stage:  The ending stage to resubmit to (can be used without a resubmission).\n";
    print "\t\tWill resubmit to ending if not defined.\n";
    print "\t-d|--input-dir [directory]:  The directory containing the input fasta files.\n";
    print "\t-h|--help:  Print help.\n";
    print "\t-o|--output [directory]:  The directory to store output (optional).\n";
    print "\t-p|--processors [integer]:  The number of processors to use.\n";
    print "\t--pid-cutoff [real]:  The pid cutoff to use (default $pid_cutoff_default).\n";
    print "\t--hsp-length [integer]:   The hsp length to use (default $hsp_length_default).\n";
    print "\t-v|--verbose:  Print extra information, define multiple times for more information.\n";
    print "\t--force-output-dir: Forces use of output directory even if it exists (optional).\n";

    print "\nStages:\n";
    print Pipeline::static_get_stage_descriptions("\t");

    print "\nExample:\n";
    print "\t".basename($0)." --processors 480 --input-dir sample/ --output data\n";
    print "\tRuns ".basename($0)." on data under sample/ with the passed number of processors.\n\n";
    print "\t".basename($0)." --resubmit data --start-stage pseudoalign\n";
    print "\tRe-runs the job stored under data/ at the pseudoalignment stage.\n\n";
}

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
my $force_output_dir_opt;
my $pid_cutoff_opt;
my $hsp_length_opt;

my $resubmit_opt;
my $start_stage_opt;
my $end_stage_opt;

if (!GetOptions(
    'r|resubmit=s' => \$resubmit_opt,
    'start-stage=s' => \$start_stage_opt,
    'end-stage=s' => \$end_stage_opt,
    'p|processors=i' => \$processors_opt,
    'd|input-dir=s' => \$input_dir_opt,
    'o|output=s' => \$output_opt,
    'k|keep-files' => \$keep_files_opt,
    'pid-cutoff=f' => \$pid_cutoff_opt,
    'hsp-length=i' => \$hsp_length_opt,
    'v|verbose+' => \$verbose_opt,
    'h|help' => \$help_opt,
    'force-output-dir' => \$force_output_dir_opt,
    'c|strain-count=i' => \$strain_count_opt))
{
    usage;
    die "$!";
}

if (defined $help_opt and $help_opt)
{
    usage;
    exit 0;
}

my $pipeline = new Pipeline($script_dir);

if (defined $verbose_opt)
{
    $pipeline->set_verbose($verbose_opt); 
}

if (defined $resubmit_opt)
{
    if (not -d $resubmit_opt)
    {
        print STDERR "Error: $resubmit_opt is an invalid job directory to resubmit from\n";
        usage;
        exit 1;
    }
    else
    {
        $pipeline->resubmit($resubmit_opt);
    }

    if (defined $end_stage_opt)
    {
        if (not $pipeline->is_valid_stage($end_stage_opt))
        {
            die "Cannot resubmit to invalid stage $end_stage_opt";
        }
        else
        {
            $pipeline->set_end_stage($end_stage_opt);
        }
    }
    
    if (defined $start_stage_opt)
    {
        if (not $pipeline->is_valid_stage($start_stage_opt))
        {
            die "Cannot resubmit to invalid stage $start_stage_opt";
        }
        else
        {
            $pipeline->set_start_stage($start_stage_opt);
        }
    }
}
else
{
    if (not defined $processors_opt)
    {
        print STDERR "Must specify number of processors\n";
        usage;
        exit 1;
    }
    elsif ($processors_opt !~ /^\d+$/)
    {
        print STDERR "Processors option must be a number\n";
        usage;
        exit 1;
    }
    else
    {
        $pipeline->set_processors($processors_opt);
    }
    
    if (defined $keep_files_opt and $keep_files_opt)
    {
        $pipeline->set_keep_files($keep_files_opt);
    }
    
    if (defined $input_dir_opt)
    {
        if (not -d $input_dir_opt)
        {
            print STDERR "Error: input fasta directory $input_dir_opt is not a directory\n";
            usage;
            exit 1;
        }
        else
        {
            $pipeline->set_input_fasta($input_dir_opt);
    
            if (defined $strain_count_opt)
            {
                if ($strain_count_opt <= 0)
                {
                    print STDERR "Error: strain count $strain_count_opt must be positive\n";
                    usage;
                    exit 1;
                }
                else
                {
                    $pipeline->set_strain_count($strain_count_opt);
                }
            }
        }
    }
    else
    {
        print STDERR "Error: input dir must be defined\n";
        usage;
        exit 1;
    }
    
    if (defined $output_opt)
    {
        if (-e $output_opt)
        {
            if (-d $output_opt and defined $force_output_dir_opt and $force_output_dir_opt)
            {
                $pipeline->set_job_dir($output_opt);
            }
            else
            {
                print "Warning: directory \"$output_opt\" already exists, are you sure you want to store data here [Y]? ";
                my $response = <>;
                chomp $response;
                if ($response eq 'y' or $response eq 'Y' or $response eq '')
                {
                    $pipeline->set_job_dir($output_opt);
                }
                else
                {
                    die "Directory \"$output_opt\" already exists, could not continue.";
                }
            }
        }
        else
        {
            mkdir $output_opt if (not -e $output_opt);
            $pipeline->set_job_dir($output_opt);
        }
    }
    else
    {
        die "No value defined for --output.";
    }
    
    if (defined $pid_cutoff_opt)
    {
        if ($pid_cutoff_opt !~ /^\d+$/)
        {
            print STDERR "pid-cutoff value $pid_cutoff_opt is invalid\n";
            usage;
            exit 1;
        }
        elsif ($pid_cutoff_opt < 0 or $pid_cutoff_opt > 100)
        {
            print STDERR "pid-cutoff value $pid_cutoff_opt must be in [0,100]\n";
            usage;
            exit 1;
        }
        else
        {
            $pipeline->set_pid_cutoff($pid_cutoff_opt);
        }
    }
    else
    {
        $pipeline->set_pid_cutoff($pid_cutoff_default);
    }
    
    if (defined $hsp_length_opt)
    {
        if ($hsp_length_opt !~ /^\d+$/)
        {
            print STDERR "hsp-length value $hsp_length_opt is invalid\n";
            usage;
            exit 1;
        }
        elsif ($hsp_length_opt < 0)
        {
            print STDERR "hsp-length value $hsp_length_opt must be > 0\n";
            usage;
            exit 1;
        }
        else
        {
            $pipeline->set_hsp_length($hsp_length_opt);
        }
    }
    else
    {
        $pipeline->set_hsp_length($hsp_length_default);
    }
    
    if (defined $end_stage_opt)
    {
        if (not $pipeline->is_valid_stage($end_stage_opt))
        {
            die "Cannot resubmit to invalid stage $end_stage_opt";
        }
        else
        {
            $pipeline->set_end_stage($end_stage_opt);
        }
    }
    
    if (defined $start_stage_opt)
    {
        if (not $pipeline->is_valid_stage($start_stage_opt))
        {
            die "Cannot resubmit to invalid stage $start_stage_opt";
        }
        else
        {
            $pipeline->set_start_stage($start_stage_opt);
        }
    }
}

$pipeline->execute;

=pod

=head1 NAME

snp_phylogenomics_control.pl:  Script to automate running of core SNP analysis.

=head1 DESCRIPTION

Runs the core SNP phylogenomic analysis stages.  The input is either a directory containing the FASTA files to analyize, or the multi-fasta file to analyze.  The output is the pseudoalign.phy alignment file and the snpreport.txt. The intermediate files are kept under a directory (named using --output), and can be used to resubmit the analysis at different stages later.

=head1 INPUT

Input is in the form of a directory of fasta-formatted files, one file per strain.  The files should be multi-fasta files containing all of the genes for that particular strain.

=head2 FASTA Directory

Use B<--input-dir [name]> to define the fasta input directory.  The input files will be checked for validity.  The count of the files in this directory will be used for the strain count.

=head1 OUTPUT

Use B<--output [OUT_NAME]> to define an output directory.  The output directory must be accessible by the cluster nodes.  Files for each stage will be written under the output directory.  In addition, a log/ directory will be written with log files for each stage.  The final results will be available under OUT_NAME/pseudoalign.

=head1 REQUIRED

=over 8

=item B<--output [directory> :  The directory to store the analysis data, required only for a new analysis.

=item B<--input-dir [directory]> :  The input directory to process.

=item B<--processors [integer]>:  The number of processors we will run the SGE jobs with.

=back

=head1 OPTIONAL

=over 8

=item B<--verbose>:  Print more information.

=item B<--pid-cutoff [real]>:  The pid cutoff to use.

=item B<--hsp-length [integer]>:  The hsp length to use.

=back

=head1 DEPENDENCIES

This script assumes you are running on a cluster environment.  Standard batch-queuing tools must be installed (qstat, qsub, etc).  As well, blast, clustalw, and BioPerl must be installed. In order to build the phylogenetic tree automatically, phyml and figtree must be installed, otherwise the pipeline will stop running before building the tree.

=head1 EXAMPLE

=over 1

=item snp_phylogenomics_control.pl --processors 480 --input-dir sample/ --output data

=back

This example will run the analysis on all fasta files under sample/, using a randomly chosing file from sample/ as the split file, and data/ as the directory to place all analysis files.  We will run the job using 480 processors on the cluster.

=over 1

=item snp_phylogenomics_control.pl --resubmit data --start-stage alignment

This example will resubmit a previously run job (under directory data/), starting from the alignment stage.

=head1 AUTHOR

Aaron Petkau - aaron.petkau@phac-aspc.gc.ca

Gary Van Domselaar - gary_van_domselaar@phac-aspc.gc.ca

=cut

1;
