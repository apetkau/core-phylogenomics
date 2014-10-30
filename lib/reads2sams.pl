#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use Bio::SeqIO;
use File::Path qw(rmtree);
use File::Copy "move";

my $SMALT = "smalt";
print STDERR "PERL5LIB=".$ENV{'PERL5LIB'}."\n";


my (@readfiles, $smalt_path, $sam_dir, $output_dir, $keep_tmp_files, $reference_file, $help,  $smalt_map_opts, $smalt_index_opts, $verbose);
my $samtools_path;
my $bam_dir;

GetOptions (
    't|reference=s'=>\$reference_file,
    's|smalt-path=s' => \$smalt_path,
    'samtools-path=s' => \$samtools_path,
    'sam-dir=s' => \$sam_dir,
    'bam-dir=s' => \$bam_dir,
    'r|reads=s@'=>\@readfiles,
    'm|map_opts=s'=>\$smalt_map_opts,
    'i|index_opts=s'=>\$smalt_index_opts,
    'v|verbose'=>\$verbose,
    'd|dir=s'=>\$output_dir,
    'k|keep'=>\$keep_tmp_files,
    'h|help' => \$help
 );


die usage() if $help;
die usage("missing arguments") unless $reference_file  and scalar @readfiles>0;
die usage("No smalt-path defined\n") if (not defined $smalt_path);
die usage("No samtools-path defined\n") if (not defined $samtools_path);
die usage("No sam-dir defined\n") if (not defined $sam_dir or (not -d $sam_dir));
die usage("No bam-dir defined\n") if (not defined $bam_dir or (not -d $bam_dir));

$SMALT=$smalt_path;

$output_dir ||= ".";
$smalt_index_opts ||= "-k 20 -s 20";
$smalt_map_opts ||= "-f samsoft";

my $tmp_dir = ".reads2samstmp";
mkdir $output_dir or die ("couln't create $output_dir: $!") unless -d $output_dir and $output_dir;
#rmtree($tmp_dir);
mkdir "$output_dir/$tmp_dir" unless -d "$output_dir/$tmp_dir";
open LOG, ">$output_dir/reads2bams.log" || die "Couldn't open $output_dir/reads2bams.log for writing: $!\n";
my %filecheck; # check for duplicate filenames
my @filestore; # store filename parts
# get list of readfiles
for (@readfiles) {    
    my($filename, $directories) = fileparse($_);
    my ($basename) = $filename =~ /^(.*)\./; #greedy
    $basename = $filename unless $basename;
    push @filestore, [$_,$filename, $directories, $basename];
    die usage ("duplicate filename: $filename") if $filecheck{$basename};
    $filecheck{$filename}++;
}

# reference work
my $refseq = new Bio::SeqIO(-file=>$reference_file, -format=>"fasta")->next_seq;
die "couldn't parse reference fasta reference sequence $reference_file" unless $refseq;
my $ref_accession = $refseq->display_name;
my $ref_length = $refseq->length;
my($ref_file, $ref_dir) = fileparse($reference_file);
my ($ref_file_basename) = $ref_file =~ /^(.*)\./; #greedy
$ref_file_basename = $ref_file unless $ref_file_basename;
my $ref_file_index = $ref_file_basename . ".index";
my $cmd = "$SMALT index $smalt_index_opts $output_dir/$tmp_dir/$ref_file_index $reference_file >$output_dir/$tmp_dir/temp.log";
print "creating reference index...\n" if $verbose;
print LOG "creating reference index...\n";
my $result = system($cmd);
die "smalt command '$cmd' failed with error: $!\n" if $result;
open TMPLOG, "$output_dir/$tmp_dir/temp.log" || die "Couldnt open $output_dir/$tmp_dir/temp.log for reading: $!\n";
my @log = <TMPLOG>;
close TMPLOG;
if ($verbose) {print for @log}
print LOG for @log;# add to master log


# read work

# smalt default map options (will be overwritten by _any_ 

