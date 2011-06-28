#!/usr/bin/perl

use strict;
use warnings;

use FindBin;

use File::Basename qw(basename dirname);
use File::Copy qw(copy move);
use File::Path qw(rmtree);
use Getopt::Long;

my $script_dir = $FindBin::Bin;

my $verbose = 0;
my $keep_files = 0;

my $pid_cutoff_default = 99;
my $hsp_length_default = 400;

sub check_job_queue_for
{
    my ($job_name) = @_;

    my @qstat = `qstat`;
    my $qstat = join "",@qstat;

    return ($qstat =~ /$job_name/);
}

sub wait_until_completion
{
    my ($job_name) = @_;

    my $completed = 0;
    while (not $completed)
    {
        sleep 10;
        print ".";
        $completed = not check_job_queue_for($job_name);
    }
}

# returns split file base path
sub perform_split
{
    my ($input_file, $split_number, $output_dir, $log_dir) = @_;

    my $split_log = "$log_dir/split.log";

    my $command = "perl $script_dir/split.pl \"$input_file\" \"$split_number\" \"$output_dir\" 1> \"$split_log\" 2> \"$split_log\"";

    die "input file: $input_file does not exist" if (not -e $input_file);
    die "output directory: $output_dir does not exist" if (not -e $output_dir);

    print "\tSplitting $input_file into $split_number pieces ...\n";
    print "\t\t$command\n" if ($verbose);
    print "\t\tSee $split_log for more information.\n";
    system($command) == 0 or die "Error for command $command: $!";
}

# Counts duplicate ids for genes in fasta formatted files
# Input:  $input_file  If file is regular file, counts only in file.
#          if file is directory, counts all files in directory
sub duplicate_count
{
    my ($input_file) = @_;

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

    print "$duplicate_count_command\n" if ($verbose);

    my $duplicate_count = `$duplicate_count_command`;
    chomp $duplicate_count;

    die "Error in duplicate id command, output \"$duplicate_count\" not a number" if ($duplicate_count !~ /^\d+$/);

    return $duplicate_count;
}

# returns database file path, bioperl index path
sub create_input_database
{
    my ($input_file,$database_output,$log_dir,$new_input_fasta) = @_;

    my $formatdb_log = "$log_dir/formatdb.log";

    die "Input file $input_file does not exist" if (not -e $input_file);
    die "Output directory: $database_output does not exist" if (not -e $database_output);

    print "\tChecking for features in $input_file with duplicate ids...\n";
    my $duplicate_count = duplicate_count($input_file);
    print "\t\tDuplicate ids: $duplicate_count\n" if ($verbose);
    print "\t...done\n";

    die "Error: duplicate ids found in input fasta $input_file\n" if ($duplicate_count > 0);

    copy($input_file, $new_input_fasta)
      or die "Could not copy $input_file to $new_input_fasta: $!";

    my $formatdb_command = "formatdb -i \"$new_input_fasta\" -p F -l \"$formatdb_log\"";
    my $index_command = "perl \"$script_dir/index.pl\" \"$new_input_fasta\"";

    print "\tCreating BLAST formatted database ...\n";
    print "\t\t$formatdb_command\n" if ($verbose);
    system($formatdb_command) == 0 or die "Error for command: $formatdb_command: $!";
    print "\t...done\n";

    print "\tCreating bioperl index ...\n";
    print "\t\t$index_command\n" if ($verbose);
    system($index_command) == 0 or die "Error for command: $index_command: $!";
    print "\t...done\n";
}

sub print_sge_script
{
    my ($processors, $script_path, $command) = @_;

    open(my $sge_fh, '>', $script_path) or die "Could not open $script_path for writing";
    print $sge_fh "#!/bin/sh\n";
    print $sge_fh "#\$ -t 1-$processors\n";
    print $sge_fh $command;
    print $sge_fh "\n";
    close($sge_fh);
}

sub get_job_id
{
    return sprintf "x%08x", time;
}

