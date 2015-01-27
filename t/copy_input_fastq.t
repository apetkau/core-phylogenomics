#!/bin/usr/env perl
use warnings;
use strict;

use lib '/Warehouse/Users/csieffert/core-phylogenomics/lib';
use lib '/Warehouse/Users/csieffert/core-phylogenomics/lib/Stage';
use Test::More;
use Test::Exception;
use Stage::CopyInputFastq;
use JobProperties;
use Logger;

#tests that CopyInputFastq.pm is correctly verifying that the input fastq and reference fasta have unique basenames.

my $logger = Logger->new('.');
my $properties = JobProperties->new('/Warehouse/Users/csieffert/core-phylogenomics/t');
my $testObject = Stage::CopyInputFastq->new($properties, $logger);

#a list of fake input fastq files that should throw an error with verify_unique_file_names
my @fastqFail = ['home/this.fastq', 'home/that.fastq', 'home/other.fastq'];
dies_ok{$testObject->verify_unique_file_names(@fastqFail, 'home/this.fasta')} 'Duplicate file names are recognized and an error is thrown.'."\n";

#test that should pass
my @fastqPass = ['home/path/this.fastq', 'home/path/that.fastq', 'home/path/other.fastq'];
ok($testObject->verify_unique_file_names(@fastqPass, '/home/path/reference.fasta'), "Valid input file names are allowed."."\n");

done_testing();