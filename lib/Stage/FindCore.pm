#!/usr/bin/env perl

package Stage::FindCore;
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

	$self->{'_stage_name'} = 'core';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $snps_output = $job_properties->get_dir('core_dir');
	my $bioperl_index = $job_properties->get_file_dir('database_dir', 'bioperl_index');
	my $processors = $job_properties->get_property('processors');
	if (not defined $processors)
	{
		warn "Warning: processors not defined, defaulting to 1 ...\n";
		$processors = 1;
	}
	my $strain_count = $job_properties->get_property('strain_count');
	my $pid_cutoff = $job_properties->get_property('pid_cutoff');
	my $hsp_length = $job_properties->get_property('hsp_length');
	my $log_dir = $job_properties->get_dir('log_dir');
	my $core_snp_base = $job_properties->get_file('core_snp_base');
	my $script_dir = $job_properties->get_script_dir;

	my $blast_dir = $job_properties->get_dir('blast_dir');
	my $blast_input_base = $job_properties->get_file_dir('blast_dir', 'blast_base');

	die "Input files $blast_input_base.x do not exist" if (not -e "$blast_input_base.1");
	die "Output directory $snps_output does not exist" if (not -e $snps_output);
	die "Bioperl index $bioperl_index does not exist" if (not -e $bioperl_index);
	die "Strain count is invalid" if (not defined ($strain_count) or $strain_count <= 0);
	die "Pid cutoff is invalid" if (not defined ($pid_cutoff) or $pid_cutoff <= 0 or $pid_cutoff > 100);
	die "HSP length is invalid" if (not defined ($hsp_length) or $hsp_length <= 0);

	my $core_snp_base_path = "$snps_output/$core_snp_base";

	$logger->log("\nStage: $stage\n",0);
	$logger->log("Performing core genome SNP identification ...\n",0);
	my $cores_command = 'perl';
	my $cores_params = [];
	for (my $i = 1; $i <= $processors; $i++)
	{
		push(@$cores_params, ["$script_dir/../lib/coresnp2.pl", '-b', "$blast_input_base.$i", '-i', "$bioperl_index", '-c', $strain_count, '-p', $pid_cutoff, '-l', $hsp_length, '-o', $snps_output]);
	}
	$logger->log("\t...done\n",1);

	$logger->log("\tSubmitting coresnp2.pl for execution ...\n",1);
	$self->_submit_jobs($cores_command, 'cores', $cores_params);
	$logger->log("done\n",1);

	require("$script_dir/../lib/rename.pl");
	$logger->log("\tRenaming SNP output files...\n",1);
	Rename::run($snps_output,$snps_output);
	$logger->log("\t...done\n",1);

	$logger->log("...done\n",0);
}

1;
