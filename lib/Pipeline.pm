#!/usr/bin/perl

package Pipeline;

use strict;
use warnings;

use File::Basename qw(basename dirname);
use File::Copy qw(copy move);
use File::Path qw(rmtree);
use Cwd qw(abs_path);

my $properties_filename = 'run.properties';
my @valid_job_dirs = ('job_dir','log_dir','fasta_dir','database_dir','split_dir','blast_dir','core_dir',
                  'align_dir','pseudoalign_dir','stage_dir','phylogeny_dir');
my @valid_other_files = ('input_fasta_dir','split_file','input_fasta_file');
my @valid_properties = join(@valid_job_dirs,@valid_other_files,'hsp_length','pid_cutoff');

my @stage_list = ('initialize',
                  'prepare-input',
                  'write-properties',
                  'build-database',
                  'split',
                  'blast',
                  'core',
                  'alignment',
                  'pseudoalign',
                  'build-phylogeny',
                  'phylogeny-graphic'
                 );

my %stage_table = ( 'initialize' => \&_initialize,
                    'prepare-input' => \&_build_input_fasta,
                    'write-properties' => \&_write_properties,
                    'build-database' => \&_create_input_database,
                    'split' => \&_perform_split,
                    'blast' => \&_perform_blast,
                    'core' => \&_find_core,
                    'alignment' => \&_align_orthologs,
                    'pseudoalign' => \&_pseudoalign,
                    'build-phylogeny' => \&_build_phylogeny,
                    'phylogeny-graphic' => \&_build_phylogeny_graphic,
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

    $self->{'verbose'} = 0;
    $self->{'script_dir'} = $script_dir;
    $self->{'keep_files'} = 1;
    $self->{'job_properties'} = {};
    $self->_check_stages;
    $self->{'job_properties'}->{'core_snp_base'} = 'snps';
    $self->{'job_properties'}->{'all_input_fasta'} = 'all.fasta';
    $self->{'job_properties'}->{'bioperl_index'} = 'all.fasta.idx';
    $self->{'job_properties'}->{'pid_cutoff'} = 99;
    $self->{'job_properties'}->{'hsp_length'} = 400;

    return $self;
}

sub set_job_dir
{
    my ($self,$job_dir) = @_;

    die "Job dir $job_dir does not exist" if (not -e $job_dir);

    my $abs_job_dir = abs_path($job_dir);
    $self->{'job_dir'} = $abs_job_dir;

    my $job_properties = $self->{'job_properties'};
    $job_properties->{'log_dir'} = "log";
    $job_properties->{'fasta_dir'} = "fasta";
    $job_properties->{'database_dir'} = "database";
    $job_properties->{'split_dir'} = "split";
    $job_properties->{'blast_dir'} = "blast";
    $job_properties->{'core_dir'} = "core";
    $job_properties->{'align_dir'} = "align";
    $job_properties->{'pseudoalign_dir'} = "pseudoalign";
    $job_properties->{'stage_dir'} = "stages";
    $job_properties->{'phylogeny_dir'} ='phylogeny';
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

    my $abs_job_dir = abs_path($job_dir);
    my $properties_path = "$abs_job_dir/$properties_filename";
    die "Cannot resubmit $abs_job_dir, file $properties_path not found" if (not -e $properties_path);

    $self->{'job_dir'} = $abs_job_dir;

    $self->_read_properties($properties_path);
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
    $self->{'job_properties'}->{'hsp_length'} = $length;
}

sub set_pid_cutoff
{
    my ($self,$pid_cutoff) = @_;

    $self->{'job_properties'}->{'pid_cutoff'} = $pid_cutoff;
}

sub set_verbose
{
    my ($self,$verbose) = @_;
    $self->{'verbose'} = $verbose;
}

sub _set_split_file
{
    my ($self,$file) = @_;
    $self->{'job_properties'}->{'split_file'} = $file;
    $self->{'job_properties'}->{'blast_base'} = basename($file).'.out';
}

sub set_processors
{
    my ($self,$processors) = @_;
    $self->{'job_properties'}->{'processors'} = $processors;
}

sub set_keep_files
{
    my ($self,$keep_files) = @_;
    $self->{'keep_files'} = (defined $keep_files and $keep_files);
}