# return blast output base path
sub perform_blast
{
    my ($input_task_base, $output_dir, $processors, $database,$log_dir,$blast_task_base) = @_;

    die "Input files $input_task_base.x do not exist" if (not -e "$input_task_base.1");
    die "Output directory $output_dir does not exist" if (not -e $output_dir);
    die "Database $database does not exist" if (not -e $database);

    my $job_name = get_job_id;

    my $blast_sge = "$output_dir/blast.sge";
    print "\tWriting $blast_sge script ...\n";
    my $sge_command = "blastall -p blastn -i \"$input_task_base.\$SGE_TASK_ID\" -o \"$blast_task_base.\$SGE_TASK_ID\" -d \"$database\"\n";
    print_sge_script($processors, $blast_sge, $sge_command);
    print "\t...done\n";

    my $error = "$log_dir/blast.error.sge";
    my $out = "$log_dir/blast.out.sge";
    my $submission_command = "qsub -N $job_name -cwd -S /bin/sh -e \"$error\" -o \"$out\" \"$blast_sge\" 1>/dev/null";
    print "\tSubmitting $blast_sge for execution ...\n";
    print "\t\tSee ($out) and ($error) for details.\n";
    print "\t\t$submission_command\n" if ($verbose);
    system($submission_command) == 0 or die "Error submitting $submission_command: $!\n";
    print "\t\tWaiting for completion of blast job array $job_name";
    wait_until_completion($job_name);
    print "done\n";
}

sub perform_id_snps
{
    my ($blast_input_base, $snps_output, $bioperl_index, $processors,
        $strain_count, $pid_cutoff, $hsp_length,$log_dir,$core_snp_base) = @_;

    die "Input files $blast_input_base.x do not exist" if (not -e "$blast_input_base.1");
    die "Output directory $snps_output does not exist" if (not -e $snps_output);
    die "Bioperl index $bioperl_index does not exist" if (not -e $bioperl_index);
    die "Strain count is invalid" if (not defined ($strain_count) or $strain_count <= 0);
    die "Pid cutoff is invalid" if (not defined ($pid_cutoff) or $pid_cutoff <= 0 or $pid_cutoff > 100);
    die "HSP length is invalid" if (not defined ($hsp_length) or $hsp_length <= 0);

    my $core_snp_base_path = "$snps_output/$core_snp_base";

    my $core_sge = "$snps_output/core.sge";
    print "\tWriting $core_sge script ...\n";
    my $sge_command = "$script_dir/coresnp2.pl \"$blast_input_base.\$SGE_TASK_ID\" \"$bioperl_index\" $strain_count $pid_cutoff $hsp_length \"$snps_output\"\n";
    print_sge_script($processors, $core_sge, $sge_command);
    print "\t...done\n";

    my $job_name = get_job_id;

    my $error = "$log_dir/core.error.sge";
    my $out = "$log_dir/core.out.sge";
    my $submission_command = "qsub -N $job_name -cwd -S /bin/sh -e \"$error\" -o \"$out\" \"$core_sge\" 1>/dev/null";
    print "\tSubmitting $core_sge for execution ...\n";
    print "\t\tSee ($out) and ($error) for details.\n";
    print "\t\t$submission_command\n" if ($verbose);
    system($submission_command) == 0 or die "Error submitting $submission_command: $!\n";
    print "\t\tWaiting for completion of core sge job array $job_name";
    wait_until_completion($job_name);
    print "done\n";

    my $rename_command = "perl $script_dir/rename.pl \"$snps_output\" \"$snps_output\"";
    print "\tRenaming SNP output files...\n";
    print "\t\t$rename_command\n" if ($verbose);
    system($rename_command) == 0 or die "Error renaming snp files: $!";
    print "\t...done\n";

}

sub count_snps
{
    my ($core_snp_base_path) = @_;

    my $count_command = "ls -1 \"$core_snp_base_path\"* | wc -l";
    my $count = undef;
    print "\t$count_command\n" if ($verbose);
    $count = `$count_command`;
    die "\tError counting snp files" if (not defined $count);
    die "\tError counting snp files, $count not a number" if ($count !~ /^\d+$/);
    die "\tError counting snp files, $count <= 0" if ($count <= 0);

    return $count;
}

