#!/usr/bin/perl

package Stage;

use strict;
use warnings;

sub new
{
        my ($class, $job_properties, $logger) = @_;

        my $self = {};
        bless($self,$class);

	$self->{'_logger'} = $logger;
	$self->{'_job_properties'} = $job_properties;

	$self->{'_stage_name'} = 'Invalid';

        return $self;
}

sub get_stage_name
{
	my ($self) = @_;

	return $self->{'_stage_name'};
}

sub _wait_until_completion
{
	my ($self,$job_name) = @_;
	my $logger = $self->{'_logger'};
	my $completed = 0;
	while (not $completed)
	{
		sleep 10;
		$logger->log(".",0);
		$completed = not $self->_check_job_queue_for($job_name);
	}
}

sub _check_job_queue_for
{
	my ($self,$job_name) = @_;

	my @qstata = `qstat`;
	my $qstat = join "",@qstata;

	return ($qstat =~ /$job_name/);
}

sub _print_sge_script
{
	my ($self, $processors, $script_path, $command) = @_;

	open(my $sge_fh, '>', $script_path) or die "Could not open $script_path for writing";
	print $sge_fh "#!/bin/sh\n";
	print $sge_fh "#\$ -t 1-$processors\n";
	print $sge_fh $command;
	print $sge_fh "\n";
	close($sge_fh);
}

sub _get_job_id
{
	my ($self) = @_;

	return sprintf "x%08x", time;
}

sub execute
{
        my ($self) = @_;
        die "Cannot run method Stage::execute directly";
}

1;
