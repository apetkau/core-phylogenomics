#!/usr/bin/perl

package FileManager;

use strict;
use warnings;

sub new
{
	my ($class, $script_dir) = @_;

	die "script_dir not defined" if (not defined $script_dir);
	die "script_dir $script_dir does not exist" if (not -e $script_dir);

	my $self = {};
	bless($self,$class);

	$self->{'_dirs'} = {};
	$self->{'_files'} = {};
	$self->{'_abs_dirs'} = {};
	$self->{'_script_dir'} = $script_dir;

	return $self;
}

sub get_script_dir
{
	my ($self) = @_;

	return $self->{'_script_dir'};
}

sub set_job_dir
{
	my ($self, $job_dir) = @_;

	die "Undefined job_dir" if (not defined $job_dir);

	$self->{'_job_dir'} = $job_dir;
}

sub get_job_dir
{
	my ($self) = @_;

	return $self->{'_job_dir'};
}

sub set_dir
{
	my ($self, $key, $dir_value) = @_;

	die "Undefined key" if (not defined $key);
	die "Undefined value" if (not defined $dir_value);

	$self->{'_dirs'}->{$key} = $dir_value;	
}

sub set_abs_dir
{
	my ($self, $key, $dir_value) = @_;

	die "Undefined key" if (not defined $key);
	die "Undefined value" if (not defined $dir_value);

	$self->{'_abs_dirs'}->{$key} = $dir_value;	
}

sub get_abs_dir
{
	my ($self, $dir_key) = @_;

	die "dir_key not defined" if (not defined $dir_key);

	return $self->{'_abs_dirs'}->{$dir_key};
}

sub set_file
{
	my ($self, $key, $file_value) = @_;

	die "Undefined key" if (not defined $key);
	die "Undefined value" if (not defined $file_value);

	$self->{'_files'}->{$key} = $file_value;	
}

sub get_dir
{
	my ($self,$dir_key) = @_;

	die "dir_key not defined" if (not defined $dir_key);

	my $job_dir = $self->{'_job_dir'};
	die "Undefined job_dir" if (not defined $job_dir);

	my $dir = $self->{'_dirs'}->{$dir_key};

	if (not defined $dir)
	{
		return undef;
	}
	else
	{
		return "$job_dir/$dir";
	}
}

sub get_file
{
	my ($self,$file_key) = @_;

	die "file_key not defined" if (not defined $file_key);

	my $job_dir = $self->{'_job_dir'};
	die "Undefined job_dir" if (not defined $job_dir);

	my $file = $self->{'_files'}->{$file_key};

	if (not defined $file)
	{
		return undef;
	}
	else
	{
		return $file;
	}
}

sub get_file_dir
{
	my ($self, $dir_key, $file_key) = @_;

	die "file_key not defined" if (not defined $file_key);
	die "dir_key not defined" if (not defined $dir_key);

	my $job_dir = $self->{'_job_dir'};
	die "Undefined job_dir" if (not defined $job_dir);

	my $file = $self->{'_files'}->{$file_key};
	my $dir = $self->{'_dirs'}->{$dir_key};

	if ((not defined $file) or (not defined $dir))
	{
		return undef;
	}
	else
	{
		return "$job_dir/$dir/$file";
	}
}

sub build_job_dirs
{
	my ($self) = @_;

	die "Job dir is not defined" if (not defined $self->{'_job_dir'});

	mkdir $self->{'_job_dir'} if (not -e $self->{'_job_dir'});

	for my $key (keys %{$self->{'_dirs'}})
	{
		my $dir = $self->get_dir($key);
		mkdir $dir if (defined $dir and not -e $dir);
	}
}

1;
