#!/usr/bin/env perl

package Pipeline::Mapping;
use Pipeline;
@ISA = qw(Pipeline);

use strict;
use warnings;

use Logger;
use JobProperties;

use Stage;
use Stage::CopyInputReference;
use Stage::CopyInputFastq;
use Stage::WriteProperties;
use Stage::SmaltMapping;
use Stage::BuildPhylogeny;
use Stage::BuildPhylogenyGraphic;
use Stage::GenerateReportOrthoMCL;
use Stage::Mpileup;
use Stage::VariantCalling;
use Stage::VcfPseudoalignment;
use Stage::FastQC;
use Stage::MappingFinal;
use Stage::VcfCore;
use Stage::CopyInputInvalid;
use File::Basename qw(basename dirname);
use File::Copy qw(copy move);
use File::Path qw(rmtree);
use Cwd qw(abs_path);


sub new
{
    my ($proto,$script_dir,$custom_config) = @_;

    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new($script_dir,$custom_config);
    bless($self,$class);

    $self->_setup_stage_tables;

    $self->_check_stages;

    my $job_properties = $self->{'job_properties'};
    $job_properties->set_property('mode', 'mapping');

    $job_properties->set_dir('mapping_dir', "mapping");
    $job_properties->set_dir('pseudoalign_dir', "pseudoalign");
    $job_properties->set_dir('stage_dir', "stages");
    $job_properties->set_dir('phylogeny_dir', 'phylogeny');
    $job_properties->set_dir('fastq_dir', 'fastq');
    $job_properties->set_dir('sam_dir', 'sam');
    $job_properties->set_dir('bam_dir', 'bam');
    $job_properties->set_dir('mpileup_dir', 'mpileup');
    $job_properties->set_dir('reference_dir', 'reference');
    $job_properties->set_dir('vcf_dir', 'vcf');
    $job_properties->set_dir('pseudoalign_dir', 'pseudoalign');
    $job_properties->set_dir('vcf2core_dir', 'vcf2core');
    $job_properties->set_dir('vcf_split_dir', 'vcf-split');
    $job_properties->set_dir('fasta_dir', 'contig_dir');
    $job_properties->set_dir('invalid_pos_dir', 'invalid');

    return $self;
}

sub new_resubmit
{
    my ($proto,$script_dir, $job_properties) = @_;

    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new_resubmit($script_dir, $job_properties);
    bless($self,$class);

    $self->_setup_stage_tables;

    $self->_check_stages;

    $job_properties->set_dir('mapping_dir', "mapping");
    $job_properties->set_dir('pseudoalign_dir', "pseudoalign");
    $job_properties->set_dir('stage_dir', "stages");
    $job_properties->set_dir('phylogeny_dir', 'phylogeny');
    $job_properties->set_dir('fastq_dir', 'fastq');
    $job_properties->set_dir('sam_dir', 'sam');
    $job_properties->set_dir('bam_dir', 'bam');
    $job_properties->set_dir('mpileup_dir', 'mpileup');
    $job_properties->set_dir('reference_dir', 'reference');
    $job_properties->set_dir('vcf_dir', 'vcf');
    $job_properties->set_dir('pseudoalign_dir', 'pseudoalign');
    $job_properties->set_dir('vcf_split_dir', 'vcf-split');
    $job_properties->set_dir('mapping_dir', "mapping");
    $job_properties->set_dir('pseudoalign_dir', "pseudoalign");
    $job_properties->set_dir('stage_dir', "stages");
    $job_properties->set_dir('phylogeny_dir', 'phylogeny');
    $job_properties->set_dir('fastq_dir', 'fastq');
    $job_properties->set_dir('sam_dir', 'sam');
    $job_properties->set_dir('bam_dir', 'bam');
    $job_properties->set_dir('mpileup_dir', 'mpileup');
    $job_properties->set_dir('reference_dir', 'reference');
    $job_properties->set_dir('vcf_dir', 'vcf');
    $job_properties->set_dir('pseudoalign_dir', 'pseudoalign');
    $job_properties->set_dir('vcf2core_dir', 'vcf2core');
    $job_properties->set_dir('vcf_split_dir', 'vcf-split');
    $job_properties->set_dir('fasta_dir', 'contig_dir');
    $job_properties->set_dir('invalid_pos_dir', 'invalid');

    return $self;
}

sub set_reference
{
	my ($self,$reference) = @_;

	die "Error: reference undefined" if (not defined $reference);
	die "Error: reference does not exist" if (not -e $reference);

	my $abs_reference_path = abs_path($reference);
	die "Error: abs path for reference not defined" if (not defined $abs_reference_path);
	$self->{'job_properties'}->set_abs_file('input_reference',$abs_reference_path);

	my $reference_name = basename($abs_reference_path);
	die "Undefined reference name" if (not defined $reference_name);
	$self->{'job_properties'}->set_file('reference',$reference_name);
}

