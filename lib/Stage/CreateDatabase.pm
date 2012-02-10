#!/usr/bin/perl

package Stage::CreateDatabase;
use Stage;
@ISA = qw(Stage);

use File::Copy qw(copy move);

use strict;
use warnings;

sub new
{
        my ($proto, $job_properties, $logger) = @_;
        my $class = ref($proto) || $proto;
        my $self = $class->SUPER::new($job_properties, $logger);

        bless($self,$class);

	$self->{'_stage_name'} = 'build-database';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $stage = $self->get_stage_name;
	my $logger = $self->{'_logger'};

	my $job_properties = $self->{'_job_properties'};
	my $input_file = $job_properties->get_file_dir('fasta_dir', 'all_input_fasta');
	my $database_output = $job_properties->get_dir('database_dir');
	my $log_dir = $job_properties->get_dir('log_dir');
	my $script_dir = $job_properties->get_script_dir;

	my $input_fasta_path = $job_properties->get_file_dir('database_dir', 'all_input_fasta');

	my $formatdb_log = "$log_dir/formatdb.log";

	die "Input file $input_file does not exist" if (not -e $input_file);
	die "Output directory: $database_output does not exist" if (not -e $database_output);

	$logger->log("\nStage: $stage\n",0);
	$logger->log("Creating initial databases ...\n",1);
	$logger->log("\tChecking for features in $input_file with duplicate ids...\n",1);
	my $duplicate_count = $self->_duplicate_count($input_file);
	$logger->log("\t\tDuplicate ids: $duplicate_count\n",1);
	$logger->log("\t...done\n",1);

	die "Error: $duplicate_count duplicate ids found in input fasta $input_file\n" if ($duplicate_count > 0);

	copy($input_file, $input_fasta_path) or die "Could not copy $input_file to $input_fasta_path: $!";

	my $formatdb_command = $job_properties->get_file('formatdb');
	$formatdb_command = 'formatdb' if ((not defined $formatdb_command) or (not -e $formatdb_command));
	my $formatdb_params = [['-i', $input_fasta_path, '-p', 'F', '-l', $formatdb_log]];

	my $index_command = "perl";
	my $index_params = [["$script_dir/../lib/index.pl", $input_fasta_path]];

	$logger->log("\tCreating BLAST formatted database ...",1);
	$self->_submit_jobs($formatdb_command, 'formatdb', $formatdb_params);
	$logger->log("...done\n",1);

	$logger->log("\tCreating bioperl index ...",1);
	$self->_submit_jobs($index_command, 'index', $index_params);
	$logger->log("...done\n",1);

	$logger->log("...done\n",0);
}

# Counts duplicate ids for genes in fasta formatted files
# Input:  $input_file  If file is regular file, counts only in file.
#          if file is directory, counts all files in directory
sub _duplicate_count
{
	my ($self,$input_file) = @_;

	my $logger = $self->{'_logger'};

	die "Invalid input dir" if (not -e $input_file);

	my $is_dir = (-d $input_file);

	my $duplicate_text_command;

	if ($is_dir)
	{
		$duplicate_text_command = "grep --only-match --no-filename '^>\\S*' \"$input_file\"/* | sort | uniq --count | grep --invert-match '^[ ^I]*1[ ^I]>'";
	}
	else
	{
		$duplicate_text_command = "grep --only-match --no-filename '^>\\S*' \"$input_file\" | sort | uniq --count | grep --invert-match '^[ ^I]*1[ ^I]>'";
	}

	my $duplicate_count_command = $duplicate_text_command." | wc -l";

	$logger->log("$duplicate_count_command\n",2);

	my $duplicate_count = `$duplicate_count_command`;
	chomp $duplicate_count;

	die "Error in duplicate id command, output \"$duplicate_count\" not a number" if ($duplicate_count !~ /^\d+$/);

	# added to show which ids are duplicated, inefficient (re-runs)
	if ($duplicate_count > 0)
	{
		$logger->log("\t\tDuplicates ...\n",1);
		$logger->log("\t\tCount ID\n",1);
		my $duplicate_text_out = `$duplicate_text_command`;
		if (defined $duplicate_text_out)
		{
			$logger->log($duplicate_text_out,1);
		}
		else
		{
			$logger->log("none",1);
		}
		$logger->log("\t\t...done\n",1);
	}

	return $duplicate_count;
}

1;
