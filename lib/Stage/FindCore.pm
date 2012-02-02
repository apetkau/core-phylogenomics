#!/usr/bin/perl

package Stage::FindCore;
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

	$self->{'_stage_name'} = 'core';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $snps_output = $self->{'_file_manager'}->get_dir('core_dir');
	my $bioperl_index = $self->{'_file_manager'}->get_file_dir('database_dir', 'bioperl_index');
	my $processors = $job_properties->{'processors'};
	my $strain_count = $job_properties->{'strain_count'};
	my $pid_cutoff = $job_properties->{'pid_cutoff'};
	my $hsp_length = $job_properties->{'hsp_length'};
	my $log_dir = $self->{'_file_manager'}->get_dir('log_dir');
	my $core_snp_base = $self->{'_file_manager'}->get_file('core_snp_base');
	my $script_dir = $self->{'_file_manager'}->get_script_dir;

	my $blast_dir = $self->{'_file_manager'}->get_dir('blast_dir');
	my $blast_input_base = $self->{'_file_manager'}->get_file_dir('blast_dir', 'blast_base');

	die "Input files $blast_input_base.x do not exist" if (not -e "$blast_input_base.1");
	die "Output directory $snps_output does not exist" if (not -e $snps_output);
	die "Bioperl index $bioperl_index does not exist" if (not -e $bioperl_index);
	die "Strain count is invalid" if (not defined ($strain_count) or $strain_count <= 0);
	die "Pid cutoff is invalid" if (not defined ($pid_cutoff) or $pid_cutoff <= 0 or $pid_cutoff > 100);
	die "HSP length is invalid" if (not defined ($hsp_length) or $hsp_length <= 0);

	my $core_snp_base_path = "$snps_output/$core_snp_base";

	$logger->log("\nStage: $stage\n",0);
	$logger->log("Performing core genome SNP identification ...\n",0);
	my $core_sge = "$snps_output/core.sge";
	$logger->log("\tWriting $core_sge script ...\n",1);
	my $sge_command = "$script_dir/../lib/coresnp2.pl -b \"$blast_input_base.\$SGE_TASK_ID\" -i \"$bioperl_index\" -c $strain_count -p $pid_cutoff -l $hsp_length -o \"$snps_output\"\n";
	$self->_print_sge_script($processors, $core_sge, $sge_command);
	$logger->log("\t...done\n",1);

	my $job_name = $self->_get_job_id;

	my $error = "$log_dir/core.error.sge";
	my $out = "$log_dir/core.out.sge";
	my $submission_command = "qsub -N $job_name -cwd -S /bin/sh -e \"$error\" -o \"$out\" \"$core_sge\" 1>/dev/null";
	$logger->log("\tSubmitting $core_sge for execution ...\n",1);
	$logger->log("\t\tSee ($out) and ($error) for details.\n",1);
	$logger->log("\t\t$submission_command\n",2);
	system($submission_command) == 0 or die "Error submitting $submission_command: $!\n";
	$logger->log("\t\tWaiting for completion of core sge job array $job_name",1);
	$self->_wait_until_completion($job_name);
	$logger->log("done\n",1);

	require("$script_dir/../lib/rename.pl");
	$logger->log("\tRenaming SNP output files...\n",1);
	Rename::run($snps_output,$snps_output);
	$logger->log("\t...done\n",1);

	$logger->log("...done\n",0);
}

1;
