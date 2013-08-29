#!/usr/bin/env perl
use warnings;
use strict;
use Getopt::Long;
use Bio::SeqIO;
use File::Basename qw/basename/;

my ($nucmer,$delta_filter,$reference,$contig,$vcf,$show_aligns,$bgzip,$tabix,$verbose);
GetOptions('s|nucmer-path=s' => \$nucmer,
	   'b|delta-filter-path=s' => \$delta_filter,
	   'r|reference=s' => \$reference,
	   'contig=s' => \$contig,
	   'out-vcf=s' => \$vcf,
	   'show-align-path=s' => \$show_aligns,
	   'bgzip-path=s' => \$bgzip,
	   'tabix-path=s' => \$tabix,
           'verbose' => \$verbose );

die "Error: no nucmer path not defined" if (not defined $nucmer);
die "Error: no delta_filter path defined" if (not defined $delta_filter);
die "Error: no show_aligns path defined" if (not defined $show_aligns);
die "Error: no bgzip path defined" if (not defined $bgzip);
die "Error: no tabix path defined" if (not defined $tabix);
die "Error: reference not defined" if (not defined $reference);
die "Error: no reference exists" if (not -e $reference);
die "Error: contig not defined" if (not defined $contig);
die "Error: contig does not exist" if (not -e $contig);
die "Error: no out-vcf defined" if (not defined $vcf);

my $basename =$contig;

my $command = "$nucmer --prefix=$basename \"$reference\" \"$contig\"";
print "Running $command\n";
system($command) == 0 or die "Could not run $command";

my $delta_out= "$basename" . '.delta';
my $filter_out = "$basename" . '.filter';

die "Error: no output from nucmer was produced" if (not -e $delta_out);

$command = "$delta_filter -o 0 -1 -q $delta_out > $filter_out";
print "Running $command\n";
system($command) == 0 or die "Could not run $command";

die "Error: no output from delta-filter was produced" if (not -e $filter_out);

my $pileup_align = "$basename" . '_aligns.txt';
#will have to be iterate over every fasta record ... on both sides!
#at the moment, just works on 1 to 1 fasta

my $bp={};


my $ref_length = fasta_length($reference);
my $contig_length = fasta_length($contig);

#foreach with different combination
foreach my $query_id( keys %$contig_length){
    foreach my $ref_id(keys %$ref_length ) {
        
        $command = "$show_aligns -q $filter_out \"$ref_id\" \"$query_id\" 2>&1  > $pileup_align";
        
        my $stderr = `$command`;

        #we should ignoring show_align failures where the query contig was simply just filtered out or never match in the first place
        if ($stderr) {
            if ( $stderr =~ /ERROR: Could not find any alignments for /  ) {
                print "INFO: Could not find match for query contig '$query_id' against reference contig '$ref_id'\n";
                
                unlink $pileup_align if ( -e $pileup_align);
                next;
            }
            else {
                die "Could not run $command";
            }
        }
        
        die "Error: no output from show-snps was produced" if (not -e $pileup_align);
        
        $bp = parse_alignments($bp,$ref_id,$pileup_align);
        unlink $pileup_align;
    }
    

}

write_vcf($vcf,$bp,$ref_length);

#compressing and indexing for future use
die "Error: no output vcf file=$vcf produced" if (not -e $vcf);
$command = "$bgzip -f \"$vcf\"";
print "Running $command\n";
system($command) == 0 or die "Could not run $command";
$command = "$tabix -f -p vcf \"$vcf.gz\"";
print "Running $command\n";
system($command) == 0 or die "Could not run $command";

die "Error: no output bgzip/tabix vcf file=$vcf.gz produced" if (not -e "$vcf.gz");

#clean up time;
unlink $delta_out;
unlink $filter_out;
unlink $pileup_align;


exit;

sub fasta_length{
    my ($file) = @_;
    
    my %lengths;
    my $in = Bio::SeqIO->new(-format=>'fasta',-file=>$file);

    while ( my $seq = $in->next_seq()) {
        $lengths{$seq->display_id} = $seq->length();
    }
    return \%lengths;
}


sub write_vcf {
    my ($name,$bp,$ref_contigs) = @_;

    open my $out,'>',$name;
    print $out "##fileformat=VCFv4.1\n";
    print $out "##INFO=<ID=DP,Number=1,Type=Integer,Description=\"Total read depth at the locus\">\n";
    print $out join("\t","#CHROM","POS","ID","REF","ALT","QUAL","FILTER","INFO") . "\n";

    
    foreach my $ref( keys %$ref_length) {
    
    my $length=$ref_length->{$ref};
    
    for my $pos(1..$length) {
        my @line;
        if ( exists $bp->{$ref}{$pos}) {
            @line = ($ref,$pos,'.',$bp->{$ref}{$pos}{'ref_bp'},$bp->{$ref}{$pos}{'q_bp'},'999','.',"DP=10000");
        }
        else {
            @line = ($ref,$pos,'.','.','.','.','.',"DP=0");
        }
        
        print $out join("\t",@line) . "\n";
    }
        
    }

    close $out;

    return;
}


