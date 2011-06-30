#!/usr/bin/perl

package Pipeline;

use strict;
use warnings;

use File::Basename qw(basename dirname);
use File::Copy qw(copy move);
use File::Path qw(rmtree);

my $properties_filename = 'run.properties';
my @valid_dirs = ('job_dir','log_dir','fasta_dir','database_dir','split_dir','blast_dir','core_dir',
                  'align_dir','pseudoalign_dir');
my @valid_properties = join(@valid_dirs,'hsp_length','pid_cutoff');

sub new
{
    my ($class,$script_dir) = @_;

    my $self = {};
    bless($self,$class);

    $self->{'verbose'} = 0;
    $self->{'script_dir'} = $script_dir;
    $self->{'keep_files'} = 1;
    $self->{'job_properties'} = {};
    $self->_create_stages;
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

    my $job_properties = $self->{'job_properties'};
    $job_properties->{'job_dir'} = $job_dir;
    $job_properties->{'log_dir'} = "$job_dir/log";
    $job_properties->{'fasta_dir'} = "$job_dir/fasta";
    $job_properties->{'database_dir'} = "$job_dir/database";
    $job_properties->{'split_dir'} = "$job_dir/split";
    $job_properties->{'blast_dir'} = "$job_dir/blast";
    $job_properties->{'core_dir'} = "$job_dir/core";
    $job_properties->{'align_dir'} = "$job_dir/align";
    $job_properties->{'pseudoalign_dir'} = "$job_dir/pseudoalign";
}

sub set_start_stage
{
    my ($self,$start_stage) = @_;
    my @stage_list = @{$self->{'stage_list'}};
    my $end_stage = $self->{'end_stage'};

    die "Cannot resubmit to undefined ending stage" if (not defined $start_stage);
    die "Cannot resubmit to invalid stage $start_stage" if (not $self->is_valid_stage($start_stage));
    die "Cannot resubmit to invalid stage $end_stage" if (not $self->_validate_stages($start_stage,$end_stage));

    $self->{'start_stage'} = $start_stage;
}

sub set_end_stage
{
    my ($self,$end_stage) = @_;
    my @stage_list = @{$self->{'stage_list'}};

    my $start_stage = $self->{'start_stage'};

    die "Cannot resubmit to undefined ending stage" if (not defined $end_stage);
    die "Cannot resubmit to invalid stage $end_stage" if (not $self->is_valid_stage($end_stage));
    die "Cannot resubmit to invalid stage $end_stage" if (not $self->_validate_stages($start_stage,$end_stage));

    $self->{'end_stage'} = $end_stage;
}

sub _validate_stages
{
    my ($self,$start_stage,$end_stage) = @_;

    my $is_valid = 1;

    my @stage_list = @{$self->{'stage_list'}};

    my $seen_start = 0;
    my $seen_end = 0;
    foreach my $valid_stage (@stage_list)
    {
        $seen_start = 1 if ($valid_stage eq $start_stage);
        $seen_end = 1 if ($valid_stage eq $end_stage);
        $is_valid = 0 if ($seen_end and (not $seen_start));
    }
    $is_valid = 0 if (not $seen_end);

    return $is_valid;
}

# Purpose: Resubmits the passed job through the pipeline going through the given stages
# Input:  $job_dir  The directory of the previously run job
# Output: Sets up the pipeline to run with the given properties
sub resubmit
{
    my ($self,$job_dir) = @_;

    my @stage_list = @{$self->{'stage_list'}};

    my $properties_path = "$job_dir/$properties_filename";

    die "Cannot resubmit to undefined job_dir" if (not defined $job_dir);
    die "Cannot resubmit $job_dir, file $properties_path not found" if (not -e $properties_path);
    die "Cannot resubmit to non-existant job_dir $job_dir" if (not -d $job_dir);

    $self->_read_properties($properties_path);
}

sub get_first_stage
{
    my ($self) = @_;

    my $stage_list = $self->{'stage_list'};
    return $stage_list->[0];
}

