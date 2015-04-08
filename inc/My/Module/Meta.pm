package My::Module::Meta;

use 5.006002;

use strict;
use warnings;

use Carp;

sub new {
    my ( $class ) = @_;
    ref $class and $class = ref $class;
    my $self = {
	distribution => $ENV{MAKING_MODULE_DISTRIBUTION},
    };
    bless $self, $class;
    return $self;
}

sub build_requires {
    return +{
	'File::Temp'	=> 0,
##	'Test::More'	=> 0.40,
##	'Test::More'	=> 0.88,	# Because of done_testing().
	'Test::More'	=> 0.96,	# Because of subtest()
    };
}

sub distribution {
    my ( $self ) = @_;
    return $self->{distribution};
}

sub notice {
    my ( $self, $opt, $prompter ) = @_;

    my @possible_exes = ('SpaceTrack');

    print <<"EOD";

NOTICE -

The SpaceTrack script is now installed by default. If you do not want
this, you can rerun this script specifying the -n option.

The SpaceTrackTk script will not be installed, and has been moved to the
eg/ directory.\a\a\a

EOD

    if ( $opt->{n} ) {
	$opt->{y}
	    and die 'You have asserted both -y and -n; I can not resolve the contradiction';
	print "Because you have asserted -n, SpaceTrack will not be installed.\n\n";
	return;
    } elsif ( $opt->{y} ) {
	print "Because you have asserted -y, SpaceTrack will be installed.\n\n";
	return @possible_exes;
    } else {
	return @possible_exes;
    }
}

sub requires {
    my ( $self, @extra ) = @_;

    return {
	'Carp'			=> 0,
	'Data::Dumper'		=> 0,
	'Exporter'		=> 0,
	'Getopt::Long'		=> 2.39,	# For getoptionsfromarray
	'HTTP::Date'		=> 0,
	'HTTP::Request'		=> 0,
	'HTTP::Response'	=> 0,
	'HTTP::Status'		=> 6.03,	# For the teapot status
	'IO::File'		=> 0,
	'IO::Uncompress::Unzip'	=> 0,	# For McCants
	'JSON'			=> 0,	# For Space Track v2
	'List::Util'		=> 0,	# For Space Track v2 FILE tracking
	'LWP::UserAgent'	=> 0,
	'LWP::Protocol::https'	=> 0,	# Space track needs as of 11-Apr-2011
	'Mozilla::CA'		=> 20141217,
					# There is no direct dependency
					# on this, but some CPAN testers
					# consistently fail with CERT
					# problems, and I know this
					# works.
	'POSIX'			=> 0,
	'Scalar::Util'		=> 1.07,	# for openhandle.
	'Text::ParseWords'	=> 0,
	'Time::Local'		=> 0,
	'URI'			=> 0,
#	'URI::Escape'		=> 0,	# For Space Track v2
	'constant'		=> 0,
	'strict'		=> 0,
	'warnings'		=> 0,
	@extra,
    };
}

sub requires_perl {
    return 5.006002;
}


1;

__END__

=head1 NAME

My::Module::Meta - Information needed to build Astro::SpaceTrack

=head1 SYNOPSIS

 use lib qw{ inc };
 use My::Module::Meta;
 my $meta = My::Module::Meta->new();
 use JSON;
 print "Required modules:\n", to_json(
     $meta->requires(), { pretty => 1 } );

=head1 DETAILS

This module centralizes information needed to build C<App::Satpass2>. It
is private to the C<App::Satpass2> package, and may be changed or
retracted without notice.

=head1 METHODS

This class supports the following public methods:

=head2 new

 use lib qw{ inc };
 my $meta = My::Module::Meta->new();

This method instantiates the class.

=head2 build_requires

 use JSON;
 print to_json( $meta->build_requires(), { pretty => 1 } );

This method computes and returns a reference to a hash describing the
modules required to build the C<Astro::Coord::ECI> package, suitable for
use in a F<Build.PL> C<build_requires> key, or a F<Makefile.PL>
C<< {META_MERGE}->{build_requires} >> key.

=head2 distribution

 if ( $meta->distribution() ) {
     print "Making distribution\n";
 } else {
     print "Not making distribution\n";
 }

This method returns the value of the environment variable
C<MAKING_MODULE_DISTRIBUTION> at the time the object was instantiated.

=head2 notice

 my @exes = $meta->notice( \%opt, \&prompter );

This method prints a notice before building. It returns a list of
executables to build.

The arguments are the options hash returned by the build system, and a
reference to a prompt routine. This reference is given the prompt and
the default answer, and the correct argument depends on your build
system; for ExtUtils::MakeMaker it is C<\&prompt>; for Module::Build it
needs to be C<< sub { return $bldr->prompt( @_ ) } >>, where C<$bldr> is
the Module::Build object.

The above are general remarks.

In this incarnation, the method determines which executables are to be
installed.

=head2 requires

 use JSON;
 print to_json( $meta->requires(), { pretty => 1 } );

This method computes and returns a reference to a hash describing
the modules required to run the C<App::Satpass2> package, suitable for
use in a F<Build.PL> C<requires> key, or a F<Makefile.PL> C<PREREQ_PM>
key. Any additional arguments will be appended to the generated hash. In
addition, unless L<distribution()|/distribution> is true,
configuration-specific modules may be added.

=head2 requires_perl

 print 'This package requires Perl ', $meta->requires_perl(), "\n";

This method returns the version of Perl required by the package.

=head1 ATTRIBUTES

This class has no public attributes.


=head1 ENVIRONMENT

=head2 MAKING_MODULE_DISTRIBUTION

This environment variable should be set to a true value if you are
making a distribution. This ensures that no configuration-specific
information makes it into F<META.yml>.


=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010-2015 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
