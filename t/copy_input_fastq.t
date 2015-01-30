#!/bin/usr/env perl
use warnings;
use strict;

use FindBin;
use lib $FindBin::Bin.'/../lib';
use Test::More;
use Test::Exception;
use Stage::CopyInputFastq;
use JobProperties;
use Logger;
use File::Temp 'tempdir';
use Getopt::Long;

#tests that CopyInputFastq.pm is correctly verifying that the input fastq and reference fasta have unique basenames.

my $tmp_dir;
my $keep_tmp;
my $script_dir = $FindBin::Bin;
if (not GetOptions('t|tmp-dir=s' => \$tmp_dir,'k|keep-tmp' => \$keep_tmp))
{
        die "Error: No tmp-dir indicated.";
}

$keep_tmp = 0 if (not defined $keep_tmp);

my $job_out = tempdir('copy_input_fastqXXXXXX', CLEANUP => (not $keep_tmp), DIR => $tmp_dir) or die "Could not create temp directory";
my $logger = Logger->new("$job_out");
my $properties = JobProperties->new($tmp_dir);
my $testObject = Stage::CopyInputFastq->new($properties, $logger);

#a list of fake input fastq files that should throw an error with verify_unique_file_names
my @fastqFail = ['home/this.fastq', 'home/that.fastq', 'home/other.fastq'];
dies_ok{$testObject->verify_unique_file_names(@fastqFail, 'home/this.fasta')} 'Duplicate file names are recognized and an error is thrown.'."\n";

#test that should pass
my @fastqPass = ['home/path/this.fastq', 'home/path/that.fastq', 'home/path/other.fastq'];
ok($testObject->verify_unique_file_names(@fastqPass, '/home/path/reference.fasta'), "Valid input file names are allowed."."\n");

done_testing();