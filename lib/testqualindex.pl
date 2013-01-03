#!/usr/bin/env perl
 
use strict;

use Bio::Index::Fasta;
use Bio::SeqIO;
use strict;
use Data::Dumper;
die "usage: index.pl <filename> " unless @ARGV;
 my $file_name = shift @ARGV; 
my $test_acc = shift @ARGV;
  my $inx = Bio::Index::Fasta->new( -filename   => $file_name . ".idx",
                                    -write_flag => 1);
  # pass a reference to the critical function to the Bio::Index object
  # make the index
$inx->make_index($file_name);
$inx->fetch($test_acc) if $test_acc;