sub set_input_invalid_positions
{
	my ($self,$invalid) = @_;

	die "Error: invalid undefined" if (not defined $invalid);
	die "Error: invalid does not exist" if (not -e $invalid);

	my $abs_invalid_path = abs_path($invalid);
	die "Error: abs path for invalid not defined" if (not defined $abs_invalid_path);
	$self->{'job_properties'}->set_abs_file('input_invalid',$abs_invalid_path);

	my $invalid_name = basename($abs_invalid_path);
	die "Undefined invalid name" if (not defined $invalid_name);
	$self->{'job_properties'}->set_file('invalid',$invalid_name);
}

sub set_input_fastq
{
	my ($self,$fastq_dir) = @_;

	die "Error: fastq_dir not defined" if (not defined $fastq_dir);
	die "Error: fastq_dir not a directory" if (not -d $fastq_dir);

	my $abs_fastq_path = abs_path($fastq_dir);
	die "Error: abs path for fastq_dir not defined" if (not defined $abs_fastq_path);
	$self->{'job_properties'}->set_abs_file('input_fastq_dir',$abs_fastq_path);
}

sub _setup_stage_tables
{
	my ($self) = @_;
	my $stage = {};

	$self->{'stage'} = $stage;
	$stage->{'all'} = [
	                  'write-properties',
			  'copy-input-reference',
			  'copy-input-invalid-positions',
			  'copy-input-fastq',
			  'copy-input-fasta',
			  'reference-mapping',
			  'mpileup',
			  'variant-calling',
			  'pseudoalign',
	                  'vcf2core',
	                  'build-phylogeny',
	                  'phylogeny-graphic',
			  'mapping-final'
	                 ];
	my %all_hash = map { $_ => 1} @{$stage->{'all'}};
	$stage->{'all_hash'} = \%all_hash;
	
	$stage->{'user'} = [
			    'reference-mapping',
			    'mpileup',
			    'variant-calling',
			    'pseudoalign',
                  	    'vcf2core',
	                    'build-phylogeny',
	                    'phylogeny-graphic',
			];
	
	$stage->{'valid_job_dirs'} = ['pseudoalign_dir', 'vcf2core_dir', 'vcf_dir', 'vcf_split_dir', 'mpileup_dir', 'bam_dir', 'sam_dir', 'mapping_dir', 'reference_dir','job_dir','log_dir','align_dir','stage_dir','phylogeny_dir', 'fastq_dir','fasta_dir'];
	#$stage->{'valid_other_files'} = ['input_fastq_dir'];
	$stage->{'valid_other_files'} = [];

	my @valid_properties = join(@{$stage->{'valid_job_dirs'}},@{$stage->{'valid_other_files'}});
	$stage->{'valid_properties'} = \@valid_properties;
}

sub _initialize
{
    my ($self) = @_;

    my $job_properties = $self->{'job_properties'};
    $job_properties->build_job_dirs;

    my $log_dir = $job_properties->get_dir('log_dir');
    my $verbose = $self->{'verbose'};

    my $logger = new Logger($log_dir, $verbose);
    $self->{'logger'} = $logger;

    my $stage_table = {
                        'write-properties' => new Stage::WriteProperties($job_properties, $logger),
			'copy-input-reference' => new Stage::CopyInputReference($job_properties, $logger),
			'copy-input-invalid-positions' => new Stage::CopyInputInvalid($job_properties, $logger),
			'copy-input-fastq' => new Stage::CopyInputFastq($job_properties, $logger),
			'copy-input-fasta' => new Stage::CopyInputFasta($job_properties, $logger),
			'reference-mapping' => new Stage::SmaltMapping($job_properties, $logger),
			'mpileup' => new Stage::Mpileup($job_properties, $logger),
			'variant-calling' => new Stage::VariantCalling($job_properties, $logger),
			'pseudoalign' => new Stage::VcfPseudoalignment($job_properties, $logger),
			'vcf2core' => new Stage::VcfCore($job_properties, $logger),
                        'build-phylogeny' => new Stage::BuildPhylogeny($job_properties, $logger),
                        'phylogeny-graphic' => new Stage::BuildPhylogenyGraphic($job_properties, $logger),
                        'mapping-final' => new Stage::MappingFinal($job_properties, $logger)
        };

    $self->{'stage_table'} = $stage_table;
}

1;
