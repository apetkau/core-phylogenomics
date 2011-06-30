#!/usr/bin/perl

use strict;
use warnings;

use FindBin;

use lib $FindBin::Bin;

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
    print "\t-c|--strain-count [integer]:  The number of strains we are working with.\n";
    print "\t-d|--input-diri [directory]:  The directory containing the input fasta files.\n";
    print "\t-h|--help:  Print help.\n";
    print "\t-i|--input-fasta [file]:  The input fasta file.\n";
    print "\t-k|--keep-files:  Keep intermediate files around.\n";
    print "\t-o|--output [directory]:  The directory to store output (optional).\n";
    print "\t-p|--processors [integer]:  The number of processors to use.\n";
    print "\t--pid-cutoff [real]:  The pid cutoff to use (default $pid_cutoff_default).\n";
    print "\t--hsp-length [integer]:   The hsp length to use (default $hsp_length_default).\n";
    print "\t-s|--split-file [file]:  The file to use for initial split.\n";
    print "\t-v|--verbose:  Print extra information.\n";

    print "\nExample:\n";
    print "\tmaster.pl --processors 480 --input-dir sample/ --split-file sample/ECO111.fasta --output data --keep-files\n";
    print "\tRuns master.pl on data under sample/ with the passed split file and processors.\n\n";
}

############
##  MAIN  ##
############

my $verbose_opt;
my $processors_opt;
my $split_file_opt;
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

if (!GetOptions(
    'r|resubmit=s' => \$resubmit_opt,
    'start-stage=s' => \$start_stage_opt,
    'end-stage=s' => \$end_stage_opt,
    'p|processors=i' => \$processors_opt,
    's|split-file=s' => \$split_file_opt,
    'd|input-dir=s' => \$input_dir_opt,
    'o|output=s' => \$output_opt,
    'i|input-fasta=s' => \$input_fasta_opt,
    'k|keep-files' => \$keep_files_opt,
    'pid-cutoff=f' => \$pid_cutoff_opt,
    'hsp-length=i' => \$hsp_length_opt,
    'v|verbose' => \$verbose_opt,
    'h|help' => \$help_opt,
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

if (defined $verbose_opt and $verbose_opt)
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
    
    if (not defined $split_file_opt)
    {
        print STDERR "Must specify an initial split file\n";
        usage;
        exit 1;
    }
    elsif (not -e $split_file_opt)
    {
        print STDERR "Error: split file $split_file_opt does not exist\n";
        usage;
        exit 1;
    }
    else
    {
        $pipeline->set_split_file($split_file_opt);
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
        if (not defined $input_fasta_opt)
        {
            print STDERR "Error: input fasta file must be defined\n";
            usage;
            exit 1;
        }
        elsif (not -e $input_fasta_opt)
        {
            print STDERR "Error: input fasta file $input_fasta_opt does not exist\n";
            usage;
            exit 1;
        }
        else
        {
            $pipeline->set_input_fasta($input_fasta_opt);
        }
        
        if (not defined $strain_count_opt)
        {
            print STDERR "Error: strain count must be defined\n";
            usage;
            exit 1;
        }
        elsif ($strain_count_opt <= 0)
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
    
    if (defined $output_opt)
    {
        if (-e $output_opt)
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
        else
        {
            $pipeline->set_job_dir($output_opt);
        }
    }
    else
    {
        $pipeline->set_job_dir(sprintf "%08x",time);
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
        $pipeline->set_pid_cutoff($pid_cutoff_opt);
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

print "Running core SNP phylogenomic pipeline.\n";
$pipeline->execute;

=pod

=head1 NAME

master.pl:  Script to automate running of core SNP analysis.

=head1 DESCRIPTION

Runs the core SNP phylogenomic analysis stages.  The input is either a directory containing the FASTA files to analyize, or the multi-fasta file to analyze.  The output is the pseudoalign.phy alignment file and the snpreport.txt. The intermediate files are kept under a directory (named using --output), and are by default cleaned out after they aren't needed (they can be kept using --keep-files).

=head1 INPUT

Input is in two forms, either a directory containing the fasta files to analyze, or a single multi-fasta file.

=head2 FASTA Directory

Use B<--input-dir [name]> to define the fasta input directory.  The input files will be checked to see if all gene names are unique, and we will attempt to create unique names if this is not the case.  The count of the files in this directory will be used for the strain count (can be overridden with B<--strain-count>).

=head2 Multi-FASTA

Use B<--input-fasta [name]> to pass a multi-fasta formatted file containing all the strains to analyze.  The file will be checked for unique strain ids, and will fail if this is not the case.  This input option also requires passing the count of the number of strains B<--strain-count>.

=head1 OUTPUT

Use B<--output [OUT_NAME]> to define an output directory, otherwise a directory will be created for you.  The output directory must be accessible by the cluster nodes.  Files for each stage will be written under the output directory.  In addition, a log/ directory will be written with log files for each stage.  The final results will be available under OUT_NAME/pseudoalign.

=head1 REQUIRED

=over 8

=item B<--input-dir [directory]> or B<--input-fasta [file]>:  The input file or directory to process.

=item B<--strain-count [integer]> (optional if --input-dir is used):  The count of the number of strains we are processing.

=item B<--processors [integer]>:  The number of processors we will run the SGE jobs with.

=item B<--split-file [file]>:  The initial fasta file we split apart to run the SGE jobs with.

=back

=head1 OPTIONAL

=over 8

=item B<--output [directory]>:  The directory to store the analysis files under.

=item B<--keep-files>:  If set will keep intermediate files in analysis.

=item B<--verbose>:  Print more information.

=item B<--pid-cutoff [real]>:  The pid cutoff to use.

=item B<--hsp-length [integer]>:  The hsp length to use.

=back

=head1 DEPENDENCIES

This script assumes you are running on a cluster environment.  Standard batch-queuing tools must be installed (qstat, qsub, etc).  As well, blast, clustalw, and BioPerl must be installed.

=head1 EXAMPLE

=over 1

=item master.pl --processors 480 --input-dir sample/ --split-file sample/ECO111.fasta --output data --keep-files

=back

This example will run the analysis on all fasta files under sample/, using sample/ECO111.fasta as the split file, and data/ as the directory to place all analysis files.  We will run the job using 480 processors on the cluster and keep all intermediate files around.

=head1 AUTHOR

Aaron Petkau - aaron.petkau@phac-aspc.gc.ca

Gary Van Domselaar - gary_van_domselaar@phac-aspc.gc.ca

=cut

1;
