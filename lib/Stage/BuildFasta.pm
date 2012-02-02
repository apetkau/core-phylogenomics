#!/usr/bin/perl

package Stage::BuildFasta;
use Stage;
@ISA = qw(Stage);

use File::Path qw(rmtree);
use File::Copy qw(copy move);
use File::Basename qw(basename);

use strict;
use warnings;

sub new
{
        my ($proto, $job_properties, $logger) = @_;
        my $class = ref($proto) || $proto;
        my $self = $class->SUPER::new($job_properties, $logger);

        bless($self,$class);

	$self->{'_stage_name'} = 'prepare-input';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $input_dir = $job_properties->get_abs_dir('input_fasta_dir');
	my $input_files = $job_properties->get_property('input_fasta_files');
	my $output_dir = $job_properties->get_dir('fasta_dir');

	my $all_input_file = $job_properties->get_file_dir('fasta_dir', 'all_input_fasta');

	die "Output directory is invalid" if (not -d $output_dir);

	$logger->log("\nStage: $stage\n",0);
	$logger->log("Preparing input files...\n",0);

	if (not defined $input_dir and (defined $input_files and (ref $input_files eq 'ARRAY')))
	{
		my $strain_count = 0;
		my $temp_input_dir =  $job_properties->get_job_dir.'/temp_input_dir';
		(rmtree($temp_input_dir) or die "Could not delete $temp_input_dir: $!") if (-e $temp_input_dir);
		mkdir($temp_input_dir) or die "Could not create $temp_input_dir: $!";
		foreach my $input_file (@$input_files)
		{
			copy($input_file,$temp_input_dir) or die "Could not copy $input_file: $!";
			$strain_count++;
		}

		$job_properties->set_property('strain_count', $strain_count);
		$input_dir = $temp_input_dir;
	}

	if (not defined $input_dir)
	{
		die "Error: could not find any valid input files\n";
	}
	else
	{
		die "Input directory is invalid" if (not -d $input_dir);
		my $sep_char = '|';

		opendir(my $input_dh, $input_dir) or die "Could not open $input_dir: $!";
		my @files = sort grep {/fasta$/i} readdir($input_dh);
		close($input_dh);

		die "No input fasta files found in $input_dir" if (scalar(@files) <= 0);

		$logger->log("\tCopying input files to $output_dir\n",1);
		foreach my $file (@files)
		{
			my $input_path = "$input_dir/$file";
			my $output_file = "$file.prepended.fasta";
			my $output_path = "$output_dir/$output_file";
			copy($input_path,$output_path) or die "Could not copy $file from $input_dir to $output_dir: $!";

			if (not defined $job_properties->get_file('split_file'))
			{
				$logger->log("\t\tSetting split file to $output_path\n",1);
				$self->_set_split_file($output_file);
			}
		}
		$logger->log("\t...done\n",1);

		$logger->log("\tChecking for unique names across all sequences in input fasta files...\n",1);
		my @files_to_append_separator;
		my %name_file_map; # used to map the name of a sequence to a file (for checking for unique separators)
		foreach my $file (@files)
		{
			my $output_path = "$output_dir/$file.prepended.fasta";

			$logger->log("\t\tFinding existing unique headers for $output_path ...\n",1);
			my $unique_command = "grep '^>' \"$output_path\" | cut -d '$sep_char' -f 1|sort -u|wc -l";
			$logger->log("\t\t\t$unique_command\n",2);
			my $unique_count = `$unique_command`;

			die "Invalid unique count" if (not defined $unique_count or $unique_count !~ /^\d+$/);
			if ($unique_count == 1)
			{
				$logger->log("\t\t\tFile $output_path contains single unique name for all sequences\n",1);

				my $find_name_command = "grep '^>' \"$output_path\" | cut -d '$sep_char' -f 1|sort -u";
				$logger->log("\t\t\t$find_name_command\n",2);
				my $unique_name = `$find_name_command`;
				chomp $unique_name;
				die "Invalid unique name" if (not defined $unique_count);

				if (exists $name_file_map{$unique_name})
				{
					$logger->log("\t\t\tName $unique_name not unique across all strains, need to generate new unique name for file $output_path\n",1);
					push(@files_to_append_separator, $file);
				}
				else
				{
					$logger->log("\t\t\tName: $unique_name\n",1);
					$name_file_map{$unique_name} = $file;
				}
			}
			else
			{
				$logger->log("\t\t\tFile $output_path has no single unique name for all sequences, need to generate new unique name\n",1);
				push(@files_to_append_separator,$file);
			}

			$logger->log("\t\t...done\n",1);
		}

		$logger->log("\t\tGenerating unique names for strains for files...\n",1) if (@files_to_append_separator > 0);
		foreach my $file (@files_to_append_separator)
		{
			my ($name) = ($file =~ /^([^\.]+)\./);

			die "Cannot take id from file name for $input_dir/$file" if (not defined $name);
			my $output_file = "$file.prepended.fasta";
			my $output_path = "$output_dir/$output_file";

			my $remove_sep_char_command = "sed -i \"s/$sep_char/_/\" \"$output_path\"";
			$logger->log("\t\t\tRemoving existing separator char\n",1);
			$logger->log("\t\t\t$remove_sep_char_command\n",1);
			system($remove_sep_char_command) == 0 or die "Error attempting to remove existing separator char: $!";

			my $uniquify_command = "sed -i \"s/>/>$name\|/\" \"$output_path\"";
			$logger->log("\t\t\tGenerating unique name for file $output_path\n",1);
			$logger->log("\t\t\t$uniquify_command\n",1);
			system($uniquify_command) == 0 or die "Error attempting to create unique gene ids: $!";
		}
		$logger->log("\t\t...done\n",1) if (@files_to_append_separator > 0);
		$logger->log("\t...done\n",1);

		my $strain_count = 0;

		my @files_to_build;
		my $file_dir;

		opendir(my $input_build_dh, $output_dir) or die "Could not open $output_dir: $!";
		$file_dir = $output_dir;
		@files_to_build = sort grep {/prepended\.fasta$/} readdir($input_build_dh);
		close($input_build_dh);

		$strain_count = scalar(@files_to_build);

		$logger->log("\tBuilding single multi-fasta file $all_input_file ...\n",1);
		open(my $out_fh, '>', "$all_input_file") or die "Could not open file $all_input_file: $!";
		foreach my $file (@files_to_build)
		{
			$logger->log("\t\treading $file_dir/$file\n",2);
			open(my $in_fh, '<', "$file_dir/$file") or die "Could not open file $file_dir/$file: $!";
			my $line;
			while ($line = <$in_fh>)
			{
				chomp $line;
				print $out_fh "$line\n";
			}

			close ($in_fh);
		}
		close ($out_fh);
		$logger->log("\t...done\n",1);

		if (not defined $job_properties->get_property('strain_count_manual'))
		{
			$job_properties->set_property('strain_count', $strain_count);
		}
		else
		{
			$job_properties->set_property('strain_count', $job_properties->get_property('strain_count_manual'));
		}
	}

	$logger->log("...done\n",0);
}

sub _set_split_file
{
	my ($self,$file) = @_;

	my $job_properties = $self->{'_job_properties'};
	$job_properties->set_file('split_file', $file);
	$job_properties->set_file('blast_base', basename($file).'.out');
}

1;
