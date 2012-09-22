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

	# get perl environment variable to pass to jobs run on cluster nodes
	my $perl_libs = $ENV{'PERL5LIB'};
	$self->{'_perl_libs'} = $perl_libs if (defined $perl_libs);

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

	my $perl_libs = $self->{'_perl_libs'};

	my $number_tasks = scalar(@$job_params);
	my %job_ids;

	$| = 1;
	$self->start_scheduler();

	my ($drmerr, $jt, $drmdiag, $jobid, $drmps,$job_id_out,$stat,$rusage);

	for (my $task = 0; $task < $number_tasks; $task++)
	{
		my $params = $job_params->[$task];
		my $job_string = "\"$bin ".join(' ', @$params)."\"";
		my $job_out = "$log_path.out";
		my $job_err = "$log_path.err";
		$logger->log("Submit $job_string\n", 1);
		
                ($drmerr,$jt,$drmdiag) = drmaa_allocate_job_template();
                die drmaa_strerror($drmerr)."\n".$drmdiag if $drmerr;

		if (defined $perl_libs)
		{
                	($drmerr,$drmdiag) = drmaa_set_vector_attribute($jt,$DRMAA_V_ENV,["PERL5LIB=$perl_libs"]);
			die drmaa_strerror($drmerr)."\n".$drmdiag if $drmerr;
		}

                ($drmerr,$drmdiag) = drmaa_set_attribute($jt,$DRMAA_REMOTE_COMMAND,$bin); #sets the command for the job to be run
                die drmaa_strerror($drmerr)."\n".$drmdiag if $drmerr;

                ($drmerr,$drmdiag) = drmaa_set_attribute($jt,$DRMAA_OUTPUT_PATH,":$job_out"); #sets the output directory for stdout
                die drmaa_strerror($drmerr)."\n".$drmdiag if $drmerr;

                ($drmerr,$drmdiag) = drmaa_set_attribute($jt,$DRMAA_ERROR_PATH,":$job_err"); #sets the output directory for stdout
                die drmaa_strerror($drmerr)."\n".$drmdiag if $drmerr;

                ($drmerr,$drmdiag) = drmaa_set_vector_attribute($jt,$DRMAA_V_ARGV,$params); #sets the list of arguments to be applied to this job
                die drmaa_strerror($drmerr)."\n".$drmdiag if $drmerr;

                ($drmerr,$jobid,$drmdiag) = drmaa_run_job($jt); #submits the job to whatever scheduler you're using
                die drmaa_strerror($drmerr)."\n".$drmdiag if $drmerr;

                ($drmerr,$drmdiag) = drmaa_delete_job_template($jt); #clears up the template for this job
                die drmaa_strerror($drmerr)."\n".$drmdiag if $drmerr;

		$job_ids{$jobid} = {'command' => $job_string, 'out' => $job_out, 'err' => $job_err};
	}

	# wait for jobs
	print "\njobs for ".$self->get_stage_name." ".scalar(keys %job_ids).".";
	$logger->log("\tjob ids for submitted jobs = ".join(',',keys %job_ids)."\n",1);
        do
        {
                ($drmerr, $job_id_out, $stat, $rusage, $drmdiag) = drmaa_wait($DRMAA_JOB_IDS_SESSION_ANY, 10);

		if ($drmerr != $DRMAA_ERRNO_EXIT_TIMEOUT)
		{
			my ($err,$exit_status,$exited,$diag);
			($err,$exited,$diag) = drmaa_wifexited($stat);
			if ($exited)
			{
				($err,$exit_status,$diag) = drmaa_wexitstatus($stat);
			
				if ($exit_status != 0)
				{
					$self->kill_all_jobs(\%job_ids);
					my $message = "error: job with id $job_id_out described by \n".
							"\tcommand: ".$job_ids{$job_id_out}->{'command'}."\n".
							"\t\tout: ".$job_ids{$job_id_out}->{'out'}."\n".
							"\t\terr: ".$job_ids{$job_id_out}->{'err'}."\n".
							" died with exit code $exit_status";
					$logger->log($message,1);
					die "$message";
				}
				delete $job_ids{$job_id_out};
			}
			else
			{
				$self->kill_all_jobs(\%job_ids);
				my $message = "error: job with id $job_id_out described by \n".
							"\tcommand: ".$job_ids{$job_id_out}->{'command'}."\n".
							"\t\tout: ".$job_ids{$job_id_out}->{'out'}."\n".
							"\t\terr: ".$job_ids{$job_id_out}->{'err'}."\n".
							" died with exit code $exit_status";
				die "$message";
			}
			print ".".scalar(keys %job_ids).".";
		}
		else
		{
                	print ".";
		}
        } while (scalar(keys %job_ids) > 0);

	$|=0;

	$self->stop_scheduler();
}

sub kill_all_jobs
{
	my ($self,$jobs) = @_;

	my ($error,$diag);

	for my $id (keys %$jobs)
	{
		($error,$diag) = drmaa_control($id,$DRMAA_CONTROL_TERMINATE);
	}
}

sub execute
{
        my ($self) = @_;
        die "Cannot run method Stage::execute directly";
}

1;
