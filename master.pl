#!/usr/bin/perl

use strict;
use warnings;

use FindBin;

use File::Basename qw(basename);
use File::Copy qw(copy);
use Getopt::Long;

my $script_dir = $FindBin::Bin;

my $verbose = 0;

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
    my ($input_file, $split_number, $output_dir) = @_;

    my $split_log = "$output_dir/split.log";

    my $command = "perl $script_dir/split.pl \"$input_file\" \"$split_number\" \"$output_dir\" 1> \"$split_log\" 2> \"$split_log\"";

    die "input file: $input_file does not exist" if (not -e $input_file);
    die "output directory: $output_dir does not exist" if (not -e $output_dir);

    print "\tSplitting $input_file into $split_number pieces ...\n";
    print "\t\t$command\n" if ($verbose);
    print "\t\tSee $split_log for more information.\n";
    system($command) == 0 or die "Error for command $command: $!";

    return "$output_dir/".basename($input_file);
}

# returns database file path, bioperl index path
sub create_input_database
{
    my ($input_file,$database_output) = @_;

    my $input_fasta_path = "$database_output/".basename($input_file);
    my $formatdb_log = "$database_output/formatdb.log";

    die "Input file $input_file does not exist" if (not -e $input_file);
    die "Output directory: $database_output does not exist" if (not -e $database_output);

    print "\tChecking for features in $input_file with duplicate ids...\n";

    # Gives the number of features in input fasta file with duplicate ids
    my $check_unique_ids_command = "grep --only-match --no-filename '^>\\S*' \"$input_file\" | sort | uniq --count | grep --invert-match '^[ ^I]*1[ ^I]>' | wc -l";

    print "\t$check_unique_ids_command\n" if ($verbose);
    my $duplicate_count = `$check_unique_ids_command`;
    chomp $duplicate_count;

    print "\t\tDuplicate ids: $duplicate_count\n" if ($verbose);
    print "\t...done\n";

    die "Error: duplicate ids found in input fasta $input_file\n" if ($duplicate_count > 0);

    copy($input_file, $input_fasta_path)
      or die "Could not copy $input_file to $input_fasta_path: $!";

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

    return ($input_fasta_path, "$input_fasta_path.idx");
}

sub print_sge_script
{
    my ($processors, $script_path, $command) = @_;

    open(my $sge_fh, '>', $script_path) or die "Could not open $script_path for writing";
    print $sge_fh "#!/bin/sh\n";
    print $sge_fh "#\$ -t 1-$processors\n";
    print $sge_fh $command;
    close($sge_fh);
}

sub get_job_id
{
    return sprintf "j%08x", time;
}

# return blast output base path
sub perform_blast
{
    my ($input_task_base, $output_dir, $processors, $database) = @_;

    die "Input files $input_task_base.x do not exist" if (not -e "$input_task_base.1");
    die "Output directory $output_dir does not exist" if (not -e $output_dir);
    die "Database $database does not exist" if (not -e $database);

    my $output_task_base = basename($input_task_base).".out"; 
    my $output_task_path_base = "$output_dir/$output_task_base";
    my $job_name = get_job_id;

    my $blast_sge = "$output_dir/blast.sge";
    print "\tWriting $blast_sge script ...\n";
    my $sge_command = "blastall -p blastn -i \"$input_task_base.\$SGE_TASK_ID\" -o \"$output_task_path_base.\$SGE_TASK_ID\" -d \"$database\"\n";
    print_sge_script($processors, $blast_sge, $sge_command);
    print "\t...done\n";

    my $submission_command = "qsub -N $job_name -cwd -S /bin/sh -e /dev/null -o /dev/null \"$blast_sge\"";
    print "\tSubmitting $blast_sge for execution ...\n";
    print "\tRun 'watch -n1 qstat' for status\n";
    print "\t\t$submission_command\n" if ($verbose);
    system($submission_command) == 0 or die "Error submitting $submission_command: $!\n";
    print "\t\tWaiting for completion of blast job array $job_name";
    wait_until_completion($job_name);
    print "done\n";

    return $output_task_path_base;
}

