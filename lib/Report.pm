#!/usr/bin/env perl

package Report;

use strict;
use warnings;

use Bio::SeqIO;

sub new
{
	my ($class, $logger) = @_;

	my $self = {};
	$self->{'_logger'} = $logger;

	bless($self, $class);

	return $self;
}

sub report_snp_locus
{
        my ($self, $core_dir,$pseudoalign_dir) = @_;

        my %total_locus_lengths;
        my $snp_locus_count = 0;
        my $snp_report_file = "$pseudoalign_dir/snp.report.txt";

        # gets snps/core genes used in pipeline (from snp report)
        open(my $snp_report_fh, $snp_report_file) or die "Could not open snp report $snp_report_file: $!";
        my %align_files;
        my $line = readline($snp_report_fh);
        while ($line)
        {
                my ($align_file) = ($line =~ /(snps\d+\.aln\.trimmed)/);
                $align_files{$align_file} = 1;

                $line = readline($snp_report_fh);
        }
        close($snp_report_fh);

        # loci count
        for my $align_file (keys %align_files)
        {
                if ($align_file =~ /^(snps\d+)\.aln.trimmed$/)
                {
                        my $core_file = $1;
                        if (not defined $core_file)
                        {
                                $self->log("Warning: core_file for $align_file not defined, skipping...",1);
                                next;
                        }

                        my $full_file_path = "$core_dir/$core_file";
                        if ($self->process_ortholog_file($full_file_path,\%total_locus_lengths))
                        {
                                $snp_locus_count++;
                        }
                }
        }

        return ($snp_locus_count,\%total_locus_lengths);
}

sub log
{
	my ($self, $message, $level) = @_;

	my $logger = $self->{'_logger'};

	if (defined $logger)
	{
		$logger->log($message, $level);
	}
	else
	{
		print $message;
	}
}

sub process_ortholog_file
{
        my ($self, $ortho_file, $total_locus_lengths) = @_;
        my $success = 0;

        if (not -e $ortho_file)
        {
                $self->log("Warning: ortho_file=$ortho_file does not exist, skipping...",1);
                return $success;
        }

        $self->log("processing $ortho_file\n",1);
        my $in = new Bio::SeqIO(-file=>"$ortho_file", -format=>"fasta");
        my  @orfs;
        while (my $seq = $in->next_seq)
        {
                my ($orf) = $seq->desc =~ /^(.*?)(\s|$)/;
                my ($strain_id) = ($orf =~ /^([^\|]*)\|/);
                die "Error, found invalid strain_id=$strain_id in orf=$orf" if (not defined $strain_id or $strain_id eq '');
                if (not exists $total_locus_lengths->{$strain_id})
                {
                        $total_locus_lengths->{$strain_id} = $seq->length;
                }
                else
                {
                        $total_locus_lengths->{$strain_id} += $seq->length;
                }
        }

        $success = 1;
        return $success;
}

sub _is_proper_core_file
{
	my ($self, $file) = @_;

	return 0;
}

sub report_core_locus
{
        my ($self, $core_dir) = @_;
        my %total_locus_lengths;
        my $core_locus_count = 0;

        opendir(my $core_dh, $core_dir) or die "Could not open directory $core_dir: $!";

        # loci count
        my $file = readdir($core_dh);
        while($file)
        {
                if ($self->_is_proper_core_file($file))
                {
                        my $full_file_path = "$core_dir/$file";
                        if ($self->process_ortholog_file($full_file_path,\%total_locus_lengths))
                        {
                                $core_locus_count++;
                        }
                }

                $file = readdir($core_dh);
        }

        return ($core_locus_count,\%total_locus_lengths);
}

sub _is_proper_input_file
{
	my ($self, $file) = @_;

	return 0;
}

sub report_initial_strains
{
        my ($self, $fasta_dir) = @_;
        my %total_features_lengths;
        my %total_strain_loci;

        opendir(my $fasta_dh, $fasta_dir) or die "Could not open directory $fasta_dir: $!";
        my @files = readdir($fasta_dh);
        closedir($fasta_dh);

        for my $file (@files)
        {
                if ($self->_is_proper_input_file($file))
                {
                        next if ($file =~ /^all/);

                        my $strain_id = undef;
                        my $full_file_path = "$fasta_dir/$file";
                        $self->log("processing $full_file_path\n",1);
                        my $in = new Bio::SeqIO(-file=>"$full_file_path", -format=>"fasta");
                        while (my $seq = $in->next_seq)
                        {
                                my ($orf) = ($seq->display_id);
                                my ($strain_id_curr) = ($orf =~ /^([^\|]*)\|/);
                                if (not defined $strain_id)
                                {
                                        $strain_id = $strain_id_curr;
                                }
                                else
                                {
                                        die "Error: found two entries in file $full_file_path with different strain ids: $strain_id and $strain_id_curr" if ($strain_id_curr ne $strain_id);
                                }

                                if (not exists $total_features_lengths{$strain_id})
                                {
                                        $total_features_lengths{$strain_id} = $seq->length;
                                        $total_strain_loci{$strain_id} = 1;
                                }
                                else
                                {
                                        $total_features_lengths{$strain_id} += $seq->length;
                                        $total_strain_loci{$strain_id}++;
                                }
                        }
                }
        }

        return (\%total_strain_loci,\%total_features_lengths);
}

1;
