#!/usr/bin/perl

use strict;
use warnings;

use FindBin;

use File::Basename qw(basename);
use Getopt::Long;

my $script_dir = $FindBin::Bin;

my $verbose = 0;

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
    system($command);
}

sub usage
{
    print "Usage: ".basename($0)." [Options]\n\n";
    print "Options:\n";
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
my $help_opt;

my $processors = 1;
my $split_file = "";

if (!GetOptions(
    'p|processors=i' => \$processors_opt,
    's|split-file=s' => \$split_file_opt,
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

if (defined $verbose_opt and $verbose_opt)
{
    $verbose = $verbose_opt;
}

print "Performing split ...\n";
mkdir "$split_output" if (not -e $split_output);
perform_split($split_file, $processors, $split_output);
print "...done\n";
