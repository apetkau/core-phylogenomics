#!/usr/bin/perl

package Pipeline;

use strict;
use warnings;

use Logger;
use JobProperties;
use Stage;
use Stage::BuildFasta;
use Stage::WriteProperties;
use Stage::CreateDatabase;
use Stage::PerformSplit;
use Stage::PerformBlast;
use Stage::FindCore;
use Stage::AlignOrthologs;
use Stage::Pseudoalign;
use Stage::GenerateReport;
use Stage::BuildPhylogeny;
use Stage::BuildPhylogenyGraphic;

use File::Basename qw(basename dirname);
use File::Copy qw(copy move);
use File::Path qw(rmtree);
use Cwd qw(abs_path);

my @valid_job_dirs = ('job_dir','log_dir','fasta_dir','database_dir','split_dir','blast_dir','core_dir',
                  'align_dir','pseudoalign_dir','stage_dir','phylogeny_dir');
my @valid_other_files = ('input_fasta_dir','split_file','input_fasta_files');
my @valid_properties = join(@valid_job_dirs,@valid_other_files,'hsp_length','pid_cutoff');

my @stage_list = ('prepare-input',
                  'write-properties',
                  'build-database',
                  'split',
                  'blast',
                  'core',
                  'alignment',
                  'pseudoalign',
                  'report',
                  'build-phylogeny',
                  'phylogeny-graphic'
                 );


my @user_stage_list = ('prepare-input',
                       'build-database',
                       'split',
                       'blast',
                       'core',
                       'alignment',
                       'pseudoalign',
                       'build-phylogeny',
                       'phylogeny-graphic'
                      );

my @stage_descriptions = ('Prepares and checks input files.',
                          'Builds database for blasts.',
                          'Splits input file among processors.',
                          'Performs blast to find core genome.',
                          'Attempts to identify snps from core genome.',
                          'Performs multiple alignment on each ortholog.',
                          'Creates a pseudoalignment.',
                          'Builds the phylogeny based on the pseudoalignment.',
                          'Builds a graphic image of the phylogeny.'
                         );

sub new
{
    my ($class,$script_dir) = @_;

    my $self = {};
    bless($self,$class);

    my $job_properties = new JobProperties($script_dir);

    $self->{'verbose'} = 0;
    $self->{'keep_files'} = 1;
    $self->{'job_properties'} = $job_properties;
    $self->_check_stages;
    $job_properties->{'pid_cutoff'} = 99;
    $job_properties->{'hsp_length'} = 400;

    $job_properties->set_file('all_input_fasta', 'all.fasta');
    $job_properties->set_file('bioperl_index', 'all.fasta.idx');
    $job_properties->set_file('core_snp_base', 'snps');
    $job_properties->set_dir('log_dir', "log");
    $job_properties->set_dir('fasta_dir', "fasta");
    $job_properties->set_dir('database_dir', "database");
    $job_properties->set_dir('split_dir', "split");
    $job_properties->set_dir('blast_dir', "blast");
    $job_properties->set_dir('core_dir', "core");
    $job_properties->set_dir('align_dir', "align");
    $job_properties->set_dir('pseudoalign_dir', "pseudoalign");
    $job_properties->set_dir('stage_dir', "stages");
    $job_properties->set_dir('phylogeny_dir', 'phylogeny');

    return $self;
}

sub set_job_dir
{
    my ($self,$job_dir) = @_;

    die "Job dir $job_dir does not exist" if (not -e $job_dir);

    my $abs_job_dir = abs_path($job_dir);
    $self->{'job_properties'}->set_job_dir($abs_job_dir);
}

sub _get_strain_ids
{
	my ($self,$fasta_input) = @_;

	opendir(my $dh, $fasta_input) or die "Could not open directory $fasta_input: $!";
	my @strain_ids = map {/(.*).fasta$/; $1;} grep {/\.fasta$/} readdir($dh);
	closedir($dh);

	return \@strain_ids;
}

