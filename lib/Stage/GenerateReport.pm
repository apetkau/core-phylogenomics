#!/usr/bin/perl

package Stage::GenerateReport;
use Stage;
@ISA = qw(Stage);

use strict;
use warnings;

sub new
{
        my ($proto, $file_manager, $job_properties, $logger) = @_;
        my $class = ref($proto) || $proto;
        my $self = $class->SUPER::new($file_manager, $job_properties, $logger);

        bless($self,$class);

	$self->{'_stage_name'} = 'report';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $verbose = $self->{'_logger'}->{'verbose'};
	my $job_properties = $self->{'_job_properties'};
	my $working_dir = $self->{'_file_manager'}->get_dir('pseudoalign_dir');
	my $script_dir = $self->{'_file_manager'}->get_script_dir;
	my $core_dir = $self->{'_file_manager'}->get_dir('core_dir');
	my $align_dir = $self->{'_file_manager'}->get_dir('align_dir');
	my $fasta_dir = $self->{'_file_manager'}->get_dir('fasta_dir');
	my $input_dir = $self->{'_file_manager'}->get_job_dir;
	my $output_file = "$working_dir/main.report";
	my $log_dir = $self->{'_file_manager'}->get_dir('log_dir');

	my $log_file = "$log_dir/generate_report.log";

	$logger->log("\nStage: $stage\n",0);
	$logger->log("Generating report ...\n",0);

	require("$script_dir/snp_phylogenomics_report.pl");
	Report::run($core_dir,$align_dir,$fasta_dir,$input_dir,$output_file,$verbose);
	$logger->log("...done\n",0);
}

1;