sub align_orthologs
{
    my ($input_task_base, $output_dir, $snp_count, $log_dir) = @_;

    die "Input files ${input_task_base}x do not exist" if (not -e "${input_task_base}1");
    die "Output directory $output_dir does not exist" if (not -e $output_dir);
    die "SNP count is invalid" if (not defined $snp_count or $snp_count <= 0);

    my $input_dir = dirname($input_task_base);

    my $job_name = get_job_id;

    my $clustalw_sge = "$output_dir/clustalw.sge";
    print "\tWriting $clustalw_sge script ...\n";
    my $sge_command = "clustalw2 -infile=${input_task_base}\$SGE_TASK_ID";
    print_sge_script($snp_count, $clustalw_sge, $sge_command);
    print "\t...done\n";

    my $error = "$log_dir/clustalw.error.sge";
    my $out = "$log_dir/clustalw.out.sge";
    my $submission_command = "qsub -N $job_name -cwd -S /bin/sh -e \"$error\" -o \"$out\" \"$clustalw_sge\" 1>/dev/null";
    print "\tSubmitting $clustalw_sge for execution ...\n";
    print "\t\tSee ($out) and ($error) for details.\n";
    print "\t\t$submission_command\n" if ($verbose);
    system($submission_command) == 0 or die "Error submitting $submission_command: $!\n";
    print "\t\tWaiting for completion of clustalw job array $job_name";
    wait_until_completion($job_name);
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
    my $trim_command = "$script_dir/trim.pl \"$output_dir\" \"$output_dir\" 1>\"$log\" 2>\"$log\"";
    print "\tTrimming alignments (see $log for details) ...\n";
    print "\t\t$trim_command\n" if ($verbose);
    system($trim_command) == 0 or die "Error trimming alignments: $!\n";
    print "\t...done\n";
}

sub pseudoalign
{
    my ($align_input, $output_dir, $log_dir) = @_;

    die "Error: align_input directory does not exist" if (not -e $align_input);
    die "Error: pseudoalign output directory does not exist" if (not -e $output_dir);

    my $log = "$log_dir/pseudoaligner.log";

    my $pseudoalign_command = "perl $script_dir/pseudoaligner.pl \"$align_input\" \"$output_dir\" 1>\"$log\" 2>\"$log\"";
    print "\tRunning pseudoaligner (see $log for details) ...\n";
    print "\t\t$pseudoalign_command\n" if ($verbose);
    system($pseudoalign_command) == 0 or die "Error running pseudoaligner: $!";
    print "\t...done\n";
}

# returns main input file and count of strains
sub build_input_fasta
{
    my ($input_dir, $output_dir) = @_;

    die "Input directory is invalid" if (not -d $input_dir);
    die "Output directory is invalid" if (not -d $output_dir);

    my $prepended = 0;

    print "\tChecking for unique genes...\n";
    my $count = duplicate_count($input_dir);
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
            my $uniquify_command = "sed \"s/>/>$file\|/\" \"$input_path\" > \"$output_path\"";
            print "\t\t$uniquify_command\n" if ($verbose);
            system($uniquify_command) == 0 or die "Error attempting to create unique gene ids: $!";
        }

        print "\t\t...done\n";
    }
    print "\t...done\n";

    my $main_input_file = "$output_dir/all.fasta";
    my $strain_count = 0;

    my @files;
    if ($prepended)
    {
        opendir(my $input_dh, $output_dir) or die "Could not open $output_dir: $!";
        @files = grep {/prepended\.fasta$/} readdir($input_dh);
        close($input_dh);
    }
    else
    {
        opendir(my $input_dh, $input_dir) or die "Could not open $input_dir: $!";
        @files = grep {/fasta$/} readdir($input_dh);
        close($input_dh);
    }

    $strain_count = scalar(@files);

    my $cat_command = "cat ";
    foreach my $file (@files)
    {
        if ($prepended)
        {
            $cat_command .= "\"$output_dir/$file\" ";
        }
        else
        {
            $cat_command .= "\"$input_dir/$file\" ";
        }
    }
    $cat_command .= " 1> $main_input_file";

    print "\tBuilding single multi-fasta file $main_input_file ...\n";
    print "\t\t$cat_command\n" if ($verbose);
    system($cat_command) == 0 or die "Could not build single multi-fasta file: $!";
    print "\t...done\n";

    return ($main_input_file,$strain_count);
}

sub usage
{
    print "Usage: ".basename($0)." [Options]\n\n";
    print "Options:\n";
    print "\t-c|--strain-count [integer]:  The number of strains we are working with.\n";
    print "\t-d|--input-diri [directory]:  The directory containing the input fasta files.\n";
    print "\t-h|--help:  Print help.\n";
    print "\t-i|--input-fasta [file]:  The input fasta file.\n";
    print "\t-k|--keep-files:  Keep intermediate files around.\n";
    print "\t-o|--output [directory]:  The directory to store output (optional).\n";
    print "\t-p|--processors [integer]:  The number of processors to use.\n";
    print "\t--pid-cutoff [real]:  The pid cutoff to use (default $pid_cutoff_default).\n";
    print "\t--hsp-length [integer]:   The hsp length to use (default $hsp_length_default).\n";
    print "\t-s|--split-file [file]:  The file to use for initial split.\n";
    print "\t-v|--verbose:  Print extra information.\n";

    print "\nExample:\n";
    print "\tmaster.pl --processors 480 --input-dir sample/ --split-file sample/ECO111.fasta --output data --keep-files\n";
    print "\tRuns master.pl on data under sample/ with the passed split file and processors.\n\n";
}