sub set_strain_count
{
    my ($self,$strain_count) = @_;
    $self->{'job_properties'}->{'strain_count_manual'} = $strain_count;
}

sub set_input_fasta
{
    my ($self,$file) = @_;

    die "File $file does not exists" if (not -e $file);

    my $abs_input_fasta = abs_path($file);

    if (-d $abs_input_fasta)
    {
        $self->{'job_properties'}->{'input_fasta_dir'} = $abs_input_fasta;
    }
    else
    {
        $self->{'job_properties'}->{'input_fasta_file'} = $abs_input_fasta;
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

    my $stage_sub = $stage_table{$stage};
    my $stage_dir = $self->_get_file('stage_dir');

    if (defined $stage_sub)
    {
        &$stage_sub($self,$stage);
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

    my $start_stage = $self->{'start_stage'};
    my $end_stage = $self->{'end_stage'};

    die "Start stage not defined" if (not defined $start_stage);
    die "End stage not defined" if (not defined $end_stage);

    my $job_properties = $self->{'job_properties'};
    print "Running core SNP phylogenomic pipeline on ".`date`;
    print "\nParameters:\n";
    print "\tjob_dir = ".$self->{'job_dir'}."\n";
    foreach my $k (keys %$job_properties)
    {
        print "\t$k = ".$job_properties->{$k}."\n";
    }
    print "\n";

    my $seen_start = 0;
    my $seen_end = 0;

    # remove "done" files from all stages after the starting stage
    my $stage_dir = $self->_get_file('stage_dir');
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
            print "\nSkipping stage: $stage\n" if ($verbose);
        }
        $seen_end = 1 if ($stage eq $end_stage);
    }
}

sub _is_stage_complete
{
    my ($self,$stage) = @_;

    my $stages_dir = $self->_get_file('stage_dir');

    return (-e "$stages_dir/$stage.done");
}

sub _initialize
{
    my ($self) = @_;

    my $properties = $self->{'job_properties'};

    mkdir $self->{'job_dir'} if (not -e $self->{'job_dir'});

    for my $dir_name (@valid_job_dirs)
    {
        my $dir = $self->_get_file($dir_name);
        mkdir $dir if (defined $dir and not -e $dir);    
    }
}

sub _check_job_queue_for
{
    my ($self,$job_name) = @_;

    my @qstata = `qstat`;
    my $qstat = join "",@qstata;

    return ($qstat =~ /$job_name/);
}

sub _wait_until_completion
{
    my ($self,$job_name) = @_;

    my $completed = 0;
    while (not $completed)
    {
        sleep 10;
        print ".";
        $completed = not $self->_check_job_queue_for($job_name);
    }
}

sub _build_phylogeny_graphic
{
    my ($self,$stage) = @_;

    my $verbose = $self->{'verbose'};
    my $job_properties = $self->{'job_properties'};
    my $working_dir = $self->_get_file('phylogeny_dir');
    my $log_dir = $self->_get_file('log_dir');

    my $log_file = "$log_dir/figtree.log";

    my $tree_file = "$working_dir/pseudoalign.phy_phyml_tree.txt";

    print "\nStage: $stage\n";
    print "Building phylogeny tree graphic ...\n";

    print "\tChecking for figtree ...\n";
    my $figtree_check = 'which figtree 1>/dev/null 2>&1';
    print "$figtree_check" if ($verbose);
    system($figtree_check) == 0 or warn "Could not find figtree with $figtree_check";
    print "\t...done\n";

    print "\tGenerating image with figtree ...\n";
    print "\tMore information can be found at $log_file\n";
    die "Error: file $tree_file does not exist" if (not -e $tree_file);
    my $tree_image = "$tree_file.pdf";
    my $figtree_command = "figtree -graphic PDF \"$tree_file\" \"$tree_image\" 1>\"$log_file\" 2>&1";
    print "\t$figtree_command" if ($verbose);
    if(system($figtree_command) != 0)
    {
        print STDERR "Warning: Could not generate image using figtree";
    }
    else
    {
        print "\tphylogenetic tree image can be found at $tree_image\n";
    }
    print "\t...done\n";
    print "...done\n";
}

