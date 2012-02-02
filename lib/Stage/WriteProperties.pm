#!/usr/bin/perl

package Stage::WriteProperties;
use Stage;
@ISA = qw(Stage);

use strict;
use warnings;

my $properties_filename = "run.properties";

sub new
{
        my ($proto, $job_properties, $logger) = @_;
        my $class = ref($proto) || $proto;
        my $self = $class->SUPER::new($job_properties, $logger);

        bless($self,$class);

	$self->{'_stage_name'} = 'write-properties';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $output = $job_properties->get_job_dir."/$properties_filename";

	$logger->log("\nStage: $stage\n",1);
	$logger->log("Writing properties file to $output...\n",1);
	$job_properties->write_properties($output);
	$logger->log("...done\n",1);
}

1;