for (@filestore) {
    my ($fullpath,$filename, $directories, $basename) = @{$_};
    my $cmd = "$SMALT map $smalt_map_opts -o $output_dir/$tmp_dir/$basename.sam $output_dir/$tmp_dir/$ref_file_index $fullpath >$output_dir/$tmp_dir/temp.log";

    print "\nmapping $filename to $ref_file_basename...\n" if $verbose;
    my $result = system($cmd);
    print LOG  "smalt command '$cmd' failed with error: $!\n" if $result;
    die "smalt command '$cmd' failed with error: $!\n" if $result;
    open TMPLOG, "$output_dir/$tmp_dir/temp.log" || die "Couldnt open temp.log for reading: $!\n";
    my @log = <TMPLOG>;
    close TMPLOG;
    print LOG for @log;# add to master log
    if ($verbose) {print for @log}

    # prepend headers to the sam file
    open SAM, "$output_dir/$tmp_dir/$basename.sam" || die "couldn't open $output_dir/$tmp_dir/$basename.sam for reading: $!\n";
    my @sam = <SAM>;
    close SAM;

    my $out_sam_file = "$output_dir/$basename.sam";
    open SAM, ">$out_sam_file" || die "couldn't open $output_dir fowriting: $!\n";
    print SAM "\@HD\tVN:1.4\n" unless $sam[0] =~ /^\@HD/;
    print SAM "\@SQ\tSN:$ref_accession\tLN:$ref_length\n" unless $sam[1] =~ /^\@SQ/;
    print SAM for @sam;
    unlink "$output_dir/$tmp_dir/$basename.sam" || die "couldn't remove $output_dir/$tmp_dir/$basename.sam: $!\n";

    my $new_out_file = "$sam_dir/$basename.sam";
    my $unsorted_bam_out = "$sam_dir/$basename.unsorted.bam";
    my $sorted_bam_base = "$sam_dir/$basename";
    my $sorted_bam_file = "$sorted_bam_base.bam";
    my $final_bam_file = "$bam_dir/$basename.bam";
    unlink($new_out_file) if (-e $new_out_file);
    symlink($out_sam_file,$new_out_file) or die "Could not link $out_sam_file to $new_out_file: $!";

    my $samtools_command = "$samtools_path view -bt \"$reference_file\" \"$new_out_file\" -o \"$unsorted_bam_out\"";
    print "running $samtools_command\n";
    system($samtools_command) == 0 or die "Could not execute $samtools_command";

    $samtools_command = "$samtools_path sort -m 536870912 \"$unsorted_bam_out\" \"$sorted_bam_base\""; 
    print "running $samtools_command\n";
    system($samtools_command) == 0 or die "Could not execute $samtools_command";

    move($sorted_bam_file,$final_bam_file) or die "Could not move $sorted_bam_file to $final_bam_file: $!";

    $samtools_command = "$samtools_path index \"$final_bam_file\"";
    print "running $samtools_command\n";
    system($samtools_command) == 0 or die "Could not execute $samtools_command";

    # cleanup unneeded files
    unless ($keep_tmp_files) {
        unlink "$unsorted_bam_out" || die "Couldn't remove $unsorted_bam_out: $!\n";
        unlink "$new_out_file" || die "Couldn't remove $new_out_file: $!\n";
        unlink "$out_sam_file" || die "Couldn't remove $out_sam_file: $!\n";
    }
}

unless ($keep_tmp_files) {
    unlink "$output_dir/$tmp_dir/$ref_file_index" || die "Couldn't remove files in $output_dir/$tmp_dir/$ref_file_index: $!\n";
    unlink "$output_dir/$tmp_dir/temp.log" || die "Couldn't remove $output_dir/$tmp_dir/temp.log: $!\n";
    unlink "$output_dir/$tmp_dir/$ref_file_index.smi" || die "Couldn't remove $output_dir/$tmp_dir/$ref_file_index.smi: $!\n";
    unlink "$output_dir/$tmp_dir/$ref_file_index.sma" || die "Couldn't remove $output_dir/$tmp_dir/$ref_file_index.sma: $!\n";
    rmdir "$output_dir/$tmp_dir" || die "Couldn't remove dir $output_dir/$tmp_dir: $!\n";
}


close LOG;
exit 0;
sub usage {
    my $message = shift;
    print $message, "\n" if $message;
    print <<EOF

$0 - Align multiple reads sets to a reference and generate bam files .
     read files must have unique file basenames eg (strain1.fa strain2.fa)   
usage: $0  <options>
       -t|--reference <reference fasta file> (mandatory)
       -r|--reads <readfile 1> --r|--reads <readfile 2> ...
       -d|--dir <output_dir>   (the ouptuput folder to store the results (required)
       -m|--map <options> (the map options to pass to smalt, e.g --map '-n 8'
       -i|--index <options> (the indexing options to pass to smalt, e.g. --index '-k 20'

eg:    $0  -t ../reference/NC_003997.3.fasta -r reads2.fastq -d . --index '-k 20' --map '-n 8 -f samsoft'

EOF
}
