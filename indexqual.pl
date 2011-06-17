#!/usr/bin/perl
 
use strict;
use lib ("/opt/rocks/lib/perl5/site_perl/5.10.1");

use lib qw(..);
use Bio::Index::Qual;
use Bio::SeqIO;
use strict;
use Data::Dumper;
die "usage: index.pl <filename> " unless @ARGV;
 my $file_name = shift @ARGV; 
my $test_acc = shift @ARGV;
  my $inx = Bio::Index::Qual->new( -filename   => $file_name . ".idx",
                                    -write_flag => 1);
  # pass a reference to the critical function to the Bio::Index object
  # make the index
$inx->make_index($file_name);
my $seq = $inx->fetch($test_acc) if $test_acc;
use Data::Dumper; print Dumper \$seq if $seq;