sub _build_phylogeny
{
    my ($self,$stage) = @_;

    my $verbose = $self->{'verbose'};
    my $job_properties = $self->{'job_properties'};
    my $input_dir = $self->_get_file('pseudoalign_dir');
    my $output_dir = $self->_get_file('phylogeny_dir');
    my $log_dir = $self->_get_file('log_dir');

    my $pseudoalign_file_name = "pseudoalign.phy";
    my $pseudoalign_file = "$input_dir/$pseudoalign_file_name";
    my $phyml_log = "$log_dir/phyml.log";

    print "\nStage: $stage\n";
    print "Building phylogeny ...\n";

    print "\tChecking for phyml ...\n";
    my $phyml_check_command = "which phyml 1>/dev/null 2>&1";
    print "\t$phyml_check_command" if ($verbose);
    system($phyml_check_command) == 0 or warn "\tUnable to find phyml using \"$phyml_check_command\"";
    print "\t...done\n";


    print "\tRunning phyml ...\n";
    print "\tMore information can be found at $phyml_log\n";
    die "Error: pseudoalign file $pseudoalign_file does not exist" if (not -e $pseudoalign_file);
    my $phylogeny_command = "phyml -i \"$pseudoalign_file\" 1>\"$phyml_log\" 2>&1";
    print "\t$phylogeny_command" if ($verbose);
    if(system($phylogeny_command) != 0)
    {
        print STDERR "Warning: could not execute $phylogeny_command, skipping stage \"$stage\"\n";
    }
    else
    {
        my $stats_name = "${pseudoalign_file_name}_phyml_stats.txt";
        my $stats_in = "$input_dir/$stats_name";
        my $stats_out = "$output_dir/$stats_name";
        my $tree_name = "${pseudoalign_file_name}_phyml_tree.txt";
        my $tree_in = "$input_dir/$tree_name";
        my $tree_out = "$output_dir/$tree_name";
        move($stats_in,$output_dir) or die "Could not move $stats_in to $output_dir: $!";
        move($tree_in,$output_dir) or die "Could not move $tree_in to $output_dir: $!";

        print "\tOutput can be found in $output_dir\n";
    }
    print "\t...done\n";


    print "...done\n";
}

# returns split file base path
sub _perform_split
{
    my ($self,$stage) = @_;

    my $verbose = $self->{'verbose'};
    my $job_properties = $self->{'job_properties'};
    my $input_file = $self->_get_file('fasta_dir').'/'.$self->_get_file('split_file');
    my $script_dir = $self->{'script_dir'};
    my $log_dir = $self->_get_file('log_dir');
    my $output_dir = $self->_get_file('split_dir');
    my $split_number = $job_properties->{'processors'};

    my $split_log = "$log_dir/split.log";

    require("$script_dir/../lib/split.pl");

    die "input file: $input_file does not exist" if (not -e $input_file);
    die "output directory: $output_dir does not exist" if (not -e $output_dir);

    print "\nStage: $stage\n";
    print "Performing split ...\n";
    print "\tSplitting $input_file into $split_number pieces ...\n";
    print "\t\tSee $split_log for more information.\n";
    Split::run($input_file,$split_number,$output_dir,$split_log);
    print "...done\n";
}

