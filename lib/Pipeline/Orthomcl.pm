#!/usr/bin/perl

package Pipeline::Orthomcl;
use Pipeline;
@ISA = qw(Pipeline);

use strict;
use warnings;

use Logger;
use JobProperties;

use Stage;
use Stage::WriteProperties;
use Stage::CopyInputFasta;
use Stage::PrepareOrthomcl;
use Stage::AlignOrthologs;
use Stage::Pseudoalign;
use Stage::BuildPhylogeny;
use Stage::BuildPhylogenyGraphic;
use Stage::GenerateReportOrthoMCL;

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
    $job_properties->set_property('mode', 'orthomcl');

    $job_properties->set_file('core_snp_base', 'snps');
    $job_properties->set_file('group_stats', 'group_stats');
    $job_properties->set_dir('core_dir', "core");
    $job_properties->set_dir('align_dir', "align");
    $job_properties->set_dir('pseudoalign_dir', "pseudoalign");
    $job_properties->set_dir('stage_dir', "stages");
    $job_properties->set_dir('phylogeny_dir', 'phylogeny');
    $job_properties->set_dir('fasta_dir', 'fasta');

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

    $job_properties->set_file('core_snp_base', 'snps');
    $job_properties->set_file('group_stats', 'group_stats');
    $job_properties->set_dir('core_dir', "core");
    $job_properties->set_dir('align_dir', "align");
    $job_properties->set_dir('pseudoalign_dir', "pseudoalign");
    $job_properties->set_dir('stage_dir', "stages");
    $job_properties->set_dir('phylogeny_dir', 'phylogeny');
    $job_properties->set_dir('fasta_dir', 'fasta');

    return $self;
}

sub _setup_stage_tables
{
	my ($self) = @_;
	my $stage = {};

	$self->{'stage'} = $stage;
	$stage->{'all'} = [
	                  'write-properties',
			  'copy-input-fasta',
			  'prepare-orthomcl',
	                  'alignment',
	                  'pseudoalign',
	                  'report',
	                  'build-phylogeny',
	                  'phylogeny-graphic'
	                 ];
	my %all_hash = map { $_ => 1} @{$stage->{'all'}};
	$stage->{'all_hash'} = \%all_hash;
	
	$stage->{'user'} = [
			    'prepare-orthomcl',
	                    'alignment',
	                    'pseudoalign',
	                    'build-phylogeny',
	                    'phylogeny-graphic',
			];
	
	$stage->{'valid_job_dirs'} = ['job_dir','log_dir','core_dir','align_dir','pseudoalign_dir','stage_dir','phylogeny_dir', 'fasta_dir'];
	$stage->{'valid_other_files'} = ['input_fasta_dir'];

	my @valid_properties = join(@{$stage->{'valid_job_dirs'}},@{$stage->{'valid_other_files'}});
	$stage->{'valid_properties'} = \@valid_properties;
}

sub set_orthologs_group
{
	my ($self, $orthologs_group) = @_;

	die "Error: orthologs group undefined" if (not defined $orthologs_group);
	die "Error: orthologs group file $orthologs_group does not exist" if (not -e $orthologs_group);

	my $abs_orthologs_group = abs_path($orthologs_group);

	die "Error: abs path for orthologs_group not defined" if (not defined $abs_orthologs_group);
	$self->{'job_properties'}->set_file('orthologs_group', $abs_orthologs_group);
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
			'copy-input-fasta' => new Stage::CopyInputFasta($job_properties, $logger),
                        'prepare-orthomcl' => new Stage::PrepareOrthomcl($job_properties, $logger),
                        'alignment' => new Stage::AlignOrthologs($job_properties, $logger),
                        'pseudoalign' => new Stage::Pseudoalign($job_properties, $logger),
                        'report' => new Stage::GenerateReportOrthoMCL($job_properties, $logger),
                        'build-phylogeny' => new Stage::BuildPhylogeny($job_properties, $logger),
                        'phylogeny-graphic' => new Stage::BuildPhylogenyGraphic($job_properties, $logger)
        };

    $self->{'stage_table'} = $stage_table;
}

1;
