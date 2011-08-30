#!/usr/bin/perl

package Trim;

use strict;
use lib ("/opt/rocks/lib/perl5/site_perl/5.10.1");

use Getopt::Long;
use Bio::AlignIO;
use Bio::SimpleAlign;
use File::Copy;

__PACKAGE__->run() unless caller;

1;

sub usage
{
    print "Usage: trim.pl -i <input dir> [-o <output dir>] [-l <log file>]\n";
}

sub run
{
    my ($input_dir,$output_dir,$log_file);

    open(my $out_fh, '>-') or die "Could not open stdout for writing";

    if ( @_ && $_[0] eq __PACKAGE__)
    {
        GetOptions('i|input-dir=s' => \$input_dir,
                   'o|output-dir=s' => \$output_dir,
                   'l|log-file=s' => \$log_file) or die "Invalid options\n";
    }
    else
    {
        ($input_dir,$output_dir,$log_file) = @_;
    }

    if (defined $log_file)
    {
        open($out_fh, '>', $log_file) or die "Could not open $log_file: $!";
    }

    die "input-dir not defined\n".usage if (not defined $input_dir);
    die "input-dir $input_dir not a valid directory\n".usage if (not -e $input_dir);

    $output_dir = $input_dir if (not defined $output_dir);
    
    opendir (my $input_dh, $input_dir) or die "Could not open $input_dir: $!";
    my @ids = sort {$a <=> $b } map {/(\d+)/;$1} grep {/snps\d+\.aln/} readdir($input_dh);
    close($input_dh);
    
    locus: for my $locusid (@ids) {
    	my $alignfile = "$input_dir/snps" . $locusid . ".aln";
            my $alignfile_out = "$output_dir/snps${locusid}.aln.trimmed";
    	print $out_fh "$alignfile\n";
            my $in = Bio::AlignIO->new(-file =>$alignfile, -format=>"clustalw");
    	my $aln = $in->next_aln;
    
    	my @starts;
    	my @ends;
    	my $start;
    	my $end;
    	for my $seq ($aln->each_alphabetically) {
    		my $seqstr = $seq->seq;
    		$seqstr =~ /(^\-{0,}).*?(\-{0,}$)/;
    		push @starts, length ($1)+5;
    		push @ends, $seq->length - length ($2) -5; # for good measure
    	}
    	@starts = sort {$b <=> $a} @starts; # largest number in pos 0
    	@ends = sort {$a <=> $b} @ends; # smallest number in pos 0
    	$start = shift @starts;
    	$end = shift @ends;
    	next locus unless $start < $end;
    	my $newalign = new Bio::SimpleAlign;
    	my $counter = 1;
    	for my $seq ($aln->each_alphabetically) {
        	# trim the alignments
        	my $newstr = $seq->subseq($start, $end);
    		$seq->seq($newstr);
    		$seq->end(length( $newstr) - scalar (@{[$newstr =~ /(-)/g]}));
    		$newalign->add_seq($seq);		
    	}
    	new Bio::AlignIO(-file=>">$alignfile_out", -format=>"clustalw")->write_aln($newalign);
    }
}
