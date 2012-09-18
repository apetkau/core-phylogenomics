#!/usr/bin/perl

package Pipeline;

use strict;
use warnings;

use Logger;
use JobProperties;

use File::Basename qw(basename dirname);
use File::Copy qw(copy move);
use File::Path qw(rmtree);
use Cwd qw(abs_path);

sub new
{
    my ($class,$script_dir) = @_;

    my $self = {};
    bless($self,$class);

    my $job_properties = new JobProperties($script_dir);
    my $config_file = "$script_dir/../etc/pipeline.conf";
    if (not -e $config_file)
    {
        print STDERR "Warning: no config file $config_file set, skipping ...\n";
    }
    else
    {
        $job_properties->read_config($config_file);
    }

    $self->{'verbose'} = 0;
    $self->{'keep_files'} = 1;
    $self->{'job_properties'} = $job_properties;

    return $self;
}

sub new_resubmit
{
    my ($class,$script_dir, $job_properties) = @_;

    my $self = {};
    bless($self,$class);

    $self->{'verbose'} = 0;
    $self->{'keep_files'} = 1;
    $self->{'job_properties'} = $job_properties;

    return $self;
}

sub set_input_fasta
{
    my ($self,$file) = @_;

    die "File $file does not exists" if (not -e $file);

    my $abs_input_fasta = abs_path($file);

    if (-d $abs_input_fasta)
    {
        $self->{'job_properties'}->set_abs_file('input_fasta_dir', $abs_input_fasta);
    }
    else
    {
        my $input_fasta_files = $self->{'job_properties'}->get_property('input_fasta_files');
        if (not defined $input_fasta_files)
        {
            $input_fasta_files = [];
            $self->{'job_properties'}->set_property('input_fasta_files', $input_fasta_files);
        }

        push(@$input_fasta_files, $abs_input_fasta);
    }
}

sub set_job_dir
{
    my ($self,$job_dir) = @_;

    die "Job dir $job_dir does not exist" if (not -e $job_dir);

    my $abs_job_dir = abs_path($job_dir);
    $self->{'job_properties'}->set_job_dir($abs_job_dir);
}

sub set_start_stage
{
    my ($self,$start_stage) = @_;
    my $end_stage = $self->{'end_stage'};

    die "Cannot resubmit to undefined ending stage" if (not defined $start_stage);
    die "Cannot resubmit to invalid stage $start_stage" if (not $self->is_valid_stage($start_stage));
    die "Cannot resubmit to invalid stage $end_stage" if (not $self->_validate_stages($start_stage,$end_stage));

    $self->{'start_stage'} = $start_stage;
}