sub prepare_orthomcl
{
#	my ($self, $orthologs_group) = @_;
#
#	my $logger = $self->{'logger'};
#	my $script_dir = $self->{'script_dir'};
#	my $core_dir = $self->_get_file('core_dir');
#	my $fasta_input = $self->_get_file('input_fasta_dir');
#	my $stage_dir = $self->_get_file('stage_dir');
#
#	die "Core dir undefined" if (not defined $core_dir or $core_dir eq '');
#	die "Core dir $core_dir does not exist" if (not -e $core_dir);
#
#	die "Fasta input undefined" if (not defined $fasta_input or $fasta_input eq '');
#	die "Fasta input $fasta_input does not exist" if (not -e $fasta_input);
#
#	# Create files to indicate previous stages have been done
#        system("touch \"$stage_dir/prepare-input.done\"");
#        system("touch \"$stage_dir/write-properties.done\"");
#        system("touch \"$stage_dir/build-database.done\"");
#        system("touch \"$stage_dir/split.done\"");
#        system("touch \"$stage_dir/blast.done\"");
#        system("touch \"$stage_dir/core.done\"");
#
#	$logger->log("Stage: Prepare Orthomcl\n", 0);
#
#	my $strain_ids = $self->_get_strain_ids($fasta_input);
#
#	require("$script_dir/../lib/alignments_orthomcl.pl");
#	AlignmentsOrthomcl::run($orthologs_group, $fasta_input, $core_dir, $strain_ids);
#
#	$logger->log("done\n",0);
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
        foreach my $valid_stage (@stage_list)
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
sub resubmit
{
    my ($self,$job_dir) = @_;

    die "Cannot resubmit to undefined job_dir" if (not defined $job_dir);
    die "Cannot resubmit to non-existant job_dir $job_dir" if (not -d $job_dir);

    my $job_properties = $self->{'job_properties'};
    my $properties_filename = "run.properties";

    my $abs_job_dir = abs_path($job_dir);
    my $properties_path = "$abs_job_dir/$properties_filename";
    die "Cannot resubmit $abs_job_dir, file $properties_path not found" if (not -e $properties_path);

    $job_properties->set_job_dir($abs_job_dir);

    $job_properties->read_properties($properties_path);
}

sub static_get_stage_descriptions
{
    my ($indent) = @_;

    my $description = "";

    for (my $i = 0; $i <= $#user_stage_list; $i++)
    {
        $description .= "$indent".$user_stage_list[$i]." :  ".$stage_descriptions[$i]."\n";
    }

    return $description;
}

sub get_first_stage
{
    my ($self) = @_;

    return $stage_list[0];
}

sub get_last_stage
{
    my ($self) = @_;

    return $stage_list[-1];
}

sub set_hsp_length
{
    my ($self,$length) = @_;
    $self->{'job_properties'}->set_property('hsp_length', $length);
}

sub set_pid_cutoff
{
    my ($self,$pid_cutoff) = @_;

    $self->{'job_properties'}->set_property('pid_cutoff', $pid_cutoff);
}

sub set_verbose
{
    my ($self,$verbose) = @_;
    $self->{'verbose'} = (defined $verbose) ? $verbose : 0;
}

sub set_processors
{
    my ($self,$processors) = @_;
    $self->{'job_properties'}->set_property('processors', $processors);
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

sub set_input_fasta
{
    my ($self,$file) = @_;

    die "File $file does not exists" if (not -e $file);

    my $abs_input_fasta = abs_path($file);

    if (-d $abs_input_fasta)
    {
        $self->{'job_properties'}->set_abs_dir('input_fasta_dir', $abs_input_fasta);
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

sub _check_stages
{
    my ($self) = @_;

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

    my $check_stage;

    if (system('which figtree 1>/dev/null 2>&1') != 0)
    {
        $check_stage = 'phylogeny-graphic';
        print STDERR "Warning: Could not find figtree, cannot run stage $check_stage\n";
        $stage_dependencies{$check_stage} = 0; 
        $self->set_end_stage('build-phylogeny');
    }

    if (system('which phyml 1>/dev/null 2>&1') != 0)
    {
        $check_stage = 'build-phylogeny';
        print STDERR "Warning: Could not find phyml, cannot run stage $check_stage\n";
        $stage_dependencies{$check_stage} = 0; 
        $self->set_end_stage('pseudoalign');
    }
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

    return ((defined $stage) and ($self->_exists_in_array($stage,\@stage_list)));
}

sub execute
{
    my ($self) = @_;

    my $verbose = $self->{'verbose'};

    $self->_initialize;

    my $logger = $self->{'logger'};

    my $job_properties = $self->{'job_properties'};
    my $log_dir = $job_properties->get_dir('log_dir');

    my $start_stage = $self->{'start_stage'};
    my $end_stage = $self->{'end_stage'};

    my $yaml_string = $job_properties->write_properties_string;

    die "Start stage not defined" if (not defined $start_stage);
    die "End stage not defined" if (not defined $end_stage);

    open(my $out_fh, '>-') or die "Could not open STDOUT";
    $logger->log("Running core SNP phylogenomic pipeline on ".`date`,0);
    $logger->log("\nParameters:\n",0);
    $logger->log("\tjob_dir = ".$self->{'job_properties'}->get_job_dir."\n",0);
    $logger->log("\tstart_stage = ".$self->{'start_stage'}."\n",0);
    $logger->log("\tend_stage = ".$self->{'end_stage'}."\n",0);
    $logger->log("\tinput_fasta_dir = ".($job_properties->get_abs_dir('input_fasta_dir'))."\n",0);
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

sub _initialize
{
    my ($self) = @_;

    my $job_properties = $self->{'job_properties'};
    $job_properties->build_job_dirs;

    my $log_dir = $job_properties->get_dir('log_dir');
    my $verbose = $self->{'verbose'};

    my $logger = new Logger($log_dir, $verbose);
    $self->{'logger'} = $logger;

    my $stage_table = { 'prepare-input' => new Stage::BuildFasta($job_properties, $logger),
                        'write-properties' => new Stage::WriteProperties($job_properties, $logger),
                        'build-database' => new Stage::CreateDatabase($job_properties, $logger),
                        'split' => new Stage::PerformSplit($job_properties, $logger),
                        'blast' => new Stage::PerformBlast($job_properties, $logger),
                        'core' => new Stage::FindCore($job_properties, $logger),
                        'alignment' => new Stage::AlignOrthologs($job_properties, $logger),
                        'pseudoalign' => new Stage::Pseudoalign($job_properties, $logger),
                        'report' => new Stage::GenerateReport($job_properties, $logger),
                        'build-phylogeny' => new Stage::BuildPhylogeny($job_properties, $logger),
                        'phylogeny-graphic' => new Stage::BuildPhylogenyGraphic($job_properties, $logger)
        };

    $self->{'stage_table'} = $stage_table;
}

sub _exists_in_array
{
    my ($self,$element,$array) = @_;

    for my $curr (@$array)
    {
        return 1 if ($curr eq $element);
    }

    return 0;
}

1;
