#!/usr/bin/perl

package JobProperties;

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
	$self->{'_properties'} = {};

	return $self;
}

sub set_property
{
	my ($self, $key, $value) = @_;

	die "Undefined key" if (not defined $key);
	die "Undefined value" if (not defined $value);

	$self->{'_properties'}->{$key} = $value;
}

sub get_property
{
	my ($self, $key) = @_;

	return $self->{'_properties'}->{$key};
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

sub write_properties
{
	my ($self, $file) = @_;

	die "File is undefined" if (not defined $file);

        open(my $out_fh, '>', $file) or die "Could not write to $file: $!";
        print $out_fh "#Properties for snp-phylogenomics job\n";
        print $out_fh "#Auto-generated on ".`date`."\n";
        $self->_perform_write_properties($out_fh);
        close($out_fh);
}

sub _perform_write_properties
{
        my ($self, $out_fh, $prefix) = @_;

	my $job_properties = $self->{'_properties'};
        my $real_prefix = defined $prefix ? $prefix : '';
        foreach my $key (keys %$job_properties)
        {
                my $value = $job_properties->{$key};
                if ((ref $value) eq 'ARRAY')
                {
                        print $out_fh "$real_prefix$key=".join(', ',@$value),"\n";
                }
                else
                {
                                print $out_fh "$real_prefix$key=".$job_properties->{$key}."\n";
                }
        }
}

sub read_properties
{
	my ($self,$file) = @_;

	open(my $in_fh, '<', $file) or die "Could not open $file: $!\n";
	while (my $line = <$in_fh>)
	{
		chomp $line;

		my ($real_content) = ($line =~ /^([^#]*)/);
		if (defined $real_content)
		{
			my ($key,$value) = ($real_content =~ /^([^=]+)=(.*)$/);

			if (defined $key and defined $value)
			{
				if ($value =~ /,/)
				{
					my @values = split(/,/,$value);
					$self->set_job_property($key, \@values);
				}
				else
				{
					$self->set_job_property($key, $value);
				}
			}
		}
	}
}

1;
