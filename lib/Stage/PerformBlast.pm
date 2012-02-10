#!/usr/bin/perl

package Stage::PerformBlast;
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

	$self->{'_stage_name'} = 'blast';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $input_task_base = $job_properties->get_file_dir('split_dir', 'split_file');
	my $output_dir = $job_properties->get_dir('blast_dir');
	my $processors = $job_properties->get_property('processors');
	my $database = $job_properties->get_file_dir('database_dir', 'all_input_fasta');
	my $log_dir = $job_properties->get_dir('log_dir');
	my $blast_task_base = $job_properties->get_file('blast_base');

	die "Input files $input_task_base.x do not exist" if (not -e "$input_task_base.1");
	die "Output directory $output_dir does not exist" if (not -e $output_dir);
	die "Database $database does not exist" if (not -e $database);

	$logger->log("\nStage: $stage\n",0);
	$logger->log("Performing blast ...\n",0);
	mkdir "$output_dir" if (not -e $output_dir);
	my $blast_base_path = "$output_dir/$blast_task_base";

	my @blast_params;
	my $max_blast = $processors;
	my $blast_command = $job_properties->get_file('blastall');
	$blast_command = "blastall" if ((not defined $blast_command) or (not -e $blast_command));
	for (my $i = 1; $i <= $max_blast; $i++)
	{
		push(@blast_params, ['-p', 'blastn', '-i', "$input_task_base.$i", '-F', 'F', '-o', "$blast_base_path.$i", '-d', "$database"]);
	}

	$logger->log("\tSubmitting blast jobs for execution ...",1);
	$self->_submit_jobs($blast_command, 'blast', \@blast_params);
	$logger->log("done\n",1);
	$logger->log("...done\n",0);
}

1;
