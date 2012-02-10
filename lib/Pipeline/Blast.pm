#!/usr/bin/perl

package Pipeline::Blast;
use Pipeline;
@ISA = qw(Pipeline);

use strict;
use warnings;

use Logger;
use JobProperties;

use Stage;
use Stage::BuildFasta;
use Stage::WriteProperties;
use Stage::CreateDatabase;
use Stage::PerformSplit;
use Stage::PerformBlast;
use Stage::FindCore;
use Stage::AlignOrthologs;
use Stage::Pseudoalign;
use Stage::GenerateReport;
use Stage::BuildPhylogeny;
use Stage::BuildPhylogenyGraphic;

use File::Basename qw(basename dirname);
use File::Copy qw(copy move);
use File::Path qw(rmtree);
use Cwd qw(abs_path);


sub new
{
    my ($proto,$script_dir) = @_;

    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new($script_dir);
    bless($self,$class);

    $self->_setup_stage_tables;

    $self->_check_stages;

    my $job_properties = $self->{'job_properties'};
    $job_properties->set_property('pid_cutoff', 99);
    $job_properties->set_property('hsp_length', 400);

    $job_properties->set_file('all_input_fasta', 'all.fasta');
    $job_properties->set_file('bioperl_index', 'all.fasta.idx');
    $job_properties->set_file('core_snp_base', 'snps');
    $job_properties->set_dir('log_dir', "log");
    $job_properties->set_dir('fasta_dir', "fasta");
    $job_properties->set_dir('database_dir', "database");
    $job_properties->set_dir('split_dir', "split");
    $job_properties->set_dir('blast_dir', "blast");
    $job_properties->set_dir('core_dir', "core");
    $job_properties->set_dir('align_dir', "align");
    $job_properties->set_dir('pseudoalign_dir', "pseudoalign");
    $job_properties->set_dir('stage_dir', "stages");
    $job_properties->set_dir('phylogeny_dir', 'phylogeny');

    return $self;
}

sub _setup_stage_tables
{
	my ($self) = @_;
	my $stage = {};

	$self->{'stage'} = $stage;
	$stage->{'all'} = ['prepare-input',
	                  'write-properties',
	                  'build-database',
	                  'split',
	                  'blast',
	                  'core',
	                  'alignment',
	                  'pseudoalign',
	                  'report',
	                  'build-phylogeny',
	                  'phylogeny-graphic'
	                 ];
	my %all_hash = map { $_ => 1} \@{$stage->{'all'}};
	$stage->{'all_hash'} = \%all_hash;
	
	$stage->{'user'} = ['prepare-input',
	                       'build-database',
	                       'split',
	                       'blast',
	                       'core',
	                       'alignment',
	                       'pseudoalign',
	                       'build-phylogeny',
	                       'phylogeny-graphic',
			];
	
	$stage->{'descriptions'} = ['Prepares and checks input files.',
	                          'Builds database for blasts.',
	                          'Splits input file among processors.',
	                          'Performs blast to find core genome.',
	                          'Attempts to identify snps from core genome.',
	                          'Performs multiple alignment on each ortholog.',
	                          'Creates a pseudoalignment.',
	                          'Builds the phylogeny based on the pseudoalignment.',
	                          'Builds a graphic image of the phylogeny.'
	                         ];

	$stage->{'valid_job_dirs'} = ['job_dir','log_dir','fasta_dir','database_dir','split_dir','blast_dir','core_dir',
	                  'align_dir','pseudoalign_dir','stage_dir','phylogeny_dir'];
	$stage->{'valid_other_files'} = ['input_fasta_dir','split_file','input_fasta_files'];

	my @valid_properties = join(@{$stage->{'valid_job_dirs'}},@{$stage->{'valid_other_files'}},'hsp_length','pid_cutoff');
	$stage->{'valid_properties'} = \@valid_properties;
}

sub _get_strain_ids
{
	my ($self,$fasta_input) = @_;

	opendir(my $dh, $fasta_input) or die "Could not open directory $fasta_input: $!";
	my @strain_ids = map {/(.*).fasta$/; $1;} grep {/\.fasta$/} readdir($dh);
	closedir($dh);

	return \@strain_ids;
}

sub set_hsp_length
{
    my ($self,$length) = @_;
    $self->{'job_properties'}->set_property('hsp_length', $length);
}

sub set_pid_cutoff
{
    my ($self,$pid_cutoff) = @_;

    $self->{'job_properties'}->set_property('pid_cutoff', $pid_cutoff);
}

sub set_processors
{
    my ($self,$processors) = @_;
    $self->{'job_properties'}->set_property('processors', $processors);
}

sub set_input_fasta
{
    my ($self,$file) = @_;

    die "File $file does not exists" if (not -e $file);

    my $abs_input_fasta = abs_path($file);

    if (-d $abs_input_fasta)
    {
        $self->{'job_properties'}->set_abs_dir('input_fasta_dir', $abs_input_fasta);
    }
    else
    {
        my $input_fasta_files = $self->{'job_properties'}->get_property('input_fasta_files');
        if (not defined $input_fasta_files)
        {
            $input_fasta_files = [];
            $self->{'job_properties'}->set_property('input_fasta_files', $input_fasta_files);
        }

        push(@$input_fasta_files, $abs_input_fasta);
    }
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

    my $stage_table = { 'prepare-input' => new Stage::BuildFasta($job_properties, $logger),
                        'write-properties' => new Stage::WriteProperties($job_properties, $logger),
                        'build-database' => new Stage::CreateDatabase($job_properties, $logger),
                        'split' => new Stage::PerformSplit($job_properties, $logger),
                        'blast' => new Stage::PerformBlast($job_properties, $logger),
                        'core' => new Stage::FindCore($job_properties, $logger),
                        'alignment' => new Stage::AlignOrthologs($job_properties, $logger),
                        'pseudoalign' => new Stage::Pseudoalign($job_properties, $logger),
                        'report' => new Stage::GenerateReport($job_properties, $logger),
                        'build-phylogeny' => new Stage::BuildPhylogeny($job_properties, $logger),
                        'phylogeny-graphic' => new Stage::BuildPhylogenyGraphic($job_properties, $logger)
        };

    $self->{'stage_table'} = $stage_table;
}

1;
