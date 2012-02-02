#!/usr/bin/perl

package Stage::Pseudoalign;
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

	$self->{'_stage_name'} = 'pseudoalign';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $script_dir = $self->{'_file_manager'}->get_script_dir;

	my $align_input = $self->{'_file_manager'}->get_dir('align_dir');
	my $output_dir = $self->{'_file_manager'}->get_dir('pseudoalign_dir');
	my $log_dir = $self->{'_file_manager'}->get_dir('log_dir');

	die "Error: align_input directory does not exist" if (not -e $align_input);
	die "Error: pseudoalign output directory does not exist" if (not -e $output_dir);

	my $log = "$log_dir/pseudoaligner.log";

	$logger->log("\nStage: $stage\n",0);
	$logger->log("Creating pseudoalignment ...\n",0);

	require("$script_dir/../lib/pseudoaligner.pl");
	$logger->log("\tRunning pseudoaligner (see $log for details) ...\n",1);
	Pseudoaligner::run($align_input,$output_dir,$log);
	$logger->log("\t...done\n",1);

	$logger->log("\tPseudoalignment and snp report generated.\n",0);
	$logger->log("\tFiles can be found in $output_dir\n",0);
	$logger->log("...done\n",0);
}

1;