############
##  MAIN  ##
############

my $verbose_opt;
my $processors_opt;
my $split_file_opt;
my $input_fasta_opt;
my $help_opt;
my $strain_count_opt;
my $input_dir_opt;
my $keep_files_opt;
my $output_opt;
my $pid_cutoff_opt;
my $hsp_length_opt;

my $processors = undef;
my $split_file = undef;
my $input_fasta = undef;
my $input_dir = undef;
my $strain_count = undef;
my $output_dir = undef;
my $pid_cutoff = $pid_cutoff_default;
my $hsp_length = $hsp_length_default;

if (!GetOptions(
    'p|processors=i' => \$processors_opt,
    's|split-file=s' => \$split_file_opt,
    'd|input-dir=s' => \$input_dir_opt,
    'o|output=s' => \$output_opt,
    'i|input-fasta=s' => \$input_fasta_opt,
    'k|keep-files' => \$keep_files_opt,
    'pid-cutoff=f' => \$pid_cutoff_opt,
    'hsp-length=i' => \$hsp_length_opt,
    'v|verbose' => \$verbose_opt,
    'h|help' => \$help_opt,
    'c|strain-count=i' => \$strain_count_opt))
{
    usage;
    die "$!";
}

if (defined $help_opt and $help_opt)
{
    usage;
    exit 0;
}

if (not defined $processors_opt)
{
    print STDERR "Must specify number of processors\n";
    usage;
    exit 1;
}
else
{
   $processors = $processors_opt; 
}

if (not defined $split_file_opt)
{
    print STDERR "Must specify an initial split file\n";
    usage;
    exit 1;
}
elsif (not -e $split_file_opt)
{
    print STDERR "Error: split file $split_file_opt does not exist\n";
    usage;
    exit 1;
}
else
{
    $split_file = $split_file_opt;
}

if (defined $keep_files_opt and $keep_files_opt)
{
    $keep_files = 1;
}

if (defined $input_dir_opt)
{
    if (not -d $input_dir_opt)
    {
        print STDERR "Error: input fasta directory $input_dir_opt is not a directory\n";
        usage;
        exit 1;
    }
    else
    {
        $input_dir = $input_dir_opt;

        if (defined $strain_count_opt)
        {
            if ($strain_count_opt <= 0)
            {
                print STDERR "Error: strain count $strain_count_opt must be positive\n";
                usage;
                exit 1;
            }
            else
            {
                $strain_count = $strain_count_opt;
            }
        }
    }
}
else
{
    if (not defined $input_fasta_opt)
    {
        print STDERR "Error: input fasta file must be defined\n";
        usage;
        exit 1;
    }
    elsif (not -e $input_fasta_opt)
    {
        print STDERR "Error: input fasta file $input_fasta_opt does not exist\n";
        usage;
        exit 1;
    }
    else
    {
        $input_fasta = $input_fasta_opt;
    }
    
    if (not defined $strain_count_opt)
    {
        print STDERR "Error: strain count must be defined\n";
        usage;
        exit 1;
    }
    elsif ($strain_count_opt <= 0)
    {
        print STDERR "Error: strain count $strain_count_opt must be positive\n";
        usage;
        exit 1;
    }
    else
    {
        $strain_count = $strain_count_opt;
    }
}

if (defined $output_opt)
{
    if (-e $output_opt)
    {
        print "Warning: directory \"$output_opt\" already exists, are you sure you want to store data here [Y]? ";
        my $response = <>;
        chomp $response;
        if ($response eq 'y' or $response eq 'Y' or $response eq '')
        {
            $output_dir = $output_opt;
        }
        else
        {
            die "Directory \"$output_opt\" already exists, could not continue.";
        }
    }
    else
    {
        $output_dir = $output_opt;
    }
}
else
{
    $output_dir = sprintf "%08x",time;
}

