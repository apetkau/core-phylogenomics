#!/usr/bin/perl

package Stage::PrepareOrthomcl;
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

	$self->{'_stage_name'} = 'prepare-orthomcl';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $fasta_dir = $job_properties->get_dir('fasta_dir');
	my $orthologs_group = $job_properties->get_file('orthologs_group');
	my $core_dir = $job_properties->get_dir('core_dir');
	my $script_dir = $job_properties->get_script_dir;
	my $log_dir = $job_properties->get_dir('log_dir');
	my $strain_ids = $self->_get_strain_ids($fasta_dir);
	
	my $parse_log = "$log_dir/parse-orthomcl.log";

	my ($groups_kept, $groups_filtered);

	$logger->log("\nStage: $stage\n",0);
	$logger->log("Parsing orthomcl ...\n", 0);
	require("$script_dir/../lib/alignments_orthomcl.pl");
	($groups_kept, $groups_filtered) = AlignmentsOrthomcl::run($orthologs_group, $fasta_dir, $core_dir, $strain_ids, $parse_log);

	$logger->log("\tKept $groups_kept/".($groups_kept+$groups_filtered)." groups\n");

	$job_properties->set_property('groups_kept', $groups_kept);
	$job_properties->set_property('groups_filtered', $groups_filtered);
	$logger->log("...done\n",0);
}

sub _get_strain_ids
{
        my ($self,$fasta_input) = @_;
    
        opendir(my $dh, $fasta_input) or die "Could not open directory $fasta_input: $!";
        my @strain_ids = map {/(.*).fasta$/; $1;} grep {/\.fasta$/} readdir($dh);
        closedir($dh);

        return \@strain_ids;
}

1;
