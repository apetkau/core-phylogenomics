#!/usr/bin/env perl

package Stage::PerformSplit;
use Stage;
@ISA = qw(Stage);

use strict;
use warnings;

sub new
{
        my ($proto, $job_properties, $logger) = @_;
        my $class = ref($proto) || $proto;
        my $self = $class->SUPER::new($job_properties, $logger);

        bless($self,$class);

	$self->{'_stage_name'} = 'split';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $input_file = $job_properties->get_file_dir('fasta_dir', 'split_file');
	my $script_dir = $job_properties->get_script_dir;
	my $log_dir = $job_properties->get_dir('log_dir');
	my $output_dir = $job_properties->get_dir('split_dir');
	my $split_number = $job_properties->get_property('processors');
	if (not defined $split_number)
	{
		warn "Warning: processors not defined, defaulting to 1 ...\n";
		$split_number = 1;
	}

	my $split_log = "$log_dir/split.log";

	require("$script_dir/../lib/split.pl");

	die "input file: $input_file does not exist" if (not -e $input_file);
	die "output directory: $output_dir does not exist" if (not -e $output_dir);

	$logger->log("\nStage: $stage\n",0);
	$logger->log("Performing split ...\n",0);
	$logger->log("\tSplitting $input_file into $split_number pieces ...\n",1);
	$logger->log("\t\tSee $split_log for more information.\n",1);
	Split::run($input_file,$split_number,$output_dir,$split_log);
	$logger->log("...done\n",0);
}

1;
