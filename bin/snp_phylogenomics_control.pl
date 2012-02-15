#!/usr/bin/perl

use strict;
use warnings;

use FindBin;

use lib $FindBin::Bin.'/../lib';

use File::Basename qw(basename dirname);
use File::Copy qw(copy move);
use File::Path qw(rmtree);
use Pod::Usage;
use Getopt::Long;
use Pipeline;
use Pipeline::Blast;
use Pipeline::Orthomcl;

my $pod_sections = "NAME|SYNOPSIS|OPTIONS|STAGES";
my $script_dir = $FindBin::Bin;

my $verbose = 0;
my $keep_files = 0;

my $pid_cutoff_default = 99;
my $hsp_length_default = 400;

sub handle_input_fasta
{
	my ($pipeline, $input_dir_opt, $strain_count_opt) = @_;

	if (defined $input_dir_opt)
	{
		if (not -d $input_dir_opt)
		{
			print STDERR "Error: input fasta directory $input_dir_opt is not a directory\n";
			pod2usage(-verbose => 99, -sections => [$pod_sections]);
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
					pod2usage(-verbose => 99, -sections => [$pod_sections]);
					exit 1;
				}
				else
				{
					$pipeline->set_strain_count($strain_count_opt);
				}
			}
		}
	}
}

sub handle_output_opt
{
    my ($pipeline, $output_opt, $force_output_dir_opt) = @_;

    if (defined $output_opt)
    {
        if (-e $output_opt)
        {
            if (-d $output_opt and (defined $force_output_dir_opt) and $force_output_dir_opt)
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
my $input_files_opt;
my $orthomcl_groups;

my $resubmit_opt;
my $start_stage_opt;
my $end_stage_opt;

if (!GetOptions(
    'r|resubmit=s' => \$resubmit_opt,
    'start-stage=s' => \$start_stage_opt,
    'end-stage=s' => \$end_stage_opt,
    'p|processors=i' => \$processors_opt,
    'd|input-dir=s' => \$input_dir_opt,
    'i|input-file=s@' => \$input_files_opt,
    'o|output=s' => \$output_opt,
    'k|keep-files' => \$keep_files_opt,
    'pid-cutoff=f' => \$pid_cutoff_opt,
    'hsp-length=i' => \$hsp_length_opt,
    'v|verbose+' => \$verbose_opt,
    'h|help' => \$help_opt,
    'force-output-dir' => \$force_output_dir_opt,
    'orthomcl-groups=s' => \$orthomcl_groups,
    'c|strain-count=i' => \$strain_count_opt))
{
    pod2usage(-verbose => 99, -sections => [$pod_sections]);
    die "$!";
}

if (defined $help_opt and $help_opt)
{
    pod2usage(-verbose => 99, -sections => [$pod_sections]);
    exit 0;
}

my $pipeline;
if (defined $orthomcl_groups)
{
	$pipeline = new Pipeline::Orthomcl($script_dir);
}
else
{
	$pipeline = new Pipeline::Blast($script_dir);
}

if (defined $verbose_opt)
{
    $pipeline->set_verbose($verbose_opt); 
}

if (defined $resubmit_opt)
{
    if (not -d $resubmit_opt)
    {
        print STDERR "Error: $resubmit_opt is an invalid job directory to resubmit from\n";
        pod2usage(-verbose => 99, -sections => [$pod_sections]);
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
elsif (defined $orthomcl_groups)
{
	die "Orthomcl groups file $orthomcl_groups does not exist" if (not -e $orthomcl_groups);

	handle_input_fasta($pipeline, $input_dir_opt, $strain_count_opt);
	handle_output_opt($pipeline, $output_opt);

	$pipeline->set_orthologs_group($orthomcl_groups);
}
else
{
    if (defined $processors_opt)
    {
        if ($processors_opt !~ /^\d+$/)
        {
            print STDERR "Processors option must be a number\n";
            pod2usage(-verbose => 99, -sections => [$pod_sections]);
            exit 1;
        }
        else
        {
            $pipeline->set_processors($processors_opt);
        }
    }
    
    if (defined $keep_files_opt and $keep_files_opt)
    {
        $pipeline->set_keep_files($keep_files_opt);
    }
    
    if (defined $input_dir_opt)
    {
        handle_input_fasta($pipeline, $input_dir_opt, $strain_count_opt);
    }
    elsif (defined $input_files_opt)
    {
        if ((ref $input_files_opt) eq 'ARRAY' and (@$input_files_opt > 0))
        {
            foreach my $in_file (@$input_files_opt)
            {
                die "Error: one of passed input files is undefind" if (not defined $in_file);
                die "Error: file=$in_file does not exist" if (not -e $in_file);
                die "Error: file=$in_file does not end in .fasta" if ($in_file !~ /\.fasta$/);
                die "Error: file=$in_file is a directory" if (-d $in_file);

            	$pipeline->set_input_fasta($in_file);
            }
        }
        else
        {
            print STDERR "Error: input-files not properly defined\n";
            pod2usage(-verbose => 99, -sections => [$pod_sections]);
            exit 1;
        }
    }
    else
    {
        print STDERR "Error: no input files defined, please specify --input-dir or --input-file\n";
        pod2usage(-verbose => 99, -sections => [$pod_sections]);
        exit 1;
    }
    
    handle_output_opt($pipeline, $output_opt, $force_output_dir_opt);
    
    if (defined $pid_cutoff_opt)
    {
        if ($pid_cutoff_opt !~ /^\d+\.?\d*$/)
        {
            print STDERR "pid-cutoff value $pid_cutoff_opt is invalid\n";
            pod2usage(-verbose => 99, -sections => [$pod_sections]);
            exit 1;
        }
        elsif ($pid_cutoff_opt < 0 or $pid_cutoff_opt > 100)
        {
            print STDERR "pid-cutoff value $pid_cutoff_opt must be in [0,100]\n";
            pod2usage(-verbose => 99, -sections => [$pod_sections]);
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
            pod2usage(-verbose => 99, -sections => [$pod_sections]);
            exit 1;
        }
        elsif ($hsp_length_opt < 0)
        {
            print STDERR "hsp-length value $hsp_length_opt must be > 0\n";
            pod2usage(-verbose => 99, -sections => [$pod_sections]);
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

=head1 SYNOPSIS

=over

=item snp_phylogenomics_control.pl --input-dir sample/ --output out

=item snp_phylogenomics_control.pl --resubmit out/ --start-stage pseudoalign

=back

=head1 DESCRIPTION

Runs the core SNP phylogenomic analysis stages.  The input is either a directory containing the FASTA files to analyize, or the multi-fasta file to analyze.  The output is the pseudoalign.phy alignment file and the snpreport.txt. The intermediate files are kept under a directory (named using --output), and can be used to resubmit the analysis at different stages later.

=head1 INPUT

Input is in the form of a directory of fasta-formatted files, one file per strain.  The files should be multi-fasta files containing all of the genes for that particular strain.

=head2 FASTA Directory

Use B<--input-dir [name]> to define the fasta input directory.  The input files will be checked for validity.  The count of the files in this directory will be used for the strain count.

=head1 OUTPUT

Use B<--output [OUT_NAME]> to define an output directory.  The output directory must be accessible by the cluster nodes.  Files for each stage will be written under the output directory.  In addition, a log/ directory will be written with log files for each stage.  The final results will be available under OUT_NAME/pseudoalign.

=head1 OPTIONS

=head2 REQUIRED

=over

=item B<-d|--input-dir [directory]> :  The input directory to process.

=item B<-o|--output [directory> :  The directory to store the analysis data, required only for a new analysis.

=back

=head2 OPTIONAL

=over

=item B<-p|--resubmit [job dir]>:  Resubmits the given job directory through the pipeline.

=item B<-p|--processors [integer]>:  The number of processors we will run the SGE jobs with.

=item B<-i|--input-file [file]>:  Specify an individual fasta file to process.

=item B<-h|--help>:  Display documentation.

=item B<-v|--verbose>:  Print more information.

=item B<--pid-cutoff [real]>:  The pid cutoff to use.

=item B<--hsp-length [integer]>:  The hsp length to use.

=item B<--start-stage [stage]>:  The stage to start on.

=item B<--end-stage [stage]>:  The stage to end on.

=item B<--force-output-dir>:  Forces use of output directory even if it already exists.

=item B<--orthomcl-groups>:  The orthomcl groups file.

=back

=head1 STAGES

=over

=item B<prepare-input>:  Prepares and checks input files.

=item B<build-database>:  Builds database for blasts.

=item B<split>:  Splits input file among processors.

=item B<blast>:  Performs blast to find core genome.

=item B<core>:  Attempts to identify snps from core genome.

=item B<alignment>:  Performs multiple alignment on each ortholog.

=item B<pseudoalign>:  Creates a pseudoalignment.

=item B<build-phylogeny>:  Builds the phylogeny based on the pseudoalignment.

=item B<phylogeny-graphic>:  Builds a graphic image of the phylogeny.

=back

=head1 DEPENDENCIES

This script assumes you are running on a cluster environment.  Standard batch-queuing tools must be installed (qstat, qsub, etc).  As well, blast, clustalw, and BioPerl must be installed. In order to build the phylogenetic tree automatically, phyml and figtree must be installed, otherwise the pipeline will stop running before building the tree.

=head1 EXAMPLE

=head2 snp_phylogenomics_control.pl --processors 480 --input-dir sample/ --output data

This example will run the analysis on all fasta files under sample/, using a randomly chosing file from sample/ as the split file, and data/ as the directory to place all analysis files.  We will run the job using 480 processors on the cluster.

=head2 snp_phylogenomics_control.pl --resubmit data --start-stage alignment

This example will resubmit a previously run job (under directory data/), starting from the alignment stage.

=head1 AUTHORS

Aaron Petkau <aaron.petkau@phac-aspc.gc.ca>

Gary Van Domselaar <gary_van_domselaar@phac-aspc.gc.ca>

=cut

1;
