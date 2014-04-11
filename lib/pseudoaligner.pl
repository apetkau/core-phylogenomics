#!/usr/bin/env perl

package Pseudoaligner;

use strict;

use Getopt::Long;
use Bio::AlignIO;
use Bio::SimpleAlign;
use Bio::LocatableSeq;
use File::Copy;

__PACKAGE__->run() unless caller;

1;
    
sub usage
{
    print "Usage: pseudoaligner.pl -i <input dir> [-o <output dir>] [-l <log file>]\n";
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

    die "Input directory is not defined\n".usage if (not defined $input_dir);
    $output_dir = $input_dir if (not defined $output_dir);
    
    die "Output directory $output_dir is not a directory" if (not -d $output_dir);
    die "Input directory $input_dir is not a directory" if (not -d $input_dir);

    print $out_fh "Working with input_dir $input_dir\n";
    print $out_fh "Output to output_dir $output_dir\n";
    
    my $outputreport = "$output_dir/snp.report.txt";
    open REPORT, ">$outputreport";
    # my @files = sort {$a cmp $b} grep { /trimmed$/i } readdir(DH);
    
    opendir (my $input_dh, $input_dir) or die "Could not open $input_dir: $!";
    my @ids = sort {$a <=> $b } map {/(\d+)/;$1} grep {/snps\d+\.aln\.trimmed/} readdir($input_dh);
    close($input_dh);
    
    my @files = map {my $file = "snps" . $_ . ".aln.trimmed";$file} @ids;
    my @columns;
    #my @qualumns;
    my %longseq;
    my %longqual;
    my @seqlengths;
    for my $locusid (@ids) {
        my $file = "$input_dir/snps".$locusid.".aln.trimmed"; 
    	print $out_fh "Working on $file\n";
    #	my %qualmap;
    
    #	my $qualfile = "quals". $locusid . ".aln.trimmed";
    #	open QUAL , $qualfile || die "Foo! Qualfile $qualfile: $!\n";
    #	my @quals = <QUAL>;
    #	for my $row (@quals) {
    #		my @quals = split /\s+/, $row;
    #		my $strain = shift @quals;
    #		$qualmap{$strain} = \@quals;
    #	}
    	my $in = new Bio::AlignIO(-file=>"$file", -format=>"clustalw",-longid=>1);
    	my $aln = $in->next_aln;
    	for my $seq ($aln->each_alphabetically) {
    	my @nucleotides = split //, $seq->seq;
    		$longseq{$seq->display_id} .= $seq->seq;
    		$longseq{$seq->display_id} .= "*";
    		
    #		push @{$longqual{$seq->display_id}}, @{$qualmap{$seq->display_id}}; 
    #		push @{$longqual{$seq->display_id}}, "*";
    	}
    }
    
    # transpose rows to columns
    my @accessions = sort {$a cmp $b } keys %longseq;
    for my $acc (sort {$a cmp $b } keys %longseq) {
    	my @chars  = split undef, $longseq{$acc};
    #	my @quals = @{$longqual{$acc}};
    	for (my $x=0;$x<@chars;$x++) {
    		$columns[$x] .= $chars[$x];
    #		push @{$qualumns[$x]} , $quals[$x];
    	}
    }
    # write out qualumns and columns for a check
    #open COL, ">columns.txt" || die "foo columns: $!\n";
    #open QUAL, ">qualumns.txt" || die "foo qualumns: $!\n";
    #for my $column (@columns) {
    #print $out_fh COL $column, "\n";
    #my @qual = @{shift @qualumns};
    #print $out_fh QUAL join " ", @qual, "\n";
    #}
    my @minors;
    my @pseudoalign;
    my $columncounter = 1;
    my $locus = shift @files;
    #open PQUAL, ">pseudoquals.txt";
    my $locuscount=1;
    my $ambiguous_count = 0;
    my $gap_count = 0;
    my $other_count = 0;
    column: for my $column (@columns) {
    #	my $quals = join " " , @{shift @qualumns};
    	my @chars = split undef, $column;
    	my %char;
    	map {$char{$_}++} @chars;
    
    	 #dont include unless minor snp >=1 or if thereis a gap character
    	my $lowest;
        (my $minorsnp) = sort{$char{$a} <=> $char{$b}} keys %char;
    	my $snpval = $char{$minorsnp};
	next column unless $snpval>=1; # there must be one snp at least
	if ($column =~ /[^ATCG\*]/i)
	{
		if ($column =~ /-/)
		{
			$gap_count++;
		}
		elsif ($column =~ /^[A-Z]+$/i) # matchs not gap, but only alpha, must be ambiguous base
		{
			$ambiguous_count++;
		}
		else
		{
			print STDERR "Skipping column $column\n";
			$other_count++;
		}
		next column;
	}
    	if ($column =~ /\*/) { # file separator
    			$locus = shift @files;
    			$locuscount++;
    			next column;
    	}
    	if (scalar keys %char>1) { # as long as there are SNPs in the file
    		
    		push @pseudoalign, $column if scalar keys %char >1;	
    		(my $minorsnp, my $majorsnp) = sort{$char{$a} <=> $char{$b}}  keys %char;
    		my @strains;
    		while ($column =~ /$minorsnp/g) {
    			push @strains, $accessions[pos($column)-1];	
    		}
    		my $strains = join "\t", @strains;
    		print REPORT "column $columncounter: $minorsnp($majorsnp) from $locus in:\t $strains\n"; 
    		$columncounter++;
    }
    }
    my @newseqs;
    for my $column (@pseudoalign) {
    	my @chars = split undef, $column;
    	for (my $x=0;$x<@chars; $x++) {
    		$newseqs[$x].= $chars[$x];
    	}
    }
    my $pseudolength;
    my @accessions = sort {$a cmp $b} keys %longseq;
    my $newaln = new Bio::SimpleAlign(-longid=>1);
    for my $seqstr (@newseqs) {
    	my $acc = shift @accessions;
    	my $seq = new Bio::LocatableSeq;
    	$seq->seq($seqstr);
    	$seq->display_id($acc);
    	$newaln->add_seq($seq);
    	$pseudolength = length $seq->seq;
    }
    
    if (not $newaln->is_flush)
    {
        print  $out_fh "Error: not all sequences in alignment have length: ".$newaln->length."\n";
        for my $seq ($newaln->each_seq())
        {
            print $out_fh "Sequence: ".$seq->id." length: ".$seq->length."\n";
            print $out_fh "\t".$seq->seq."\n";
        }
        die;
    }
    
    my $pseudo_out = "$output_dir/pseudoalign.phy";
    my $out = new Bio::AlignIO (-file=>">$pseudo_out", -format=>"phylip",-longid=>1);
    $out->interleaved(0);
    $out->write_aln($newaln);
    print $out_fh "there are ", length($pseudoalign[0]), " strains in the pseudoalignment.\n";
    print $out_fh "there are $pseudolength snps in the alignment\n";
    print $out_fh "there are $locuscount loci in the alignment\n";
    print $out_fh "removed $gap_count gaps in all alignments\n";
    print $out_fh "removed $ambiguous_count ambiguous base pair characters in all alignments\n";
    print $out_fh "removed $other_count other columns in alignments\n";
}
