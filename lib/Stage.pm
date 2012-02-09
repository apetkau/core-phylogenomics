#!/usr/bin/perl

package Stage;

use Schedule::DRMAAc qw( :all );
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

sub start_scheduler
{
        my ($self, $drmerr, $drmdiag) = drmaa_init(undef);
        die drmaa_strerror($drmerr),"\n",$drmdiag if ($drmerr);
}

sub stop_scheduler
{
        my ($self, $drmerr,$drmdiag) = drmaa_exit();
        die drmaa_strerror($drmerr)."\n".$drmdiag if $drmerr;
}

# Submits the given jobs with the given parameters and waits until completion.
# Input:  $bin  The executable to run.
#	  $name  The name to be used for the log files
#	  $job_params  A list of parameters to pass to $bin which change for each job.  Store as
#			    a reference to an array containing arrays of parameters for each job.
# Output: None
sub _submit_jobs
{
	my ($self, $bin, $name, $job_params) = @_;

	die "Error: bin undefined" if (not defined $bin);
	die "Error: name undefined" if (not defined $name);
	die "Error: job_params not defined" if (not defined $job_params);

#	die "Error: bin=$bin does not exist" if (not -e $bin);
	die "Error: job_params not an array of parameters" if (not (ref $job_params eq 'ARRAY'));

	my $job_properties = $self->{'_job_properties'};
	my $logger = $self->{'_logger'};
	my $log_dir = $job_properties->get_dir('log_dir');
	my $log_path = "$log_dir/$name";

	my $number_tasks = scalar(@$job_params);
	my @job_ids;

	$| = 1;
	$self->start_scheduler();

	my ($drmerr, $jt, $drmdiag, $jobid, $drmps);

	for (my $task = 0; $task < $number_tasks; $task++)
	{
		my $params = $job_params->[$task];
		$logger->log("Submit \"$bin ".join(' ', @$params)."\"\n", 1);
		
                ($drmerr,$jt,$drmdiag) = drmaa_allocate_job_template();
                die drmaa_strerror($drmerr)."\n".$drmdiag if $drmerr;

                ($drmerr,$drmdiag) = drmaa_set_attribute($jt,$DRMAA_REMOTE_COMMAND,$bin); #sets the command for the job to be run
                die drmaa_strerror($drmerr)."\n".$drmdiag if $drmerr;

                ($drmerr,$drmdiag) = drmaa_set_attribute($jt,$DRMAA_OUTPUT_PATH,":$log_path.out"); #sets the output directory for stdout
                die drmaa_strerror($drmerr)."\n".$drmdiag if $drmerr;

                ($drmerr,$drmdiag) = drmaa_set_attribute($jt,$DRMAA_ERROR_PATH,":$log_path.err"); #sets the output directory for stdout
                die drmaa_strerror($drmerr)."\n".$drmdiag if $drmerr;

                ($drmerr,$drmdiag) = drmaa_set_vector_attribute($jt,$DRMAA_V_ARGV,$params); #sets the list of arguments to be applied to this job
                die drmaa_strerror($drmerr)."\n".$drmdiag if $drmerr;

                ($drmerr,$jobid,$drmdiag) = drmaa_run_job($jt); #submits the job to whatever scheduler you're using
                die drmaa_strerror($drmerr)."\n".$drmdiag if $drmerr;

                ($drmerr,$drmdiag) = drmaa_delete_job_template($jt); #clears up the template for this job
                die drmaa_strerror($drmerr)."\n".$drmdiag if $drmerr;

                push(@job_ids,$jobid);
	}

	# wait for jobs
        do
        {
                ($drmerr, $drmdiag) = drmaa_synchronize(\@job_ids, 10, 0);

                die drmaa_strerror( $drmerr ) . "\n" . $drmdiag
                                if $drmerr and $drmerr != $DRMAA_ERRNO_EXIT_TIMEOUT;

                print ".";
        } while ($drmerr == $DRMAA_ERRNO_EXIT_TIMEOUT);

	$|=0;

	$self->stop_scheduler();
}

sub execute
{
        my ($self) = @_;
        die "Cannot run method Stage::execute directly";
}

1;