sub set_end_stage
{
    my ($self,$end_stage) = @_;

    my $start_stage = $self->{'start_stage'};
    my $stage_dependencies = $self->{'stage_dependencies'};
    my @stage_list = @{$self->{'stage'}->{'all'}};

    die "Cannot resubmit to undefined ending stage" if (not defined $end_stage);
    die "Cannot resubmit to invalid stage $end_stage" if (not $self->is_valid_stage($end_stage));

    my $last_valid_stage;
    my $break = 0;
    for (my $i = 0; !$break and $i <= $#stage_list; $i++)
    {
        my $curr_stage = $stage_list[$i];
        $last_valid_stage = $curr_stage if (($stage_dependencies->{$curr_stage}));
        if ($curr_stage eq $end_stage)
        {
            $end_stage = $last_valid_stage if ($last_valid_stage ne $end_stage);
            $break = 1;
        }
    }

    die "Cannot resubmit to invalid stage $end_stage" if (not $self->_validate_stages($start_stage,$end_stage));

    $self->{'end_stage'} = $end_stage;
}

sub _validate_stages
{
    my ($self,$start_stage,$end_stage) = @_;
    my $stage_dependencies = $self->{'stage_dependencies'};

    my $is_valid = 1;

    if (not ($stage_dependencies->{$end_stage}))
    {
        $is_valid = 0;
    }
    else
    {
        my $seen_start = 0;
        my $seen_end = 0;
        foreach my $valid_stage (@{$self->{'stage'}->{'all'}})
        {
            $seen_start = 1 if ($valid_stage eq $start_stage);
            $seen_end = 1 if ($valid_stage eq $end_stage);
            $is_valid = 0 if ($seen_end and (not $seen_start));
        }
        $is_valid = 0 if (not $seen_end);
    }

    return $is_valid;
}

# Purpose: Resubmits the passed job through the pipeline going through the given stages
# Input:  $job_dir  The directory of the previously run job
# Output: Sets up the pipeline to run with the given properties
sub ResubmitFrom
{
    my ($script_dir, $job_dir) = @_;

    my $pipeline;

    die "Cannot resubmit to undefined job_dir" if (not defined $job_dir);
    die "Cannot resubmit to non-existant job_dir $job_dir" if (not -d $job_dir);

    my $job_properties = new JobProperties($script_dir);
    my $config_file = "$script_dir/../etc/pipeline.conf";
    if (not -e $config_file)
    {
        print STDERR "Warning: no config file $config_file set, skipping ...\n";
    }
    else
    {
        $job_properties->read_config($config_file);
    }

    my $properties_filename = "run.properties";
    my $abs_job_dir = abs_path($job_dir);
    my $properties_path = "$abs_job_dir/$properties_filename";
    die "Cannot resubmit $abs_job_dir, file $properties_path not found" if (not -e $properties_path);
    $job_properties->read_properties($properties_path);

    $job_properties->set_job_dir($abs_job_dir);

    my $mode = $job_properties->get_property('mode');

    die "Error: no mode found in $properties_path, cannot resubmit job" if (not defined $mode);
    if ($mode eq 'blast')
    {
        $pipeline = Pipeline::Blast->new_resubmit($script_dir, $job_properties);
    }
    elsif ($mode eq 'orthomcl')
    {
        $pipeline = Pipeline::Orthomcl->new_resubmit($script_dir, $job_properties);
    }
    else
    {
        die "Error: unknown pipeline mode '$mode' found in properties file '$properties_path'";
    }

    return $pipeline;
}

sub get_first_stage
{
    my ($self) = @_;

    return $self->{'stage'}->{'all'}->[0];
}

sub get_last_stage
{
    my ($self) = @_;

    return $self->{'stage'}->{'all'}->[-1];
}

sub set_verbose
{
    my ($self,$verbose) = @_;
    $self->{'verbose'} = (defined $verbose) ? $verbose : 0;
}

sub set_keep_files
{
    my ($self,$keep_files) = @_;
    $self->{'keep_files'} = (defined $keep_files and $keep_files);
}

sub set_strain_count
{
    my ($self,$strain_count) = @_;
    $self->{'job_properties'}->set_property('strain_count_manual', $strain_count);
}

sub _check_stages
{
    my ($self) = @_;

    my @stage_list = @{$self->{'stage'}->{'all'}};

    my $start_stage = $stage_list[0];
    my $end_stage = $stage_list[-1];

    my %stage_dependencies;
    foreach my $stage (@stage_list)
    {
        $stage_dependencies{$stage} = 1;
    }
    $self->{'stage_dependencies'} = \%stage_dependencies;
    $self->{'start_stage'} = $start_stage;
    $self->{'end_stage'} = $end_stage;
}

sub _execute_stage
{
    my ($self,$stage) = @_;

    my $stage_table = $self->{'stage_table'};
    my $stage_obj = $stage_table->{$stage};
    my $stage_dir = $self->{'job_properties'}->get_dir('stage_dir');

    if (defined $stage_obj)
    {
        $stage_obj->execute;
        system("touch \"$stage_dir/$stage.done\"");
    }
    else
    {
        die "Invalid stage $stage, could not continue";
    }
}

sub is_valid_stage
{
    my ($self,$stage) = @_;

    return ((defined $stage) and (exists $self->{'stage'}->{'all_hash'}->{$stage}));
}

sub execute
{
    my ($self) = @_;

    my $verbose = $self->{'verbose'};

    $self->_initialize;

    my @stage_list = @{$self->{'stage'}->{'all'}};

    my $logger = $self->{'logger'};

    my $job_properties = $self->{'job_properties'};
    my $log_dir = $job_properties->get_dir('log_dir');

    my $start_stage = $self->{'start_stage'};
    my $end_stage = $self->{'end_stage'};

    die "Start stage not defined" if (not defined $start_stage);
    die "End stage not defined" if (not defined $end_stage);

    my $yaml = YAML::Tiny->new;
    $yaml->[0] = {'job_dir' => $self->{'job_properties'}->get_job_dir,
		  'start_stage' => $self->{'start_stage'},
		  'end_stage' => $self->{'end_stage'}};
    my $other_string = $yaml->write_string;

    open(my $out_fh, '>-') or die "Could not open STDOUT";
    $logger->log("Running core SNP phylogenomic pipeline on ".`date`,0);
    $logger->log("\nParameters:\n",0);
    $logger->log($other_string."\n", 0);
    $logger->log($job_properties->write_properties_string."\n",0);
    $logger->log("\n",0);
    close($out_fh);

    my $seen_start = 0;
    my $seen_end = 0;

    # remove "done" files from all stages after the starting stage
    my $stage_dir = $job_properties->get_dir('stage_dir');
    foreach my $stage (@stage_list)
    {
        $seen_start = 1 if ($stage eq $start_stage);
        if ($seen_start)
        {
            unlink "$stage_dir/$stage.done" if (-e "$stage_dir/$stage.done");
        }
    }

    $seen_start = 0;
    $seen_end = 0;
    foreach my $stage (@stage_list)
    {
        $seen_start = 1 if ($stage eq $start_stage);
        if ($seen_start and not $seen_end)
        {
            $self->_execute_stage($stage);
        }
        elsif (not $seen_end and not $self->_is_stage_complete($stage))
        {
            die "Error: attempting to skip stage '$stage', but it is not complete yet ...\n";
        }
        else
        {
            $logger->log("\nSkipping stage: $stage\n",1);
        }
        $seen_end = 1 if ($stage eq $end_stage);
    }
}

sub _is_stage_complete
{
    my ($self,$stage) = @_;

    my $stages_dir = $self->{'job_properties'}->get_dir('stage_dir');

    return (-e "$stages_dir/$stage.done");
}

1;