sub parse_alignments {
    #grabbing arguments either from command line or from another module/script
    my ( $bp, $ref,$align_file ) = @_;

    
    my %bp = %{$bp};
    
    open my $in , '<', $align_file;

    #get skip first 3 lines in the file to ease
    for ( 0..2) {
        <$in>;
    }
    my $alignment = <$in>;
    chomp $alignment;
    my ($ref_id,$query_id) = $alignment =~ /.*between (.+) and (.+)/;
        
    #skip blank line
    <$in>;
        
        
    my $next_align = next_alignment($in);
    while ( my ($details) = $next_align->()) {
        if (! %$details) {
            last;
        }

        #go thru each base pair that was alignmned to the reference and record the position
        #if the query or reference have a gap, it will be ignored
        my ($qseq,$hseq) = ($details->{'query_seq'},$details->{'hit_seq'});

            
        #check to see if we are increasing or decreasing
        my ($pos,$next) =($details->{'start_hit'},1);
            
        if ( $details->{'orient_hit'} eq '-1') {
            $next=-1;
            $pos = $details->{'stop_hit'};
        }
            
        my @qseq = split//,$qseq;
        foreach my $ref_bp( split //,$hseq) {
            my $query_bp = shift @qseq;
            #we do not care about indels at the moment.
            if ( $query_bp eq '.' or $ref_bp eq '.') {
                print "Found indel @ '$pos'. Skipping\n" if $verbose;
                next;
            }
            else {
                if ( exists $bp{$ref}{$pos} && $bp{$ref}{$pos}{'q_bp'} ne $query_bp) {
                    die "Seen already '$pos' with " . $bp{$ref}{$pos}{'q_bp'} ." against $query_bp\n";
                }
                elsif (exists $bp{$ref}{$pos} && $bp{$ref}{$pos}{'q_bp'} eq $query_bp ) {
                    print "Same base pair for $pos\n" if $verbose;
                }
                
                $bp{$ref}{$pos}={'q_bp'=>$query_bp,'ref_bp'=> $ref_bp};
                #increment/decrement to next pos
                $pos +=$next;
                
            }
            
        }
            
    }
    
    close $in;
    
    return \%bp;
}


sub next_alignment {
    my ($in)=@_;
    my $lines;
    
    return sub {
        local $/ = "END ";    
        $lines= <$in>;
        my %details;
        {
            my ($align);
            if ($lines) {
                local $/ = "\n";
                open $align ,'<',\$lines;
                my $header = <$align>;
                chomp $header;
                
                #if we see 'END alignment'... we will skip the line since the alignment are not evenly split since they do NOT have unique end markers
                #having unique end markers would make parser a lot easier. i.e '//' in genbank files or '>' in fasta files
                if ( $header =~ /^alignment.*/) {
                    $header = <$align>;
                    chomp ($header);
                }
                
                if ( $header) {
                    #print "$header\n";
                    #get orientation,start & stop for both query and reference
                    my @line = split/\s+/,$header;
                    $details{'start_query'} =$line[10];
                    $details{'stop_query'} =$line[12];
                    $details{'orient_query'} =$line[9];
                    
                    $details{'start_hit'} =$line[5];
                    $details{'stop_hit'} =$line[7];
                    $details{'orient_hit'} =$line[4];
                    $details{'header'} = $header;
                }

                while (my $hit_line = <$align>) {
                    chomp $hit_line;
                    
                    if ($hit_line && $hit_line =~ /\d+\s+.*/) {
                        #remove the whitespace and coordinate from the beginning of the line and just save the base pair
                        my (undef,$hit_seq) = split/\s+/,$hit_line;

                        
                        #hit line always follows a query line
                        my $query_line = <$align>;
                        chomp $query_line;
                        my (undef,$query_seq) = split/\s+/,$query_line;
                        
                        my $match_line = <$align>;
                        
                        if (length $query_seq == length $hit_seq ) {
                            $details{'query_seq'} .= $query_seq;
                            $details{'hit_seq'} .= $hit_seq;
                        }
                        else {
                            die "Alignments are not the same length for HSP : '$header'\n";
                        }

                        
                    }
                }
                
                
            }
            
        }
        
        
        return \%details;
    }
}