if (defined $pid_cutoff_opt)
{
    if ($pid_cutoff_opt !~ /^\d+$/)
    {
        print STDERR "pid-cutoff value $pid_cutoff_opt is invalid\n";
        usage;
        exit 1;
    }
    elsif ($pid_cutoff_opt < 0 or $pid_cutoff_opt > 100)
    {
        print STDERR "pid-cutoff value $pid_cutoff_opt must be in [0,100]\n";
        usage;
        exit 1;
    }
    else
    {
        $pid_cutoff = $pid_cutoff_opt;
    }
}

if (defined $hsp_length_opt)
{
    if ($hsp_length_opt !~ /^\d+$/)
    {
        print STDERR "hsp-length value $hsp_length_opt is invalid\n";
        usage;
        exit 1;
    }
    elsif ($hsp_length_opt < 0)
    {
        print STDERR "hsp-length value $hsp_length_opt must be > 0\n";
        usage;
        exit 1;
    }
    else
    {
        $hsp_length = $hsp_length_opt;
    }
}

if (defined $verbose_opt and $verbose_opt)
{
    $verbose = $verbose_opt;
}

my $database_file;
my $bioperl_index;
my $split_base_path;
my $blast_base_path;
my $core_snp_base_path;

my $job_dir = "$output_dir";

my $log_dir = "$job_dir/log";
my $fasta_output = "$job_dir/fasta";
my $database_output = "$job_dir/database";
my $split_output = "$job_dir/split";
my $blast_output = "$job_dir/blast";
my $core_snp_output = "$job_dir/core";
my $align_output = "$job_dir/align";
my $pseudoalign_output = "$job_dir/pseudoalign";

my $snps_count;

print "Running core SNP phylogenomic pipeline.\n";

if ($verbose)
{
    print "\nProperties:\n";
    print "pid-cutoff: $pid_cutoff\n";
    print "hsp-length: $hsp_length\n";
    print "input-dir: $input_dir\n" if (defined $input_dir);
    print "input-fasta: $input_fasta\n" if (defined $input_fasta);
    print "output: $job_dir\n";
    print "keep-files: ".($keep_files?'true':'false')."\n";
    print "verbose: ".($verbose?'true':'false')."\n";
    print "split-file: $split_file\n";
    print "strain-count: ".(defined $strain_count?$strain_count:'auto')."\n";
    print "processors: $processors\n\n";
}

print "Storing all data under $job_dir\n";
mkdir $job_dir if (not -e $job_dir);
mkdir $log_dir if (not -e $log_dir);

if (defined $input_dir)
{
    mkdir ($fasta_output) if (not -e $fasta_output);

    print "Preparing files under $input_dir ...\n";
    print "We assume all files under $input_dir are fasta-formatted and should be included in pipeline\n";
    my ($input_fasta_auto, $strain_count_auto) = build_input_fasta($input_dir,$fasta_output);
    print "...done\n";

    die "Error creating input fasta file" if (not -e $input_fasta_auto);
    die "Error getting strain count" if (not defined $strain_count_auto or $strain_count_auto !~ /\d+/);

    $input_fasta = $input_fasta_auto;

    # only set to auto-value if not already set
    $strain_count = $strain_count_auto if (not defined $strain_count);
}

print "Creating initial databases ...\n";
mkdir $database_output if (not -e $database_output);
$database_file = "$database_output/".basename($input_fasta);
$bioperl_index = "$database_file.idx";
create_input_database($input_fasta, $database_output, $log_dir,$database_file);
print "...done\n";

print "Performing split ...\n";
mkdir "$split_output" if (not -e $split_output);
$split_base_path = "$split_output/".basename($split_file);
perform_split($split_file, $processors, $split_output, $log_dir);
print "...done\n";

if (not $keep_files)
{
    if (defined $input_dir)
    {
        print "Cleaning $fasta_output\n" if ($verbose);
        rmtree($fasta_output) or die "Error: could not delete $fasta_output";
    }
}

print "Performing blast ...\n";
mkdir "$blast_output" if (not -e $blast_output);
$blast_base_path = "$blast_output/".basename($split_base_path).".out";
perform_blast($split_base_path, $blast_output, $processors, $database_file,$log_dir,$blast_base_path);
print "...done\n";

print "Performing core genome SNP identification ...\n";
mkdir "$core_snp_output" if (not -e $core_snp_output);
my $core_snp_base = "snps";
$core_snp_base_path = "$core_snp_output/$core_snp_base";
perform_id_snps($blast_base_path, $core_snp_output, $bioperl_index, $processors, $strain_count, $pid_cutoff, $hsp_length,$log_dir,$core_snp_base);
print "...done\n";

