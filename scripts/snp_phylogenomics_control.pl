#!/usr/bin/env perl

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
use Pipeline::Mapping;
use Pipeline::PrepareFastq;

my $pod_sections = "SYNOPSIS";
my $pod_sections_long = "NAME|SYNOPSIS|OPTIONS|STAGES";
my $script_dir = $FindBin::Bin;

my $verbose = 0;
my $keep_files = 0;

my $pid_cutoff_default = 99;
my $hsp_length_default = 400;

sub handle_input_fastq
{
	my ($pipeline,$input_dir_opt) = @_;

	if (not defined $input_dir_opt)
	{
		die "Error: no input directory defined";
	}
	elsif (not -d $input_dir_opt)
	{
		die "Error: input_dir=$input_dir_opt is not a directory";
	}
	else
	{
		$pipeline->set_input_fastq($input_dir_opt);
	}
}

sub handle_input_fasta
{
	my ($pipeline, $input_dir_opt, $strain_count_opt) = @_;

	if (defined $input_dir_opt)
	{
		if (not -d $input_dir_opt)
		{
			print STDERR "Error: input fasta directory $input_dir_opt is not a directory\n";
			pod2usage(-verbose => 99, -sections => $pod_sections);
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
					pod2usage(-verbose => 99, -sections => $pod_sections);
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

sub handle_processors
{
	my ($pipeline, $processors) = @_;

	if (defined $processors)
	{
		if ($processors !~ /^\d+$/)
		{
			print STDERR "Processors option must be a number\n";
			pod2usage(-verbose => 99, -sections => $pod_sections);
			exit 1;
		}
		else
		{
			$pipeline->set_processors($processors);
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
		print STDERR "No value defined for --output\n";
		pod2usage(-verbose => 99, -sections => $pod_sections);
		exit 1;
	}
}

sub parse_mapping_opts
{
	my ($options, $pipeline) = @_;

	if (defined $options->{'reference'})
	{
		die "Reference file ".$options->{'reference'}." does not exist" if (not -e $options->{'reference'});
		$pipeline->set_reference($options->{'reference'});

		handle_output_opt($pipeline, $options->{'o'});
		handle_input_fastq($pipeline, $options->{'d'});
		parse_stage_opts($options,$pipeline);
	}
	else
	{
		die "Error: reference not defined";
	}
	if (defined $options->{'invalid-pos'})
	{
	    $pipeline->set_input_invalid_positions($options->{'invalid-pos'});
	}
}

sub parse_prepare_fastq_opts
{
	my ($options, $pipeline) = @_;

	if (defined $options->{'reference'})
	{
		die "Reference file ".$options->{'reference'}." does not exist" if (not -e $options->{'reference'});
		$pipeline->set_reference($options->{'reference'});

		handle_output_opt($pipeline, $options->{'o'});
		handle_input_fastq($pipeline, $options->{'d'});
		parse_stage_opts($options,$pipeline);
	}
	else
	{
		die "Error: reference not defined";
	}
}

sub parse_ortho_opts
{
	my ($options, $pipeline) = @_;

	if (defined $options->{'orthomcl-groups'})
	{
		die "Orthomcl groups file ".$options->{'orthomcl-groups'}." does not exist" if (not -e $options->{'orthomcl-groups'});
	
		$pipeline->set_orthologs_group($options->{'orthomcl-groups'});

		handle_input_fasta($pipeline, $options->{'d'}, $options->{'c'});
		handle_output_opt($pipeline, $options->{'o'});
		parse_stage_opts($options,$pipeline);
	}
	else
	{
		die "Error: orthomcl-groups option not defined\n";
	}
}

sub parse_stage_opts
{
	my ($options, $pipeline) = @_;

	if (defined $options->{'end-stage'})
	{
		my $end_stage_opt = $options->{'end-stage'};
		if (not $pipeline->is_valid_stage($end_stage_opt))
		{
			die "Cannot resubmit to invalid stage $end_stage_opt";
		}
		else
		{
			$pipeline->set_end_stage($end_stage_opt);
		}
	}
	
	if (defined $options->{'start-stage'})
	{
		my $start_stage_opt = $options->{'start-stage'};
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

sub parse_resubmit_opts
{
	my ($options, $pipeline) = @_;

	if (defined $options->{'r'})
	{
		if (defined $options->{'end-stage'})
		{
			if (not $pipeline->is_valid_stage($options->{'end-stage'}))
			{
				die "Cannot resubmit to invalid stage ".$options->{'end-stage'};
			}
			else
			{
				$pipeline->set_end_stage($options->{'end-stage'});
			}
		}
		
		if (defined $options->{'start-stage'})
		{
			if (not $pipeline->is_valid_stage($options->{'start-stage'}))
			{
				die "Cannot resubmit to invalid stage ".$options->{'start-stage'};
			}
			else
			{
				$pipeline->set_start_stage($options->{'start-stage'});
			}
		}
	}
}

sub parse_blast_opts
{
	my ($options, $pipeline) = @_;
	
	
	if (defined $options->{'p'})
	{
		handle_processors($pipeline, $options->{'p'});
	}
	
	if (defined $options->{'keep-files'} and $options->{'keep-files'})
	{
		$pipeline->set_keep_files(1);
	}
	
	if (defined $options->{'d'})
	{
		handle_input_fasta($pipeline, $options->{'d'}, $options->{'c'});
	}
	elsif (defined $options->{'i'})
	{
		my $input_files_opt = $options->{'i'};
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
			pod2usage(-verbose => 99, -sections => $pod_sections);
			exit 1;
		}
	}
	else
	{
		print STDERR "Error: no input files defined, please specify --input-dir or --input-file\n";
		print STDERR "Or specify --help for more information\n";
		pod2usage(-verbose => 99, -sections => $pod_sections);
		exit 1;
	}
	
	handle_output_opt($pipeline, $options->{'o'}, $options->{'force-output-dir'});
	
	if (defined $options->{'pid-cutoff'})
	{
		my $pid_cutoff_opt = $options->{'pid-cutoff'};
		if ($pid_cutoff_opt !~ /^\d+\.?\d*$/)
		{
			print STDERR "pid-cutoff value $pid_cutoff_opt is invalid\n";
			pod2usage(-verbose => 99, -sections => $pod_sections);
			exit 1;
		}
		elsif ($pid_cutoff_opt < 0 or $pid_cutoff_opt > 100)
		{
			print STDERR "pid-cutoff value $pid_cutoff_opt must be in [0,100]\n";
			pod2usage(-verbose => 99, -sections => $pod_sections);
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
	
	if (defined $options->{'hsp-length'})
	{
		my $hsp_length_opt = $options->{'hsp-length'};
		if ($hsp_length_opt !~ /^\d+$/)
		{
			print STDERR "hsp-length value $hsp_length_opt is invalid\n";
			pod2usage(-verbose => 99, -sections => $pod_sections);
			exit 1;
		}
		elsif ($hsp_length_opt < 0)
		{
			print STDERR "hsp-length value $hsp_length_opt must be > 0\n";
			pod2usage(-verbose => 99, -sections => $pod_sections);
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
	
	parse_stage_opts($options,$pipeline);

	return $pipeline;
}

############
##  MAIN  ##
############

my $mode;
my $help;

my %options;

if (!GetOptions(\%options,
	'm|mode=s',
	'r|resubmit=s',
	'start-stage=s',
	'end-stage=s',
	'p|processors=i',
	'd|input-dir=s',
	'i|input-file=s@',
	'reference=s',
	'o|output=s',
	'k|keep-files',
	'pid-cutoff=f',
	'hsp-length=i',
	'v|verbose+',
	'config=s',
	'h|help',
	'copy-input',
	'force-output-dir',
	'orthomcl-groups=s',
	'invalid-pos=s',
	'c|strain-count=i'))
{
	pod2usage(-verbose => 99, -sections => $pod_sections);
	die "$!";
}

if (defined $options{'h'})
{
	pod2usage(-verbose => 99, -sections => $pod_sections_long, -exitval => 0);
}

my $pipeline;
if (defined $options{'r'})
{
	if ($options{'r'} ne '' and (-d $options{'r'}))
	{
		my $pipeline = Pipeline::ResubmitFrom($script_dir, $options{'r'});
		parse_resubmit_opts(\%options, $pipeline);
		$pipeline->execute;
	}
	else
	{
		die "Invalid directory '".$options{'r'}."' to resubmit from";
	}
}
elsif (not defined $options{'m'})
{
	warn "Warning: no mode defined, defaulting to BLAST pipeline mode.\n";
	$pipeline = new Pipeline::Blast($script_dir,$options{'config'});
	$pipeline->set_verbose($options{'v'}) if (defined $options{'v'}); 
	$pipeline->set_input_copy(1) if (defined $options{'copy-input'});
	parse_blast_opts(\%options, $pipeline);
	$pipeline->execute;
}
elsif ($options{'m'} eq 'blast')
{
	$pipeline = new Pipeline::Blast($script_dir,$options{'config'});
	$pipeline->set_verbose($options{'v'}) if (defined $options{'v'}); 
	$pipeline->set_input_copy(1) if (defined $options{'copy-input'});
	parse_blast_opts(\%options, $pipeline);
	$pipeline->execute;
}
elsif ($options{'m'} eq 'orthomcl')
{
	$pipeline = new Pipeline::Orthomcl($script_dir,$options{'config'});
	$pipeline->set_verbose($options{'v'}) if (defined $options{'v'}); 
	$pipeline->set_input_copy(1) if (defined $options{'copy-input'});
	parse_ortho_opts(\%options, $pipeline);
	$pipeline->execute;
}
elsif ($options{'m'} eq 'mapping')
{
	$pipeline = new Pipeline::Mapping($script_dir,$options{'config'});
	$pipeline->set_verbose($options{'v'}) if (defined $options{'v'}); 
	$pipeline->set_input_copy(1) if (defined $options{'copy-input'});
	parse_mapping_opts(\%options,$pipeline);
	$pipeline->execute;
}
elsif ($options{'m'} eq 'prepare-fastq')
{
	$pipeline = new Pipeline::PrepareFastq($script_dir,$options{'config'});
	$pipeline->set_verbose($options{'v'}) if (defined $options{'v'}); 
	parse_prepare_fastq_opts(\%options,$pipeline);
	$pipeline->execute;
}
else
{
	print STDERR "Error: invalid mode (".$options{'m'}.") defined\n";
	pod2usage(-verbose => 99, -sections => $pod_sections, -exitval => 1);
}

exit 0;

=pod

=head1 NAME

snp_phylogenomics_control.pl:  Script to automate running of core SNP analysis.

=head1 SYNOPSIS

=head2 BLAST

=over

=item snp_phylogenomics_control.pl --mode blast --input-dir sample/ --output out

=item snp_phylogenomics_control.pl --mode blast --resubmit out/ --start-stage pseudoalign

=back

=head2 ORTHOMCL

=over

=item snp_phylogenomics_control.pl --mode orthomcl --input-dir sample/ --output out --orthomcl-groups groups.txt

=back

=head2 MAPPING

=over

=item snp_phylogenomics_control.pl --mode prepare-fastq --input-dir sample_fastq/ --output out --reference ref.fasta [--config options.conf]


=item snp_phylogenomics_control.pl --mode mapping --input-dir out/downsampled_fastq/ --output out --reference ref.fasta [--config options.conf] [--invalid-pos bad_pos.tsv]


=back

=head2 More Documentation

For more documentation, please see the README.md file or go to https://github.com/apetkau/core-phylogenomics

=back

=head1 DESCRIPTION

Runs the core SNP phylogenomic analysis stages.  The input is either a directory containing the FASTQ files to analyize, the multi-fasta file to analyze, or the raw reads to analyze.  The output is the pseudoalign.phy alignment file and the snpreport.txt. The intermediate files are kept under a directory (named using --output), and can be used to resubmit the analysis at different stages later.

=head1 INPUT

Input is in the form of a directory of fasta or fastq formatted files, one file per strain.  The fastq files should be multi-fasta files containing all of the genes for that particular strain.  The fastq files should be all the raw reads for each particular strain.

=head2 FASTA/FASTQ Directory

Use B<--input-dir [name]> to define the fasta/fastq input directory.  The input files will be checked for validity.  The count of the files in this directory will be used for the strain count.

=head1 OUTPUT

Use B<--output [OUT_NAME]> to define an output directory.  The output directory must be accessible by the cluster nodes.  Files for each stage will be written under the output directory.  In addition, a log/ directory will be written with log files for each stage.  The final results will be available under OUT_NAME/pseudoalign.

=head1 CONFIG

Special config files can be passed (used only in mapping/prepare-fastq stages) to define complex parameters.  An example of these files are:

=head2 PREPARE FASTQ

=over

=item %YAML 1.1

=item ---

=item max_coverage: 50

=item trim_clean_params: '--min_quality 30 --bases_to_trim 10 --min_avg_quality 35 --min_length 60 -p 1'

=back

=head2 MAPPING

=over

=item %YAML 1.1

=item ---

=item min_coverage: 15

=item freebayes_params: '--pvar 0 --ploidy 1 --no-mnps --left-align-indels --min-mapping-quality 30 --min-base-quality 30 --indel-exclusion-window 5 --min-alternate-fraction 0.75'

=item smalt_index: '-k 13 -s 1'

=item smalt_map: '-n 1 -f samsoft'

=back

=head1 OPTIONS

=head2 REQUIRED

=over

=item B<-d|--input-dir [directory]> :  The input directory containing the fasta/fastq files to process.

=item B<-o|--output [directory> :  The directory to store the analysis data, required only for a new analysis.

=back

=head2 OPTIONAL

=over

=item B<-m|--mode [mode]>:  The mode to run the pipeline in.  One of 'blast', 'orthomcl', or 'mapping'.

=item B<-r|--resubmit [job dir]>:  Resubmits the given job directory through the pipeline.

=item B<-p|--processors [integer]>:  The number of processors we will run the SGE jobs with.

=item B<-i|--input-file [file]>:  Specify an individual fasta file to process.

=item B<--start-stage [stage]>:  The stage to start on.

=item B<--end-stage [stage]>:  The stage to end on.

=item B<--config [config file]>:  A custom config file which can override some default options.

=item B<--force-output-dir>:  Forces use of output directory even if it already exists.

=item B<-v|--verbose>:  Print more information.

=item B<-h|--help>:  Display documentation.

=item B<--copy-input>:  Copy input files instead of just using a symlink, useful for dealing with I/O when running many instances of the pipeline.

=back

=head3 BLAST

=over

=item B<--pid-cutoff [real]>:  The pid cutoff to use.

=item B<--hsp-length [integer]>:  The hsp length to use.

=back

=head3 ORTHOMCL

=over

=item B<--orthomcl-groups>:  The orthomcl groups file.

=back

=head3 MAPPING

=over

Runs reference mapping version of pipeline.  Data must be prepared with 'prepare-fastq' mode first.  This can be run as below:

=item snp_phylogenomics_control.pl --mode prepare-fastq --input-dir sample_fastq/ --output out --reference ref.fasta [--config options.conf]

Once data is prepared, the out/downsampled_fastq directory will contain prepared/cleaned data to be used for rest of pipeline.

=item B<--reference>:  The reference file (multi-fasta, one entry per chromosome) to map to.

=item B<--invalid-pos [file]>:  A TSV file contain a list of range(s) (one per line) of positions to ignore reference(s). 


=back


=head1 STAGES

=head2 BLAST

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

=head2 ORTHOMCL

=over

=item B<prepare-orthomcl>:  Prepares the core gene files from the orthomcl groups file.

=item B<alignment>:  Performs multiple alignment on each ortholog.

=item B<pseudoalign>:  Creates a pseudoalignment.

=item B<build-phylogeny>:  Builds the phylogeny based on the pseudoalignment.

=item B<phylogeny-graphic>:  Builds a graphic image of the phylogeny.

=back

=head2 MAPPING

=over

=item B<reference-mapping>:  Performs reference mapping (using smalt).

=item B<mpileup>:  Runs mpileup (for error checking/validating SNPs).

=item B<variant-calling>:  Variant calling using freebayes.

=item B<pseudoalign>:  Generates pseudoalignment file.

=item B<vcf2core>: Computes percent of genome used for analysis.

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

Gary Van Domselaar <gary.van.domselaar@phac-aspc.gc.ca>

Philip Mabon <philip.mabon@phac-aspc.gc.ca>

=cut

1;