sub perform_id_snps
{
    my ($blast_input_base, $snps_output, $bioperl_index, $processors, $strain_count, $pid_cutoff, $hsp_length) = @_;

    die "Input files $blast_input_base.x do not exist" if (not -e "$blast_input_base.1");
    die "Output directory $snps_output does not exist" if (not -e $snps_output);
    die "Bioperl index $bioperl_index does not exist" if (not -e $bioperl_index);
    die "Strain count is invalid" if (not defined ($strain_count) or $strain_count <= 0);
    die "Pid cutoff is invalid" if (not defined ($pid_cutoff) or $pid_cutoff <= 0 or $pid_cutoff > 100);
    die "HSP length is invalid" if (not defined ($hsp_length) or $hsp_length <= 0);

    my $core_sge = "$snps_output/core.sge";
    print "\tWriting $core_sge script ...\n";
    my $sge_command = "$script_dir/coresnp2.pl \"$blast_input_base.\$SGE_TASK_ID\" \"$bioperl_index\" $strain_count $pid_cutoff $hsp_length \"$snps_output\"\n";
    print_sge_script($processors, $core_sge, $sge_command);
    print "\t...done\n";

    my $job_name = get_job_id;

    my $submission_command = "qsub -N $job_name -cwd -S /bin/sh -e /dev/null -o /dev/null \"$core_sge\"";
    print "\tSubmitting $core_sge for execution ...\n";
    print "\tRun 'watch -n1 qstat' for status\n";
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

    my $count_command = "ls -l \"$snps_output/*\" | wc -l";
    my $count = undef;
    print "\tCounting SNP files...\n";
    print "\t\t$count_command\n" if ($verbose);
    $count = `$count_command`;
    print "\t...done\n";

    return $count;
}

sub usage
{
    print "Usage: ".basename($0)." [Options]\n\n";
    print "Options:\n";
    print "\t-c|--strain-count:  The number of strains we are working with.\n";
    print "\t-i|--input-fasta:  The input fasta file.\n";
    print "\t-p|--processors:  The number of processors to use.\n";
    print "\t-s|--split-file:  The file to use for initial split.\n";
    print "\t-v|--verbose:  Print extra information.\n";
    print "\t-h|--help:  Print help.\n";
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

my $processors = 1;
my $split_file = "";
my $input_fasta = "";
my $strain_count = 0;

if (!GetOptions(
    'p|processors=i' => \$processors_opt,
    's|split-file=s' => \$split_file_opt,
    'i|input-fasta=s' => \$input_fasta_opt,
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

if (defined $verbose_opt and $verbose_opt)
{
    $verbose = $verbose_opt;
}

my $pid_cutoff = 99;
my $hsp_length = 400;

my $database_file;
my $bioperl_index;
my $split_base_path;
my $blast_base_path;

my $job_id = time;
my $root_data_dir = "$script_dir/data";

my $job_dir = "$root_data_dir/$job_id";

my $database_output = "$job_dir/database";
my $split_output = "$job_dir/split";
my $blast_output = "$job_dir/blast";
my $core_snp_output = "$job_dir/core";

print "Running core SNP phylogenomic pipeline.  Storing all data under $job_dir\n";
mkdir ($root_data_dir) if (not -e $root_data_dir);
mkdir $job_dir if (not -e $job_dir);

print "Creating initial databases ...\n";
mkdir $database_output if (not -e $database_output);
($database_file, $bioperl_index) = create_input_database($input_fasta, $database_output);
print "...done\n";

print "Performing split ...\n";
mkdir "$split_output" if (not -e $split_output);
$split_base_path = perform_split($split_file, $processors, $split_output);
print "...done\n";

print "Performing blast ...\n";
mkdir "$blast_output" if (not -e $blast_output);
$blast_base_path = perform_blast($split_base_path, $blast_output, $processors, $database_file);
print "...done\n";

print "Performing core genome SNP identification ...\n";
mkdir "$core_snp_output" if (not -e $core_snp_output);
perform_id_snps($blast_base_path, $core_snp_output, $bioperl_index, $processors, $strain_count, $pid_cutoff, $hsp_length);
print "...done\n";
