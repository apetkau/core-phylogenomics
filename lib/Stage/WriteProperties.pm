#!/usr/bin/perl

package Stage::WriteProperties;
use Stage;
@ISA = qw(Stage);

use strict;
use warnings;

my $properties_filename = "run.properties";

sub new
{
        my ($proto, $file_manager, $job_properties, $logger) = @_;
        my $class = ref($proto) || $proto;
        my $self = $class->SUPER::new($file_manager, $job_properties, $logger);

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
	my $output = $self->{'_file_manager'}->get_job_dir."/$properties_filename";

	$logger->log("\nStage: $stage\n",1);
	$logger->log("Writing properties file to $output...\n",1);
	open(my $out_fh, '>', $output) or die "Could not write to $output: $!";
	print $out_fh "#Properties for snp-phylogenomics job\n";
	print $out_fh "#Auto-generated on ".`date`."\n";
	$self->_perform_write_properties($out_fh,$job_properties);
	close($out_fh);
	$logger->log("...done\n",1);
}

sub _perform_write_properties
{
	my ($self, $out_fh, $job_properties, $prefix) = @_;
	my $real_prefix = defined $prefix ? $prefix : '';
	foreach my $key (keys %$job_properties)
	{
		my $value = $job_properties->{$key};
		if ((ref $value) eq 'ARRAY')
		{
			print $out_fh "$real_prefix$key=".join(', ',@$value),"\n";
		}
		else
		{
				print $out_fh "$real_prefix$key=".$job_properties->{$key}."\n";
		}
	}
}

1;
