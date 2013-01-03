#!/usr/bin/env perl

package Report::Blast;
use Report;
@ISA = qw(Report);

use strict;
use warnings;

sub new
{
	my ($proto, $logger) = @_;
	my $class = ref($proto) || $proto;
	my $self = $class->SUPER::new($logger);

	bless($self, $class);
}

sub _is_proper_core_file
{
	my ($self, $file) = @_;

	return ((defined $file) and $file =~ /^core.*\.ffn$/ or $file =~ /^100pid_core.*\.ffn/);
}

sub _is_proper_input_file
{
	my ($self, $file) = @_;

	return ((defined $file) and $file =~ /\.prepended\.fasta/);
}