print "Counting SNP files...\n";
$snps_count = count_snps($core_snp_base_path);
print "...done\n";

if (not $keep_files)
{
    print "Cleaning $database_output\n" if ($verbose);
    rmtree($database_output) or die "Error: could not delete $database_output";

    print "Cleaning $split_output\n" if ($verbose);
    rmtree($split_output) or die "Error: could not delete $split_output";

    print "Cleaning $blast_output\n" if ($verbose);
    rmtree($blast_output) or die "Error: could not delete $blast_output";
}

print "Performing multiple alignment of orthologs ...\n";
mkdir $align_output if (not -e $align_output);
align_orthologs($core_snp_base_path, $align_output, $snps_count,$log_dir);
print "...done\n";

if (not $keep_files)
{
    print "Cleaning $core_snp_output\n" if ($verbose);
    rmtree($core_snp_output) or die "Error: could not delete $core_snp_output";
}

print "Creating pseudoalignment ...\n";
mkdir $pseudoalign_output if (not -e $pseudoalign_output);
pseudoalign($align_output, $pseudoalign_output,$log_dir);
print "...done\n";

if (not $keep_files)
{
    print "Cleaning $align_output\n" if ($verbose);
    rmtree($align_output) or die "Error: could not delete $align_output";
}

print "\n\nPseudoalignment and snp report generated.\n";
print "Files can be found in $pseudoalign_output\n";

=pod

=head1 NAME

master.pl:  Script to automate running of core SNP analysis.

=head1 DESCRIPTION

Runs the core SNP phylogenomic analysis stages.  The input is either a directory containing the FASTA files to analyize, or the multi-fasta file to analyze.  The output is the pseudoalign.phy alignment file and the snpreport.txt. The intermediate files are kept under a directory (named using --output), and are by default cleaned out after they aren't needed (they can be kept using --keep-files).

=head1 INPUT

Input is in two forms, either a directory containing the fasta files to analyze, or a single multi-fasta file.

=head2 FASTA Directory

Use B<--input-dir [name]> to define the fasta input directory.  The input files will be checked to see if all gene names are unique, and we will attempt to create unique names if this is not the case.  The count of the files in this directory will be used for the strain count (can be overridden with B<--strain-count>).

=head2 Multi-FASTA

Use B<--input-fasta [name]> to pass a multi-fasta formatted file containing all the strains to analyze.  The file will be checked for unique strain ids, and will fail if this is not the case.  This input option also requires passing the count of the number of strains B<--strain-count>.

=head1 OUTPUT

Use B<--output [OUT_NAME]> to define an output directory, otherwise a directory will be created for you.  The output directory must be accessible by the cluster nodes.  Files for each stage will be written under the output directory.  In addition, a log/ directory will be written with log files for each stage.  The final results will be available under OUT_NAME/pseudoalign.

=head1 REQUIRED

=over 8

=item B<--input-dir [directory]> or B<--input-fasta [file]>:  The input file or directory to process.

=item B<--strain-count [integer]> (optional if --input-dir is used):  The count of the number of strains we are processing.

=item B<--processors [integer]>:  The number of processors we will run the SGE jobs with.

=item B<--split-file [file]>:  The initial fasta file we split apart to run the SGE jobs with.

=back

=head1 OPTIONAL

=over 8

=item B<--output [directory]>:  The directory to store the analysis files under.

=item B<--keep-files>:  If set will keep intermediate files in analysis.

=item B<--verbose>:  Print more information.

=item B<--pid-cutoff [real]>:  The pid cutoff to use.

=item B<--hsp-length [integer]>:  The hsp length to use.

=back

=head1 DEPENDENCIES

This script assumes you are running on a cluster environment.  Standard batch-queuing tools must be installed (qstat, qsub, etc).  As well, blast, clustalw, and BioPerl must be installed.

=head1 EXAMPLE

=over 1

=item master.pl --processors 480 --input-dir sample/ --split-file sample/ECO111.fasta --output data --keep-files

=back

This example will run the analysis on all fasta files under sample/, using sample/ECO111.fasta as the split file, and data/ as the directory to place all analysis files.  We will run the job using 480 processors on the cluster and keep all intermediate files around.

=head1 AUTHOR

Aaron Petkau - aaron.petkau@phac-aspc.gc.ca

Gary Van Domselaar - gary_van_domselaar@phac-aspc.gc.ca

=cut

1;
