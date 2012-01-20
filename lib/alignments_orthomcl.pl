#!/usr/bin/perl

package AlignmentsOrthomcl;

use strict;
use warnings;

use Getopt::Long;
use Bio::SeqIO;
use Cwd;
use File::Copy;
use File::Basename;

__PACKAGE__->run() unless caller;

1;

sub usage
{
	return
"Usage: ".basename($0).".pl -i <input_dir> -f <fasta_input> -o <output_dir>\n";
}

sub run
{
	my ($orthomcl_input,$fasta_input,$output_dir);

	if ( @_ && $_[0] eq __PACKAGE__)
	{
		GetOptions('i|orthomcl-input=s' => \$orthomcl_input,
		   'f|fasta-input=s' => \$fasta_input,
		   'o|output-dir=s' => \$output_dir) or die "Invalid options\n".usage;
	}
	else
	{
		($orthomcl_input, $fasta_input, $output_dir) = @_;
	}

	die "othomcl-input not defined\n".usage if (not defined $orthomcl_input);
	die "orthomcl-input $orthomcl_input does not exist.\n".usage if (not -e $orthomcl_input);

	die "fasta-input not defined\n".usage if (not defined $fasta_input);
	die "fasta-input $fasta_input not a valid directory\n".usage if (not -d $fasta_input);

	die "output not defined\n".usage if (not defined $output_dir);

	my %gene_seq; # hash table mapping sequence id to sequence for all input fasta files
	opendir(my $dh, $fasta_input) or die "Could not open $fasta_input: $!";
	my @files = grep {/\.fasta$/} readdir($dh);
	foreach my $file (@files)
	{
		my $file_path = "$fasta_input/$file";
		my $in = new Bio::SeqIO(-file => "$file_path", -format => "fasta") or die "Could not open $file_path: $!";
		my $seq = $in->next_seq;
		while (defined $seq)
		{
			my ($orf) = ($seq->display_id);
			if (not defined $orf)
			{
				print STDERR "Warning: no id in file $file_path for $seq";
			}
			else
			{
				$gene_seq{$orf} = $seq;
			}

			$seq = $in->next_seq;
		}
	}
	closedir($dh);

	open(my $g_h, "<$orthomcl_input") or die "Could not open groups file $orthomcl_input: $!";
	my $line = readline($g_h);

	mkdir $output_dir if (not -e $output_dir);
	while(defined $line)
	{
		my @group_en = split(/\s+/, $line);
	
		my ($group_name) = ($group_en[0] =~ /^([^:]*)/);
		die "Error: invalid group name ".(defined $group_name ? $group_name : 'undefined') if (not defined $group_name);
		my $filepath = "$output_dir/core.$group_name";
		open(my $fh, ">$filepath") or die "Could not write to $filepath: $!";
	        for ( my $i = 1; $i < @group_en; $i++)
	        {
	                my $en = $group_en[$i];
	
	                if (not defined $en)
	                {
	                        print STDERR "Warning: no proper id for line $line\n";
	                }
	                else
	                {
	                        my $seq = $gene_seq{$en};

	                        if (not defined $seq)
	                        {
	                                print STDERR "Warning: no in sequence list for entry $en\n";
	                        }
	                        else
	                        {
	                                print $fh ">$en\n";
                               		print $fh $seq->seq,"\n";
                        	}
	                }
		}
		close($fh);

		$line = readline($g_h);
        }
	close($g_h);
}
