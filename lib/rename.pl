#!/usr/bin/env perl

package Rename;

use strict;

use Getopt::Long;
use Bio::SeqIO;
use Cwd;
use File::Copy;

__PACKAGE__->run() unless caller;

1;

sub usage
{
    print "Usage: rename.pl -i <input_dir> [-o <output_dir>]\n";
}

sub run
{
    my ($input_dir,$output_dir);

    if ( @_ && $_[0] eq __PACKAGE__)
    {
        GetOptions('i|input-dir=s' => \$input_dir,
                   'o|output-dir=s' => \$output_dir) or die "Invalid options\n".usage;
    }
    else
    {
        ($input_dir,$output_dir) = @_;
    }

    die "input-dir not defined\n".usage if (not defined $input_dir);
    die "input-dir $input_dir not a valid directory\n".usage if (not -e $input_dir);

    $output_dir = $input_dir if (not defined $output_dir);

    my $locus_map_path = (defined $output_dir) ? "$output_dir/locusmap.txt" : "locusmap.txt";
    
    my $x=1;
    opendir(my $input_dh, $input_dir) or die "Could not open directory $input_dir: $!";
    my @files = readdir($input_dh);
    closedir($input_dh);
    
    open LOCUSMAP, ">$locus_map_path" || die "foo!: $!\n";
    for my $file (@files) {
            if ($file =~ /^core.*\.ffn$/)
            {
    		my $full_file_path = "$input_dir/$file";
    		my $in = new Bio::SeqIO(-file=>"$full_file_path", -format=>"fasta");
    		my  @orfs;
    		while (my  $seq= $in->next_seq) {
    		my ($orf) = $seq->desc =~ /^(.*?)\s/;
    			push @orfs, $orf;
    		}
    		my  $orfs =  join " ", @orfs;
    		print LOCUSMAP "$x: $orfs\n";
    		my $newfilename = (defined $output_dir) ? "$output_dir/snps$x" : "snps$x";
    		copy($full_file_path, $newfilename) or die "Could not rename $full_file_path to $newfilename: $!";
    		$x++;
            }
    }
}

