#!/usr/bin/perl

use strict;
use warnings;

use FindBin;

use File::Basename qw(basename);
use File::Copy qw(copy);
use Getopt::Long;

my $script_dir = $FindBin::Bin;

my $verbose = 0;

my $database_output = "$script_dir/database";
my $split_output = "$script_dir/split";

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
}

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

    print "\t$check_unique_ids_command\n";
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
}

sub perform_blast
{
    my ($input_base, $output_dir, $processors, $database) = @_;
}

sub usage
{
    print "Usage: ".basename($0)." [Options]\n\n";
    print "Options:\n";
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

my $processors = 1;
my $split_file = "";
my $input_fasta = "";

if (!GetOptions(
    'p|processors=i' => \$processors_opt,
    's|split-file=s' => \$split_file_opt,
    'i|input-fasta=s' => \$input_fasta_opt,
    'v|verbose' => \$verbose_opt,
    'h|help' => \$help_opt))
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
    print STDERR "Error: split file $split_file_opt does not exist";
    usage;
    exit 1;
}
else
{
    $split_file = $split_file_opt;
}

if (not defined $input_fasta_opt)
{
    print STDERR "Error: input fasta file must be defined";
    usage;
    exit 1;
}
elsif (not -e $input_fasta_opt)
{
    print STDERR "Error: input fasta file $input_fasta_opt does not exist";
    usage;
    exit 1;
}
else
{
    $input_fasta = $input_fasta_opt;
}

if (defined $verbose_opt and $verbose_opt)
{
    $verbose = $verbose_opt;
}

print "Creating initial databases ...\n";
mkdir $database_output if (not -e $database_output);
create_input_database($input_fasta, $database_output);
print "...done\n";

print "Performing split ...\n";
mkdir "$split_output" if (not -e $split_output);
perform_split($split_file, $processors, $split_output);
print "...done\n";
