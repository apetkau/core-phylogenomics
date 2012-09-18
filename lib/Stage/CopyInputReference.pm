#!/usr/bin/perl

package Stage::CopyInputReference;
use Stage;
@ISA = qw(Stage);

use File::Copy;
use File::Basename;

use strict;
use warnings;

sub new
{
        my ($proto, $job_properties, $logger) = @_;
        my $class = ref($proto) || $proto;
        my $self = $class->SUPER::new($job_properties, $logger);

        bless($self,$class);

	$self->{'_stage_name'} = 'copy-input-reference';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $input_file = $job_properties->get_file('input_reference');
	my $output_dir = $job_properties->get_dir('reference_dir');
	
	$logger->log("\nStage: $stage\n",0);

	die "input reference file is undefined" if (not defined $input_file);
	die "input reference file does not exist" if (not -e $input_file);

	my $new_reference_file_name = basename($input_file);
	my $new_reference_file_path = "$output_dir/$new_reference_file_name";
	$job_properties->set_file('reference',$new_reference_file_name);

	copy($input_file, $new_reference_file_path) or die "Could not copy \"$input_file\" to \"$new_reference_file_path\"";

	$logger->log("...done\n",0);
}

1;
