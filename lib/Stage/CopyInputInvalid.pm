#!/usr/bin/env perl

package Stage::CopyInputInvalid;
use Stage;
@ISA = qw(Stage);

use File::Copy;
use File::Basename;
use Bio::SeqIO;

use strict;
use warnings;

sub new
{
        my ($proto, $job_properties, $logger) = @_;
        my $class = ref($proto) || $proto;
        my $self = $class->SUPER::new($job_properties, $logger);

        bless($self,$class);

	$self->{'_stage_name'} = 'copy-input-invalid-positions';

        return $self;
}


sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $input_file = $job_properties->get_abs_file('input_invalid');
	my $output_file_path = $job_properties->get_file_dir('invalid_pos_dir','invalid');
	
	$logger->log("\nStage: $stage\n",0);

	die "input reference file is undefined" if (not defined $input_file);
	die "input reference file does not exist" if (not -e $input_file);

	copy($input_file, $output_file_path) or die "Could not copy \"$input_file\" to \"$output_file_path\"";

	$logger->log("...done\n",0);
}

1;