sub get_last_stage
{
    my ($self) = @_;

    my $stage_list = $self->{'stage_list'};
    return $stage_list->[-1];
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

sub set_split_file
{
    my ($self,$file) = @_;
    $self->{'job_properties'}->{'split_file'} = $file;
    $self->{'job_properties'}->{'blast_base'} = basename($file).'.out';
    $self->{'job_properties'}->{'split_base'} = basename($file);
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

    if (-d $file)
    {
        $self->{'job_properties'}->{'input_fasta_dir'} = $file;
    }
    else
    {
        $self->{'job_properties'}->{'input_fasta_file'} = $file;
    }
}

sub _create_stages
{
    my ($self) = @_;

    my $stage_table = { 'initialize' => \&_initialize,
                        'prepare-input' => \&_build_input_fasta,
                        'write-properties' => \&_write_properties,
                        'build-database' => \&_create_input_database,
                        'split' => \&_perform_split,
                        'blast' => \&_perform_blast,
                        'identify-snps' => \&_perform_id_snps,
                        'alignment' => \&_align_orthologs,
                        'pseudoalign' => \&_pseudoalign
    };

    $self->{'stage_table'} = $stage_table;

    my $stage_list = ['initialize',
                      'prepare-input',
                      'write-properties',
                      'build-database',
                      'split',
                      'blast',
                      'identify-snps',
                      'alignment',
                      'pseudoalign'
                     ];

    $self->{'start_stage'} = $stage_list->[0];
    $self->{'end_stage'} = $stage_list->[-1];

    $self->{'stage_list'} = $stage_list;
}

sub _execute_stage
{
    my ($self,$stage) = @_;

    my $stage_table = $self->{'stage_table'};
    my $stage_sub = $stage_table->{$stage};

    if (defined $stage_sub)
    {
        &$stage_sub($self,$stage);
    }
    else
    {
        die "Invalid stage $stage, could not continue";
    }
}

sub is_valid_stage
{
    my ($self,$stage) = @_;
    my @stage_list = @{$self->{'stage_list'}};

    return (defined $stage) and (grep {$_ eq $stage} @stage_list);
}

sub execute
{
    my ($self) = @_;

    my $verbose = $self->{'verbose'};

    my $stage_list = $self->{'stage_list'};
    my $start_stage = $self->{'start_stage'};
    my $end_stage = $self->{'end_stage'};

    die "Start stage not defined" if (not defined $start_stage);
    die "End stage not defined" if (not defined $end_stage);
    die "Stage list not defined" if (not defined $stage_list);

    my $seen_start = 0;
    my $seen_end = 0;
    foreach my $stage (@$stage_list)
    {
        $seen_start = 1 if ($stage eq $start_stage);
        if ($seen_start and not $seen_end)
        {
            $self->_execute_stage($stage);
        }
        else
        {
            print "\nSkipping stage: $stage\n" if ($verbose);
        }
        $seen_end = 1 if ($stage eq $end_stage);
    }
}

sub _initialize
{
    my ($self) = @_;

    my $properties = $self->{'job_properties'};

    mkdir $properties->{'job_dir'} if (not -e $properties->{'job_dir'});

    for my $dir_name (@valid_dirs)
    {
        mkdir $properties->{$dir_name} if (not -e $properties->{$dir_name});    
    }

    # write properties file
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

# returns split file base path
sub _perform_split
{
    my ($self,$stage) = @_;

    my $verbose = $self->{'verbose'};
    my $job_properties = $self->{'job_properties'};
    my $input_file = $job_properties->{'split_file'};
    my $script_dir = $self->{'script_dir'};
    my $log_dir = $job_properties->{'log_dir'};
    my $output_dir = $job_properties->{'split_dir'};
    my $split_number = $job_properties->{'processors'};

    my $split_log = "$log_dir/split.log";

    my $command = "perl $script_dir/split.pl \"$input_file\" \"$split_number\" \"$output_dir\" 1> \"$split_log\" 2>&1";

    die "input file: $input_file does not exist" if (not -e $input_file);
    die "output directory: $output_dir does not exist" if (not -e $output_dir);

    print "\nStage: $stage\n";
    print "Performing split ...\n";
    print "\tSplitting $input_file into $split_number pieces ...\n";
    print "\t\t$command\n" if ($verbose);
    print "\t\tSee $split_log for more information.\n";
    system($command) == 0 or die "Error for command $command: $!";
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
    my $output = $job_properties->{'job_dir'}."/$properties_filename";
    
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

    my $duplicate_count_command;

    if ($is_dir)
    {
        $duplicate_count_command = "grep --only-match --no-filename '^>\\S*' \"$input_file\"/* | sort | uniq --count | grep --invert-match '^[ ^I]*1[ ^I]>' | wc -l";
    }
    else
    {
        $duplicate_count_command = "grep --only-match --no-filename '^>\\S*' \"$input_file\" | sort | uniq --count | grep --invert-match '^[ ^I]*1[ ^I]>' | wc -l";
    }

    print "$duplicate_count_command\n" if ($self->{'verbose'});

    my $duplicate_count = `$duplicate_count_command`;
    chomp $duplicate_count;

    die "Error in duplicate id command, output \"$duplicate_count\" not a number" if ($duplicate_count !~ /^\d+$/);

    return $duplicate_count;
}

sub _create_input_database
{
    my ($self,$stage) = @_;
    my $verbose = $self->{'verbose'};
    my $job_properties = $self->{'job_properties'};
    my $input_file = $job_properties->{'fasta_dir'}.'/'.$job_properties->{'all_input_fasta'};
    my $database_output = $job_properties->{'database_dir'};
    my $log_dir = $job_properties->{'log_dir'};
    my $script_dir = $self->{'script_dir'};

    my $input_fasta_path = $job_properties->{'database_dir'}.'/'.$job_properties->{'all_input_fasta'};

    my $formatdb_log = "$log_dir/formatdb.log";

    die "Input file $input_file does not exist" if (not -e $input_file);
    die "Output directory: $database_output does not exist" if (not -e $database_output);

    print "\nStage: $stage\n";
    print "Creating initial databases ...\n";
    print "\tChecking for features in $input_file with duplicate ids...\n";
    my $duplicate_count = $self->_duplicate_count($input_file);
    print "\t\tDuplicate ids: $duplicate_count\n" if ($verbose);
    print "\t...done\n";

    die "Error: duplicate ids found in input fasta $input_file\n" if ($duplicate_count > 0);

    copy($input_file, $input_fasta_path) or die "Could not copy $input_file to $input_fasta_path: $!";

    my $formatdb_command = "formatdb -i \"$input_fasta_path\" -p F -l \"$formatdb_log\"";
    my $index_command = "perl \"$script_dir/index.pl\" \"$input_fasta_path\"";

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
    my $input_task_base = $job_properties->{'split_dir'}.'/'.$job_properties->{'split_base'};
    my $output_dir = $job_properties->{'blast_dir'};
    my $processors = $job_properties->{'processors'};
    my $database = $job_properties->{'database_dir'}.'/'.$job_properties->{'all_input_fasta'};
    my $log_dir = $job_properties->{'log_dir'};
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

sub _perform_id_snps
{
    my ($self,$stage) = @_;

    my $job_properties = $self->{'job_properties'};
    my $snps_output = $job_properties->{'core_dir'};
    my $bioperl_index = $job_properties->{'database_dir'}.'/'.$job_properties->{'bioperl_index'};
    my $processors = $job_properties->{'processors'};
    my $strain_count = $job_properties->{'strain_count'};
    my $pid_cutoff = $job_properties->{'pid_cutoff'};
    my $hsp_length = $job_properties->{'hsp_length'};
    my $log_dir = $job_properties->{'log_dir'};
    my $core_snp_base = $job_properties->{'core_snp_base'};
    my $script_dir = $self->{'script_dir'};

    my $blast_dir = $job_properties->{'blast_dir'};
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
    my $sge_command = "$script_dir/coresnp2.pl \"$blast_input_base.\$SGE_TASK_ID\" \"$bioperl_index\" $strain_count $pid_cutoff $hsp_length \"$snps_output\"\n";
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

    my $rename_command = "perl $script_dir/rename.pl \"$snps_output\" \"$snps_output\"";
    print "\tRenaming SNP output files...\n";
    print "\t\t$rename_command\n" if ($verbose);
    system($rename_command) == 0 or die "Error renaming snp files: $!";
    print "\t...done\n";

    print "...done\n";
}

sub _count_snps
{
    my ($self,$core_snp_base_path) = @_;
    my $verbose = $self->{'verbose'};

    print "\tCounting SNP files...\n";
    my $count_command = "ls -1 \"$core_snp_base_path\"* | wc -l";
    my $count = undef;
    print "\t\t$count_command\n" if ($verbose);
    $count = `$count_command`;
    die "\t\tError counting snp files" if (not defined $count);
    die "\t\tError counting snp files, $count not a number" if ($count !~ /^\d+$/);
    die "\t\tError counting snp files, $count <= 0" if ($count <= 0);

    print "\t...done\n";

    return $count;
}

sub _align_orthologs
{
    my ($self,$stage) = @_;
    my $job_properties = $self->{'job_properties'};
    my $input_task_base = $job_properties->{'core_dir'}.'/'.$job_properties->{'core_snp_base'};
    my $output_dir = $job_properties->{'align_dir'};
    my $log_dir = $job_properties->{'log_dir'};
    my $script_dir = $self->{'script_dir'};
    my $verbose = $self->{'verbose'};

    die "Input files ${input_task_base}x do not exist" if (not -e "${input_task_base}1");
    die "Output directory $output_dir does not exist" if (not -e $output_dir);

    my $input_dir = dirname($input_task_base);

    my $job_name = $self->_get_job_id;

    print "\nStage: $stage\n";
    print "Performing multiple alignment of orthologs ...\n";

    my $snp_count = $self->_count_snps($input_task_base);
    die "SNP count is invalid" if (not defined $snp_count or $snp_count <= 0);

    my $clustalw_sge = "$output_dir/clustalw.sge";
    print "\tWriting $clustalw_sge script ...\n";
    my $sge_command = "clustalw2 -infile=${input_task_base}\$SGE_TASK_ID";
    $self->_print_sge_script($snp_count, $clustalw_sge, $sge_command);
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
    my $trim_command = "$script_dir/trim.pl \"$output_dir\" \"$output_dir\" 1>\"$log\" 2>&1";
    print "\tTrimming alignments (see $log for details) ...\n";
    print "\t\t$trim_command\n" if ($verbose);
    system($trim_command) == 0 or die "Error trimming alignments: $!\n";
    print "\t...done\n";

    print "...done\n";
}

sub _pseudoalign
{
    my ($self,$stage) = @_;
    my $job_properties = $self->{'job_properties'};
    my $script_dir = $self->{'script_dir'};
    my $verbose = $self->{'verbose'};

    my $align_input = $job_properties->{'align_dir'};
    my $output_dir = $job_properties->{'pseudoalign_dir'};
    my $log_dir = $job_properties->{'log_dir'};

    die "Error: align_input directory does not exist" if (not -e $align_input);
    die "Error: pseudoalign output directory does not exist" if (not -e $output_dir);

    my $log = "$log_dir/pseudoaligner.log";

    my $pseudoalign_command = "perl $script_dir/pseudoaligner.pl \"$align_input\" \"$output_dir\" 1>\"$log\" 2>&1";

    print "\nStage: $stage\n";
    print "Creating pseudoalignment ...\n";

    print "\tRunning pseudoaligner (see $log for details) ...\n";
    print "\t\t$pseudoalign_command\n" if ($verbose);
    system($pseudoalign_command) == 0 or die "Error running pseudoaligner: $!";
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
    my $input_dir = $job_properties->{'input_fasta_dir'};
    my $input_file = $job_properties->{'input_fasta_file'};
    my $output_dir = $job_properties->{'fasta_dir'};

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
    
        my $prepended = 0;
    
        print "\tChecking for unique genes...\n";
        my $count = $self->_duplicate_count($input_dir);
        if ($count > 0)
        {
            $prepended = 1;
            print "\t\t$count duplicate genes found, attempting to fix...\n";
    
            opendir(my $input_dh, $input_dir) or die "Could not open $input_dir: $!";
            my @files = grep {/fasta$/i} readdir($input_dh);
            close($input_dh);
    
            die "No input fasta files found in $input_dir" if (scalar(@files) <= 0);
            foreach my $file (@files)
            {
                my ($name) = ($file =~ /^([^\.]+)\./);
    
                die "Cannot take id from file name for $input_dir/$file" if (not defined $name);
                my $input_path = "$input_dir/$file";
                my $output_path = "$output_dir/$name.prepended.fasta";
                my $uniquify_command = "sed \"s/>/>$name\|/\" \"$input_path\" > \"$output_path\"";
                print "\t\t$uniquify_command\n" if ($verbose);
                system($uniquify_command) == 0 or die "Error attempting to create unique gene ids: $!";
            }
    
            print "\t\t...done\n";
        }
        print "\t...done\n";
    
        my $strain_count = 0;
    
        my @files;
        my $file_dir;
        if ($prepended)
        {
            opendir(my $input_dh, $output_dir) or die "Could not open $output_dir: $!";
            $file_dir = $output_dir;
            @files = grep {/prepended\.fasta$/} readdir($input_dh);
            close($input_dh);
        }
        else
        {
            opendir(my $input_dh, $input_dir) or die "Could not open $input_dir: $!";
            $file_dir = $input_dir;
            @files = grep {/fasta$/} readdir($input_dh);
            close($input_dh);
        }
    
        $strain_count = scalar(@files);
    
        print "\tBuilding single multi-fasta file $all_input_file ...\n";
        open(my $out_fh, '>', "$all_input_file") or die "Could not open file $all_input_file: $!";
        foreach my $file (@files)
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
