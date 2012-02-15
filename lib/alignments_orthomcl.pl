#!/usr/bin/perl

package AlignmentsOrthomcl;

use strict;
use warnings;

use Getopt::Long;
use Bio::SeqIO;
use Cwd;
use File::Copy;
use File::Basename;

my $out_fh;

__PACKAGE__->run() unless caller;

1;

sub usage
{
	return
"Usage: ".basename($0).".pl -i <orthomcl input> -f <fasta_input> -o <output_dir> --strain-id <strain id> ... -l <log>
Options:
	-i|--orthomcl-input:  The orthomcl groups file to use for clusters of core genes.
	-f|--fasta-input:  The fasta input directory containing the nucleotide files.
	-o|--output-dir:  The output dir to store the core gene files.
	-s|--strain-id:  The ids of each strain to include in the set to filter out (multiple).
	-l|--log:  Log file\n";
}

sub create_set_table
{
	my ($set_params) = @_;
	my %ortho_group;
	my $ortho_group_string = '';
	my $first = 1;
	foreach my $i (@$set_params)
	{
		$ortho_group{$i} = 1;

		if ($first)
		{
			$ortho_group_string .= $i;
			$first = 0;
		}
		else
		{
			$ortho_group_string .= ", $i";
		}
	}

	return (\%ortho_group, $ortho_group_string);
}

# Input:  ortho_input  The orthomcl input groups file
# Output:  A list containing all the good groups which should be processed
sub handle_ortho_groups
{
	my ($ortho_input,$ortho_group) = @_;

	my @ortho_good_group;

	my $number_valid_strains_in_set = scalar(keys %$ortho_group);

	open(my $g_h, "<$ortho_input") or die "Could not open groups file $ortho_input: $!";
	my $line = readline($g_h);

	my $group_kept = 0;
	my $group_filtered = 0;
	while (defined $line)
	{
		my @group_en = split(/\s+/, $line);
		my %existence_hash;
		my @good_ortho_values; # stores the combined strain/locus tag names for the current group
	
		my ($group_name) = ($group_en[0] =~ /^([^:]*)/);
		die "Error: invalid group name ".(defined $group_name ? $group_name : 'undefined') if (not defined $group_name);

		for(my $g = 1; $g < scalar(@group_en); $g++)
		{
			my ($strain,$locus_id) = split(/\|/, $group_en[$g]);
			die "No strain name found for $group_en[$g] on $line" if ((not defined $strain) or $strain eq '');
			die "No locus_id found for $group_en[$g] on $line" if ((not defined $locus_id) or $locus_id eq '');

			if (not exists $ortho_group->{$strain})
			{
				print $out_fh "No ortholog group name for $strain in set, skipping ...\n";
			}
			elsif (not exists $existence_hash{$strain})
			{
				$existence_hash{$strain} = 1;
				push(@good_ortho_values, {name => $strain, id => $locus_id});
			}
			else
			{
				print $out_fh "Duplicate for strain $strain found, skipping ...\n";
			}
		}

		if (scalar(@good_ortho_values) == $number_valid_strains_in_set)
		{
			push(@ortho_good_group, \@good_ortho_values);
			$group_kept++;
		}
		else
		{
			print $out_fh "Skipping group as it does not contain a complete valid set of strains: $line\n";
			$group_filtered++;
		}
		
		$line = readline($g_h);
	}

	close($g_h);

	return (\@ortho_good_group, $group_kept, $group_filtered);
}

sub create_seq_gene_table
{
	my ($fasta_input_dir) = @_;

	my %gene_seq; # hash table mapping sequence id to sequence for all input fasta files
	opendir(my $dh, $fasta_input_dir) or die "Could not open $fasta_input_dir: $!";
	my @files = grep {/\.fasta$/} readdir($dh);
	foreach my $file (@files)
	{
		my $file_path = "$fasta_input_dir/$file";
		my $in = new Bio::SeqIO(-file => "$file_path", -format => "fasta") or die "Could not open $file_path: $!";
		my $seq = $in->next_seq;
		while (defined $seq)
		{
			my ($orf) = ($seq->display_id);
			if (not defined $orf)
			{
				print $out_fh "Warning: no id in file $file_path for $seq";
			}
			else
			{
				$gene_seq{$orf} = $seq;
			}

			$seq = $in->next_seq;
		}
	}
	closedir($dh);

	return \%gene_seq;
}

sub run
{
	my ($orthomcl_input,$fasta_input,$output_dir, $strain_id,$log);

	if ( @_ && $_[0] eq __PACKAGE__)
	{
		GetOptions('i|orthomcl-input=s' => \$orthomcl_input,
		   'f|fasta-input=s' => \$fasta_input,
		   'o|output-dir=s' => \$output_dir,
		   's|strain-id=s@' => \$strain_id,
		   'l|log=s' => \$log) or die "Invalid options\n".usage;
	}
	else
	{
		($orthomcl_input, $fasta_input, $output_dir, $strain_id, $log) = @_;
	}

	die "othomcl-input not defined\n".usage if (not defined $orthomcl_input);
	die "orthomcl-input $orthomcl_input does not exist.\n".usage if (not -e $orthomcl_input);

	die "fasta-input not defined\n".usage if (not defined $fasta_input);
	die "fasta-input $fasta_input not a valid directory\n".usage if (not -d $fasta_input);

	die "strain-id not defined, must define at least one".usage if (not defined $strain_id);
	die "strain-id not defined, must define at least one".usage if (not (@$strain_id > 0));

	die "output not defined\n".usage if (not defined $output_dir);

	if (defined $log)
	{
		open($out_fh, '>', $log) or die "Could not open $log: $!";
	}
	else
	{
		open($out_fh, '>-') or die "Could not open stdout for writing";
	}

	my ($ortho_group, $ortho_group_string) = create_set_table($strain_id); # hash table defining which strains we want to filter out for defining group of orthologs
	print $out_fh "Filtering $ortho_group_string using orthomcl file $orthomcl_input and fasta input directory $fasta_input\n";
	my $seq_gene = create_seq_gene_table($fasta_input);

	my ($groups, $group_kept, $group_filtered) = handle_ortho_groups($orthomcl_input,$ortho_group);
	print $out_fh "Kept a total of $group_kept of ".($group_kept + $group_filtered)." groups\n";

	my %strain_locus;
	mkdir $output_dir if (not -e $output_dir);

	for(my $i = 0; $i < @$groups; $i++)
	{
		my $num = $i+1;
		my $ortho_group = $groups->[$i];

		my $filepath = "$output_dir/snps$num";
		open(my $fh, ">$filepath") or die "Could not write to $filepath: $!";
	        for ( my $j = 0; $j < @$ortho_group; $j++)
	        {
			my $entry = $ortho_group->[$j];
			my $strain = $entry->{'name'};
			my $id = $entry->{'id'};
			my $seq_gene_string = "$strain|$id";
	
	                if (not defined $entry)
	                {
	                        die "Error: undefined entry\n";
	                }
	                else
	                {
	                        my $seq = $seq_gene->{$seq_gene_string};

	                        if (not defined $seq)
	                        {
	                                print $out_fh "Warning: no in sequence list for entry $seq_gene_string\n";
	                        }
	                        else
	                        {
	                                print $fh ">$strain $strain|$id\n";
                               		print $fh $seq->seq,"\n";
                        	}
	                }
		}
		close($fh);
        }
}
