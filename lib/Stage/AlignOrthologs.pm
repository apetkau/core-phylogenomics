#!/usr/bin/perl

package Stage::AlignOrthologs;
use Stage;
@ISA = qw(Stage);

use File::Basename qw(basename dirname);
use File::Copy qw(copy move);

use strict;
use warnings;

sub new
{
        my ($proto, $file_manager, $job_properties, $logger) = @_;
        my $class = ref($proto) || $proto;
        my $self = $class->SUPER::new($file_manager, $job_properties, $logger);

        bless($self,$class);

	$self->{'_stage_name'} = 'alignment';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $core_dir = $self->{'_file_manager'}->get_dir('core_dir');
	my $input_task_base = $self->{'_file_manager'}->get_file_dir('core_dir', 'core_snp_base');
	my $output_dir = $self->{'_file_manager'}->get_dir('align_dir');
	my $log_dir = $self->{'_file_manager'}->get_dir('log_dir');
	my $script_dir = $self->{'_file_manager'}->get_script_dir;

	die "Input files ${input_task_base}x do not exist" if (not -e "${input_task_base}1");
	die "Output directory $output_dir does not exist" if (not -e $output_dir);

	my $input_dir = dirname($input_task_base);

	my $job_name = $self->_get_job_id;

	$logger->log("\nStage: $stage\n",0);
	$logger->log("Performing multiple alignment of orthologs ...\n",0);

	my $max_snp_number = $self->_largest_snp_file($core_dir, $self->{'_file_manager'}->get_file('core_snp_base'));
	die "Largest SNP number is invalid" if (not defined $max_snp_number or $max_snp_number <= 0);

	my $clustalw_sge = "$output_dir/clustalw.sge";
	$logger->log("\tWriting $clustalw_sge script ...\n",1);
	my $sge_command = "clustalw2 -infile=${input_task_base}\$SGE_TASK_ID";
	$self->_print_sge_script($max_snp_number, $clustalw_sge, $sge_command);
	$logger->log("\t...done\n",1);

	my $error = "$log_dir/clustalw.error.sge";
	my $out = "$log_dir/clustalw.out.sge";
	my $submission_command = "qsub -N $job_name -cwd -S /bin/sh -e \"$error\" -o \"$out\" \"$clustalw_sge\" 1>/dev/null";
	$logger->log("\tSubmitting $clustalw_sge for execution ...\n",1);
	$logger->log("\t\tSee ($out) and ($error) for details.\n",1);
	$logger->log("\t\t$submission_command\n",2);
	system($submission_command) == 0 or die "Error submitting $submission_command: $!\n";
	$logger->log("\t\tWaiting for completion of clustalw job array $job_name",1);
	$self->_wait_until_completion($job_name);
	$logger->log("done\n",1);

	opendir(my $align_dh, $input_dir) or die "Could not open $input_dir: $!";
	my @align_files = grep {/snps\d+\.aln/} readdir($align_dh);
	close($align_dh);
	$logger->log("\tMoving alignment files ...\n",1);
	foreach my $file_in (@align_files)
	{
		move("$input_dir/$file_in", "$output_dir/".basename($file_in)) or die "Could not move file $file_in: $!";
	}
	$logger->log("\t...done\n",1);

	my $log = "$log_dir/trim.log";
	require("$script_dir/../lib/trim.pl");
	$logger->log("\tTrimming alignments (see $log for details) ...\n",1);
	Trim::run($output_dir,$output_dir,$log);
	$logger->log("\t...done\n",1);

	$logger->log("...done\n",0);
}

sub _largest_snp_file
{
	my ($self,$core_dir, $core_snp_base) = @_;
	my $logger = $self->{'_logger'};

	$logger->log("\tGetting largest SNP file...\n",1);
	my $max = -1;
	opendir(my $dir_h,$core_dir);
	while(my $file = readdir $dir_h)
	{
		my ($curr_num) = ($file =~ /^$core_snp_base(\d+)$/);
		$max = $curr_num if (defined $curr_num and $curr_num > $max);
	}
	close ($dir_h);
	$logger->log("\t\tMax: $max\n",1);
	die "Error, no snp files" if ($max <= 0);

	$logger->log("\t...done\n",1);

	return $max;
}

1;