sub _read_properties
{
    my ($self,$file) = @_;
    my $job_properties = $self->{'job_properties'};

    open(my $in_fh, '<', $file) or die "Could not open $file: $!\n";
    while (my $line = <$in_fh>)
    {
        chomp $line;

        my ($real_content) = ($line =~ /^([^#]*)/);
        if (defined $real_content)
        {
            my ($key,$value) = ($real_content =~ /^([^=]+)=(.*)$/);

            if (defined $key and defined $value)
            {
                $job_properties->{$key} = $value;
            }
        }
    }
}

sub _write_properties
{
    my ($self,$stage) = @_;
    my $verbose = $self->{'verbose'};

    my $job_properties = $self->{'job_properties'};
    my $output = $self->{'job_dir'}."/$properties_filename";
    
    print "\nStage: $stage\n" if ($verbose);
    print "Writing properties file to $output...\n" if ($verbose);
    open(my $out_fh, '>', $output) or die "Could not write to $output: $!";
    print $out_fh "#Properties for snp-phylogenomics job\n";
    print $out_fh "#Auto-generated on ".`date`."\n";
    foreach my $key (keys %$job_properties)
    {
        print $out_fh "$key=".$job_properties->{$key}."\n";
    }
    close($out_fh);
    print "...done\n" if ($verbose);
}

# Counts duplicate ids for genes in fasta formatted files
# Input:  $input_file  If file is regular file, counts only in file.
#          if file is directory, counts all files in directory
sub _duplicate_count
{
    my ($self,$input_file) = @_;

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

    print "$duplicate_count_command\n" if ($self->{'verbose'});

    my $duplicate_count = `$duplicate_count_command`;
    chomp $duplicate_count;

    die "Error in duplicate id command, output \"$duplicate_count\" not a number" if ($duplicate_count !~ /^\d+$/);

    # added to show which ids are duplicated, inefficient (re-runs)
    if ($self->{'verbose'})
    {
        print "\t\tDuplicates ...\n";
        print "\t\tCount ID\n";
        print `$duplicate_text_command`;
        print "\t\t...done\n";
    }

    return $duplicate_count;
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

sub _get_file
{
    my ($self,$file) = @_;

    if (defined $file and $self->_exists_in_array($file,\@valid_job_dirs))
    {
        my $file_name = $self->{'job_properties'}->{$file};
        if (defined $file_name)
        {
            return $self->{'job_dir'}.'/'.$file_name;
        }
    }
    elsif (defined $file and $self->_exists_in_array($file,\@valid_other_files))
    {
        my $file_name = $self->{'job_properties'}->{$file};
        if (defined $file_name)
        {
            return $file_name;
        }
    }

    return undef;
}

sub _create_input_database
{
    my ($self,$stage) = @_;
    my $verbose = $self->{'verbose'};
    my $job_properties = $self->{'job_properties'};
    my $input_file = $self->_get_file('fasta_dir').'/'.$job_properties->{'all_input_fasta'};
    my $database_output = $self->_get_file('database_dir');
    my $log_dir = $self->_get_file('log_dir');
    my $script_dir = $self->{'script_dir'};

    my $input_fasta_path = $self->_get_file('database_dir').'/'.$job_properties->{'all_input_fasta'};

    my $formatdb_log = "$log_dir/formatdb.log";

    die "Input file $input_file does not exist" if (not -e $input_file);
    die "Output directory: $database_output does not exist" if (not -e $database_output);

    print "\nStage: $stage\n";
    print "Creating initial databases ...\n";
    print "\tChecking for features in $input_file with duplicate ids...\n";
    my $duplicate_count = $self->_duplicate_count($input_file);
    print "\t\tDuplicate ids: $duplicate_count\n" if ($verbose);
    print "\t...done\n";

    die "Error: $duplicate_count duplicate ids found in input fasta $input_file\n" if ($duplicate_count > 0);

    copy($input_file, $input_fasta_path) or die "Could not copy $input_file to $input_fasta_path: $!";

    my $formatdb_command = "formatdb -i \"$input_fasta_path\" -p F -l \"$formatdb_log\"";
    my $index_command = "perl \"$script_dir/../lib/index.pl\" \"$input_fasta_path\"";

    print "\tCreating BLAST formatted database ...\n";
    print "\t\t$formatdb_command\n" if ($verbose);
    system($formatdb_command) == 0 or die "Error for command: $formatdb_command: $!";
    print "\t...done\n";

    print "\tCreating bioperl index ...\n";
    print "\t\t$index_command\n" if ($verbose);
    system($index_command) == 0 or die "Error for command: $index_command: $!";
    print "\t...done\n";

    print "...done\n";
}

sub _print_sge_script
{
    my ($self, $processors, $script_path, $command) = @_;

    open(my $sge_fh, '>', $script_path) or die "Could not open $script_path for writing";
    print $sge_fh "#!/bin/sh\n";
    print $sge_fh "#\$ -t 1-$processors\n";
    print $sge_fh $command;
    print $sge_fh "\n";
    close($sge_fh);
}

sub _get_job_id
{
    my ($self) = @_;

    return sprintf "x%08x", time;
}

# return blast output base path
sub _perform_blast
{
    my ($self,$stage) = @_;
    my $job_properties = $self->{'job_properties'};
    my $input_task_base = $self->_get_file('split_dir').'/'.(basename $job_properties->{'split_file'});
    my $output_dir = $self->_get_file('blast_dir');
    my $processors = $job_properties->{'processors'};
    my $database = $self->_get_file('database_dir').'/'.$job_properties->{'all_input_fasta'};
    my $log_dir = $self->_get_file('log_dir');
    my $blast_task_base = $job_properties->{'blast_base'}; 
    my $verbose = $self->{'verbose'};

    die "Input files $input_task_base.x do not exist" if (not -e "$input_task_base.1");
    die "Output directory $output_dir does not exist" if (not -e $output_dir);
    die "Database $database does not exist" if (not -e $database);

    print "\nStage: $stage\n";
    print "Performing blast ...\n";
    mkdir "$output_dir" if (not -e $output_dir);
    my $blast_base_path = "$output_dir/$blast_task_base";

    my $job_name = $self->_get_job_id;

    my $blast_sge = "$output_dir/blast.sge";
    print "\tWriting $blast_sge script ...\n";
    my $sge_command = "blastall -p blastn -i \"$input_task_base.\$SGE_TASK_ID\" -o \"$blast_base_path.\$SGE_TASK_ID\" -d \"$database\"\n";
    $self->_print_sge_script($processors, $blast_sge, $sge_command);
    print "\t...done\n";

    my $error = "$log_dir/blast.error.sge";
    my $out = "$log_dir/blast.out.sge";
    my $submission_command = "qsub -N $job_name -cwd -S /bin/sh -e \"$error\" -o \"$out\" \"$blast_sge\" 1>/dev/null";
    print "\tSubmitting $blast_sge for execution ...\n";
    print "\t\tSee ($out) and ($error) for details.\n";
    print "\t\t$submission_command\n" if ($verbose);
    system($submission_command) == 0 or die "Error submitting $submission_command: $!\n";
    print "\t\tWaiting for completion of blast job array $job_name";
    $self->_wait_until_completion($job_name);
    print "done\n";
    print "...done\n";
}

sub _find_core
{
    my ($self,$stage) = @_;

    my $job_properties = $self->{'job_properties'};
    my $snps_output = $self->_get_file('core_dir');
    my $bioperl_index = $self->_get_file('database_dir').'/'.$job_properties->{'bioperl_index'};
    my $processors = $job_properties->{'processors'};
    my $strain_count = $job_properties->{'strain_count'};
    my $pid_cutoff = $job_properties->{'pid_cutoff'};
    my $hsp_length = $job_properties->{'hsp_length'};
    my $log_dir = $self->_get_file('log_dir');
    my $core_snp_base = $job_properties->{'core_snp_base'};
    my $script_dir = $self->{'script_dir'};

    my $blast_dir = $self->_get_file('blast_dir');
    my $blast_input_base = $blast_dir.'/'.$job_properties->{'blast_base'};

    my $verbose = $self->{'verbose'};

    die "Input files $blast_input_base.x do not exist" if (not -e "$blast_input_base.1");
    die "Output directory $snps_output does not exist" if (not -e $snps_output);
    die "Bioperl index $bioperl_index does not exist" if (not -e $bioperl_index);
    die "Strain count is invalid" if (not defined ($strain_count) or $strain_count <= 0);
    die "Pid cutoff is invalid" if (not defined ($pid_cutoff) or $pid_cutoff <= 0 or $pid_cutoff > 100);
    die "HSP length is invalid" if (not defined ($hsp_length) or $hsp_length <= 0);

    my $core_snp_base_path = "$snps_output/$core_snp_base";

    print "\nStage: $stage\n";
    print "Performing core genome SNP identification ...\n";
    my $core_sge = "$snps_output/core.sge";
    print "\tWriting $core_sge script ...\n";
    my $sge_command = "$script_dir/../lib/coresnp2.pl -b \"$blast_input_base.\$SGE_TASK_ID\" -i \"$bioperl_index\" -c $strain_count -p $pid_cutoff -l $hsp_length -o \"$snps_output\"\n";
    $self->_print_sge_script($processors, $core_sge, $sge_command);
    print "\t...done\n";

    my $job_name = $self->_get_job_id;

    my $error = "$log_dir/core.error.sge";
    my $out = "$log_dir/core.out.sge";
    my $submission_command = "qsub -N $job_name -cwd -S /bin/sh -e \"$error\" -o \"$out\" \"$core_sge\" 1>/dev/null";
    print "\tSubmitting $core_sge for execution ...\n";
    print "\t\tSee ($out) and ($error) for details.\n";
    print "\t\t$submission_command\n" if ($verbose);
    system($submission_command) == 0 or die "Error submitting $submission_command: $!\n";
    print "\t\tWaiting for completion of core sge job array $job_name";
    $self->_wait_until_completion($job_name);
    print "done\n";

    require("$script_dir/../lib/rename.pl");
    print "\tRenaming SNP output files...\n";
    Rename::run($snps_output,$snps_output);
    print "\t...done\n";

    print "...done\n";
}

sub _largest_snp_file
{
    my ($self,$core_dir, $core_snp_base) = @_;
    my $verbose = $self->{'verbose'};

    print "\tGetting largest SNP file...\n";
    my $max = -1;
    opendir(my $dir_h,$core_dir);
    while(my $file = readdir $dir_h)
    {
        my ($curr_num) = ($file =~ /^$core_snp_base(\d+)$/);
        $max = $curr_num if (defined $curr_num and $curr_num > $max);
    }
    close ($dir_h);
    print "\t\tMax: $max\n";
    die "Error, no snp files" if ($max <= 0);

    print "\t...done\n";

    return $max;
}

sub _align_orthologs
{
    my ($self,$stage) = @_;
    my $job_properties = $self->{'job_properties'};
    my $core_dir = $self->_get_file('core_dir');
    my $input_task_base = "$core_dir/".$job_properties->{'core_snp_base'};
    my $output_dir = $self->_get_file('align_dir');
    my $log_dir = $self->_get_file('log_dir');
    my $script_dir = $self->{'script_dir'};
    my $verbose = $self->{'verbose'};

    die "Input files ${input_task_base}x do not exist" if (not -e "${input_task_base}1");
    die "Output directory $output_dir does not exist" if (not -e $output_dir);

    my $input_dir = dirname($input_task_base);

    my $job_name = $self->_get_job_id;

    print "\nStage: $stage\n";
    print "Performing multiple alignment of orthologs ...\n";

    my $max_snp_number = $self->_largest_snp_file($core_dir, $job_properties->{'core_snp_base'});
    die "Largest SNP number is invalid" if (not defined $max_snp_number or $max_snp_number <= 0);

    my $clustalw_sge = "$output_dir/clustalw.sge";
    print "\tWriting $clustalw_sge script ...\n";
    my $sge_command = "clustalw2 -infile=${input_task_base}\$SGE_TASK_ID";
    $self->_print_sge_script($max_snp_number, $clustalw_sge, $sge_command);
    print "\t...done\n";

    my $error = "$log_dir/clustalw.error.sge";
    my $out = "$log_dir/clustalw.out.sge";
    my $submission_command = "qsub -N $job_name -cwd -S /bin/sh -e \"$error\" -o \"$out\" \"$clustalw_sge\" 1>/dev/null";
    print "\tSubmitting $clustalw_sge for execution ...\n";
    print "\t\tSee ($out) and ($error) for details.\n";
    print "\t\t$submission_command\n" if ($verbose);
    system($submission_command) == 0 or die "Error submitting $submission_command: $!\n";
    print "\t\tWaiting for completion of clustalw job array $job_name";
    $self->_wait_until_completion($job_name);
    print "done\n";

    opendir(my $align_dh, $input_dir) or die "Could not open $input_dir: $!";
    my @align_files = grep {/snps\d+\.aln/} readdir($align_dh);
    close($align_dh);
    print "\tMoving alignment files ...\n";
    foreach my $file_in (@align_files)
    {
        move("$input_dir/$file_in", "$output_dir/".basename($file_in)) or die "Could not move file $file_in: $!";
    }
    print "\t...done\n";

    my $log = "$log_dir/trim.log";
    require("$script_dir/../lib/trim.pl");
    print "\tTrimming alignments (see $log for details) ...\n";
    Trim::run($output_dir,$output_dir,$log);
    print "\t...done\n";

    print "...done\n";
}

sub _pseudoalign
{
    my ($self,$stage) = @_;
    my $job_properties = $self->{'job_properties'};
    my $script_dir = $self->{'script_dir'};
    my $verbose = $self->{'verbose'};

    my $align_input = $self->_get_file('align_dir');
    my $output_dir = $self->_get_file('pseudoalign_dir');
    my $log_dir = $self->_get_file('log_dir');

    die "Error: align_input directory does not exist" if (not -e $align_input);
    die "Error: pseudoalign output directory does not exist" if (not -e $output_dir);

    my $log = "$log_dir/pseudoaligner.log";

    print "\nStage: $stage\n";
    print "Creating pseudoalignment ...\n";

    require("$script_dir/../lib/pseudoaligner.pl");
    print "\tRunning pseudoaligner (see $log for details) ...\n";
    Pseudoaligner::run($align_input,$output_dir,$log);
    print "\t...done\n";

    print "...done\n";

    print "\n\nPseudoalignment and snp report generated.\n";
    print "Files can be found in $output_dir\n";
}

# returns main input file and count of strains
sub _build_input_fasta
{
    my ($self,$stage) = @_;
    my $verbose = $self->{'verbose'};
    my $job_properties = $self->{'job_properties'};
    my $input_dir = $self->_get_file('input_fasta_dir');
    my $input_file = $self->{'input_fasta_file'};
    my $output_dir = $self->_get_file('fasta_dir');

    my $all_input_file = $output_dir.'/'.$job_properties->{'all_input_fasta'};

    die "Output directory is invalid" if (not -d $output_dir);

    print "\nStage: $stage\n";
    print "Preparing input files...\n";

    if (defined $input_file)
    {
        copy($input_file,$all_input_file) or die "Could not copy $input_file: $!";
        if (not defined $job_properties->{'strain_count_manual'})
        {
            die "Strain count not defined";
        }
        else
        {
            $job_properties->{'strain_count'} = $job_properties->{'strain_count_manual'};
        }
    }
    elsif (defined $input_dir)
    {
        die "Input directory is invalid" if (not -d $input_dir);
	my $sep_char = '|';
    
        opendir(my $input_dh, $input_dir) or die "Could not open $input_dir: $!";
        my @files = grep {/fasta$/i} readdir($input_dh);
        close($input_dh);

        die "No input fasta files found in $input_dir" if (scalar(@files) <= 0);

        print "\tCopying input files to $output_dir\n";
        foreach my $file (@files)
        {
            my $input_path = "$input_dir/$file";
            my $output_file = "$file.prepended.fasta";
            my $output_path = "$output_dir/$output_file";
            copy($input_path,$output_path) or die "Could not copy $file from $input_dir to $output_dir: $!";

            if (not defined $job_properties->{'split_file'})
            {
                print "\t\tSetting split file to $output_path\n";
                $self->_set_split_file($output_file);
            }
        }
        print "\t...done\n";

        print "\tChecking for unique names across all sequences in input fasta files...\n";
	my @files_to_append_separator;
	my %name_file_map; # used to map the name of a sequence to a file (for checking for unique separators)
        foreach my $file (@files)
        {
            my $output_path = "$output_dir/$file.prepended.fasta";

            print "\t\tFinding existing unique headers for $output_path ...\n";
            my $unique_command = "grep '^>' \"$output_path\" | cut -d '$sep_char' -f 1|sort -u|wc -l";
            print "\t\t\t$unique_command\n" if ($verbose);
            my $unique_count = `$unique_command`;

            die "Invalid unique count" if (not defined $unique_count or $unique_count !~ /^\d+$/);
            if ($unique_count == 1)
            {
                print "\t\t\tFile $output_path contains single unique name for all sequences\n";
                my $find_name_command = "grep '^>' \"$output_path\" | cut -d '$sep_char' -f 1|sort -u";
                print "\t\t\t$find_name_command\n" if ($verbose);
                my $unique_name = `$find_name_command`;
                chomp $unique_name;
                die "Invalid unique name" if (not defined $unique_count);

                if (exists $name_file_map{$unique_name})
                {
                    print "\t\t\tName $unique_name not unique across all strains, need to generate new unique name for file $output_path\n";
                    push(@files_to_append_separator, $file);
                }
                else
                {
                    print "\t\t\tName: $unique_name\n";
                    $name_file_map{$unique_name} = $file;
                }
            }
            else
            {
                print "\t\t\tFile $output_path has no single unique name for all sequences, need to generate new unique name\n";
                push(@files_to_append_separator,$file);
            }

            print "\t\t...done\n";
        }

        print "\t\tGenerating unique names for strains for files...\n" if (@files_to_append_separator > 0);
        foreach my $file (@files_to_append_separator)
        {
            my ($name) = ($file =~ /^([^\.]+)\./);

            die "Cannot take id from file name for $input_dir/$file" if (not defined $name);
            my $output_file = "$file.prepended.fasta";
            my $output_path = "$output_dir/$output_file";

            my $remove_sep_char_command = "sed -i \"s/$sep_char/_/\" \"$output_path\"";
            print "\t\t\tRemoving existing separator char\n" if ($verbose);
            print "\t\t\t$remove_sep_char_command\n" if ($verbose);
            system($remove_sep_char_command) == 0 or die "Error attempting to remove existing separator char: $!";

            my $uniquify_command = "sed -i \"s/>/>$name\|/\" \"$output_path\"";
            print "\t\t\tGenerating unique name for file $output_path\n";
            print "\t\t\t$uniquify_command\n" if ($verbose);
            system($uniquify_command) == 0 or die "Error attempting to create unique gene ids: $!";
        }
        print "\t\t...done\n" if (@files_to_append_separator > 0);
        print "\t...done\n";
    
        my $strain_count = 0;
    
        my @files_to_build;
        my $file_dir;

        opendir(my $input_build_dh, $output_dir) or die "Could not open $output_dir: $!";
        $file_dir = $output_dir;
        @files_to_build = grep {/prepended\.fasta$/} readdir($input_build_dh);
        close($input_build_dh);
    
        $strain_count = scalar(@files_to_build);
    
        print "\tBuilding single multi-fasta file $all_input_file ...\n";
        open(my $out_fh, '>', "$all_input_file") or die "Could not open file $all_input_file: $!";
        foreach my $file (@files_to_build)
        {
            print "\t\treading $file_dir/$file\n" if ($verbose);
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
        print "\t...done\n";
    
        if (not defined $job_properties->{'strain_count_manual'})
        {
            $job_properties->{'strain_count'} = $strain_count;
        }
        else
        {
            $job_properties->{'strain_count'} = $job_properties->{'strain_count_manual'};
        }
    }
    else
    {
        die "No input file or input directory defined";
    }

    print "...done\n";
}

#print "Storing all data under $job_dir\n";
#mkdir $job_dir if (not -e $job_dir);
#mkdir $log_dir if (not -e $log_dir);
#
#if (defined $input_dir)
#{
#    mkdir ($fasta_output) if (not -e $fasta_output);
#
#    print "Preparing files under $input_dir ...\n";
#    print "We assume all files under $input_dir are fasta-formatted and should be included in pipeline\n";
#    my ($input_fasta_auto, $strain_count_auto) = build_input_fasta($input_dir,$fasta_output);
#    print "...done\n";
#
#    die "Error creating input fasta file" if (not -e $input_fasta_auto);
#    die "Error getting strain count" if (not defined $strain_count_auto or $strain_count_auto !~ /\d+/);
#
#    $input_fasta = $input_fasta_auto;
#
#    # only set to auto-value if not already set
#    $strain_count = $strain_count_auto if (not defined $strain_count);
#}

#if (not $keep_files)
#{
#    if (defined $input_dir)
#    {
#        print "Cleaning $fasta_output\n" if ($verbose);
#        rmtree($fasta_output) or die "Error: could not delete $fasta_output";
#    }
#}
#
#if (not $keep_files)
#{
#    print "Cleaning $database_output\n" if ($verbose);
#    rmtree($database_output) or die "Error: could not delete $database_output";
#
#    print "Cleaning $split_output\n" if ($verbose);
#    rmtree($split_output) or die "Error: could not delete $split_output";
#
#    print "Cleaning $blast_output\n" if ($verbose);
#    rmtree($blast_output) or die "Error: could not delete $blast_output";
#}
#
#if (not $keep_files)
#{
#    print "Cleaning $core_snp_output\n" if ($verbose);
#    rmtree($core_snp_output) or die "Error: could not delete $core_snp_output";
#}
#
#if (not $keep_files)
#{
#    print "Cleaning $align_output\n" if ($verbose);
#    rmtree($align_output) or die "Error: could not delete $align_output";
#}
#
#print "\n\nPseudoalignment and snp report generated.\n";
#print "Files can be found in $pseudoalign_output\n";

1;
