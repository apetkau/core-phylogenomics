#!/usr/bin/perl
use strict;
use lib ("/opt/rocks/lib/perl5/site_perl/5.10.1");
use Bio::SeqIO;
use Cwd;
use File::Copy;

my $input_dir = shift;
my $output_dir = shift;

my $locus_map_path = (defined $output_dir) ? "$output_dir/locusmap.txt" : "locusmap.txt";

my $x=1;
$input_dir = '.' if (not defined $input_dir);
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
		move($full_file_path, $newfilename) or die "Could not rename $full_file_path to $newfilename: $!";
		$x++;
        }
}

