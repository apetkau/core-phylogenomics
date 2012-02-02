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

	my $job_name = $self->_get_job_id;

	my $blast_sge = "$output_dir/blast.sge";
	$logger->log("\tWriting $blast_sge script ...\n",1);
	my $sge_command = "blastall -p blastn -i \"$input_task_base.\$SGE_TASK_ID\" -F F -o \"$blast_base_path.\$SGE_TASK_ID\" -d \"$database\"\n";
	$self->_print_sge_script($processors, $blast_sge, $sge_command);
	$logger->log("\t...done\n",1);

	my $error = "$log_dir/blast.error.sge";
	my $out = "$log_dir/blast.out.sge";
	my $submission_command = "qsub -N $job_name -cwd -S /bin/sh -e \"$error\" -o \"$out\" \"$blast_sge\" 1>/dev/null";
	$logger->log("\tSubmitting $blast_sge for execution ...\n",1);
	$logger->log("\t\tSee ($out) and ($error) for details.\n",1);
	$logger->log("\t\t$submission_command\n",2);
	system($submission_command) == 0 or die "Error submitting $submission_command: $!\n";
	$logger->log("\t\tWaiting for completion of blast job array $job_name",1);
	$self->_wait_until_completion($job_name);
	$logger->log("done\n",1);
	$logger->log("...done\n",0);
}

1;
