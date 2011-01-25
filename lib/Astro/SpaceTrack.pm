=head1 NAME

Astro::SpaceTrack - Retrieve orbital data from www.space-track.org.

=head1 SYNOPSIS

 my $st = Astro::SpaceTrack->new (username => $me,
     password => $secret, with_name => 1) or die;
 my $rslt = $st->spacetrack ('special');
 print $rslt->is_success ? $rslt->content :
     $rslt->status_line;

or

 perl -MAstro::SpaceTrack=shell -e shell
 
 (some banner text gets printed here)
 
 SpaceTrack> set username me password secret
 OK
 SpaceTrack> set with_name 1
 OK
 SpaceTrack> spacetrack special >special.txt
 SpaceTrack> celestrak visual >visual.txt
 SpaceTrack> exit

=head1 LEGAL NOTICE

The following two paragraphs are quoted from the Space Track web site.

Due to existing National Security Restrictions pertaining to access of
and use of U.S. Government-provided information and data, all users
accessing this web site must be an approved registered user to access
data on this site.

By logging in to the site, you accept and agree to the terms of the
User Agreement specified in
L<http://www.space-track.org/perl/user_agreement.pl>.

You should consult the above link for the full text of the user
agreement before using this software.

=head1 DESCRIPTION

This package accesses the Space-Track web site,
L<http://www.space-track.org>, and retrieves orbital data from this
site. You must register and get a username and password before you
can make use of this package, and you must abide by the site's
restrictions, which include not making the data available to a
third party.

In addition, the celestrak method queries L<http://celestrak.com/> for
a named data set, and then queries L<http://www.space-track.org/> for
the orbital elements of the objects in the data set. This method may not
require a Space Track username and password, depending on how you have
the Astro::SpaceTrack object configured. See the documentation on this
method for the details.

Other methods (amsat(), spaceflight() ...) have been added to access
other repositories of orbital data, and in general these do not require
a Space Track username and password.

Beginning with version 0.017, there is provision for retrieval of
historical data.

Nothing is exported by default, but the shell method/subroutine
and the BODY_STATUS constants (see L</iridium_status>) can be
exported if you so desire.

Most methods return an HTTP::Response object. See the individual
method document for details. Methods which return orbital data on
success add a 'Pragma: spacetrack-type = orbit' header to the
HTTP::Response object if the request succeeds, and a 'Pragma:
spacetrack-source =' header to specify what source the data came from.

=head2 Methods

The following methods should be considered public:

=over 4

=cut

package Astro::SpaceTrack;

use 5.006002;

use strict;
use warnings;

use base qw{Exporter};

our $VERSION = '0.050';
our @EXPORT_OK = qw{shell BODY_STATUS_IS_OPERATIONAL BODY_STATUS_IS_SPARE
    BODY_STATUS_IS_TUMBLING};
our %EXPORT_TAGS = (
    status => [qw{BODY_STATUS_IS_OPERATIONAL BODY_STATUS_IS_SPARE
	BODY_STATUS_IS_TUMBLING}],
);

use Astro::SpaceTrack::Parser;
use Carp;
use Compress::Zlib ();
use Getopt::Long;
use IO::File;
use HTTP::Response;	# Not in the base, but comes with LWP.
use HTTP::Status qw{RC_NOT_FOUND RC_OK RC_PRECONDITION_FAILED
	RC_UNAUTHORIZED RC_INTERNAL_SERVER_ERROR};	# Not in the base, but comes with LWP.
use LWP::UserAgent;	# Not in the base.
use POSIX qw{strftime};
use Scalar::Util 1.07 qw{ blessed };
use Text::ParseWords;
use Time::Local;

use constant COPACETIC => 'OK';
use constant BAD_SPACETRACK_RESPONSE =>
	'Unable to parse SpaceTrack response';
use constant INVALID_CATALOG =>
	'Catalog name %s invalid. Legal names are %s.';
use constant LOGIN_FAILED => 'Login failed';
use constant NO_CREDENTIALS => 'Username or password not specified.';
use constant NO_CAT_ID => 'No catalog IDs specified.';
use constant NO_OBJ_NAME => 'No object name specified.';
use constant NO_RECORDS => 'No records found.';

use constant SESSION_PATH => '/';
use constant SESSION_KEY => 'spacetrack_session';

my %catalogs = (	# Catalog names (and other info) for each source.
    celestrak => {
	sts => {name => 'Current Space Shuttle Mission (if any)'},
	'tle-new' => {name => "Last 30 Days' Launches"},
	stations => {name => 'International Space Station'},
	visual => {name => '100 (or so) brightest'},
	weather => {name => 'Weather'},
	noaa => {name => 'NOAA'},
	goes => {name => 'GOES'},
	resource => {name => 'Earth Resources'},
	sarsat => {name => 'Search and Rescue (SARSAT)'},
	dmc => {name => 'Disaster Monitoring'},
	tdrss => {name => 'Tracking and Data Relay Satellite System (TDRSS)'},
	geo => {name => 'Geostationary'},
	intelsat => {name => 'Intelsat'},
	gorizont => {name => 'Gorizont'},
	raduga => {name => 'Raduga'},
	molniya => {name => 'Molniya'},
	iridium => {name => 'Iridium'},
	orbcomm => {name => 'Orbcomm'},
	globalstar => {name => 'Globalstar'},
	amateur => {name => 'Amateur Radio'},
	'x-comm' => {name => 'Experimental Communications'},
	'other-comm' => {name => 'Other communications'},
	'gps-ops' => {name => 'GPS Operational'},
	'glo-ops' => {name => 'Glonass Operational'},
	galileo => {name => 'Galileo'},
	sbas => {name =>
	    'Satellite-Based Augmentation System (WAAS/EGNOS/MSAS)'},
	nnss => {name => 'Navy Navigation Satellite System (NNSS)'},
	musson => {name => 'Russian LEO Navigation'},
	science => {name => 'Space and Earth Science'},
	geodetic => {name => 'Geodetic'},
	engineering => {name => 'Engineering'},
	education => {name => 'Education'},
	military => {name => 'Miscellaneous Military'},
	radar => {name => 'Radar Calibration'},
	cubesat => {name => 'CubeSats'},
	other => {name => 'Other'},
    },
    iridium_status => {
	kelso => {name => 'Celestrak (Kelso)'},
	mccants => {name => 'McCants'},
	sladen => {name => 'Sladen'},
    },
    spaceflight => {
	iss => {name => 'International Space Station',
	    url => 'http://spaceflight.nasa.gov/realdata/sightings/SSapplications/Post/JavaSSOP/orbit/ISS/SVPOST.html',
	},
	shuttle => {name => 'Current shuttle mission',
	    url => 'http://spaceflight.nasa.gov/realdata/sightings/SSapplications/Post/JavaSSOP/orbit/SHUTTLE/SVPOST.html',
	},
    },
    spacetrack => {
	md5 => {name => 'MD5 checksums', number => 0, special => 1},
	full => {name => 'Full catalog', number => 1},
	geosynchronous => {name => 'Geosynchronous satellites', number => 3},
	navigation => {name => 'Navigation satellites', number => 5},
	weather => {name => 'Weather satellites', number => 7},
	iridium => {name => 'Iridium satellites', number => 9},
	orbcomm => {name => 'OrbComm satellites', number => 11},
	globalstar => {name => 'Globalstar satellites', number => 13},
	intelsat => {name => 'Intelsat satellites', number => 15},
	inmarsat => {name => 'Inmarsat satellites', number => 17},
	amateur => {name => 'Amateur Radio satellites', number => 19},
	visible => {name => 'Visible satellites', number => 21},
	special => {name => 'Special satellites', number => 23},
    },
);

my %mutator = (	# Mutators for the various attributes.
    addendum => \&_mutate_attrib,		# Addendum to banner text.
    banner => \&_mutate_attrib,
    cookie_expires => \&_mutate_attrib,
    debug_url => \&_mutate_attrib,	# Force the URL. Undocumented and unsupported.
    direct => \&_mutate_attrib,
    domain_space_track => \&_mutate_authen,
    dump_headers => \&_mutate_attrib,	# Dump all HTTP headers. Undocumented and unsupported.
    fallback => \&_mutate_attrib,
    filter => \&_mutate_attrib,
    iridium_status_format => \&_mutate_iridium_status_format,
    max_range => \&_mutate_number,
    password => \&_mutate_authen,
    session_cookie => \&_mutate_cookie,
    url_iridium_status_kelso => \&_mutate_attrib,
    url_iridium_status_mccants => \&_mutate_attrib,
    url_iridium_status_sladen => \&_mutate_attrib,
    username => \&_mutate_authen,
    verbose => \&_mutate_attrib,
    webcmd => \&_mutate_attrib,
    with_name => \&_mutate_attrib,
);
# Maybe I really want a cookie_file attribute, which is used to do
# $self->{agent}->cookie_jar ({file => $self->{cookie_file}, autosave => 1}).
# We'll want to use a false attribute value to pass an empty hash. Going to
# this may imply modification of the new () method where the cookie_jar is
# defaulted and the session cookie's age is initialized.


=item $st = Astro::SpaceTrack->new ( ... )

=for html <a name="new"></a>

This method instantiates a new Space-Track accessor object. If any
arguments are passed, the set () method is called on the new object,
and passed the arguments given.

Proxies are taken from the environment if defined. See the ENVIRONMENT
section of the Perl LWP documentation for more information on how to
set these up.

=cut

sub new {
    my ($class, @args) = @_;
    $class = ref $class if ref $class;

    my $self = {
	agent => LWP::UserAgent->new (),
	banner => 1,	# shell () displays banner if true.
	cookie_expires => 0,
	debug_url => undef,	# Not turned on
	direct => 0,	# Do not direct-fetch from redistributors
	domain_space_track => 'www.space-track.org',
	dump_headers => 0,	# No dumping.
	fallback => 0,	# Do not fall back if primary source offline
	filter => 0,	# Filter mode.
	iridium_status_format => 'mccants',	# For historical reasons.
	max_range => 500,	# Sanity limit on range size.
	password => undef,	# Login password.
	session_cookie => undef,
	url_iridium_status_kelso =>
	    'http://celestrak.com/SpaceTrack/query/iridium.txt',
	url_iridium_status_mccants =>
	    'http://www.io.com/~mmccants/tles/iridium.html',
	url_iridium_status_sladen =>
	    'http://www.rod.sladen.org.uk/iridium.htm',
	username => undef,	# Login username.
	verbose => undef,	# Verbose error messages for catalogs.
	webcmd => undef,	# Command to get web help.
	with_name => undef,	# True to retrieve three-line element sets.
    };
    bless $self, $class;

    $self->{agent}->env_proxy;

    $ENV{SPACETRACK_OPT} and
	$self->set (grep {defined $_} split '\s+', $ENV{SPACETRACK_OPT});

    $ENV{SPACETRACK_USER} and do {
	my ($user, $pass) = split '/', $ENV{SPACETRACK_USER}, 2;
	$self->set (username => $user, password => $pass);
    };

    @args and $self->set (@args);

    $self->{agent}->cookie_jar ({})
	unless $self->{agent}->cookie_jar;

    $self->_check_cookie ();

    return $self;
}

=for html <a name="amsat"></a>

=item $resp = $st->amsat ()

This method downloads current orbital elements from the Radio Amateur
Satellite Corporation's web page, L<http://www.amsat.org/>. This lists
satellites of interest to radio amateurs, and appears to be updated
weekly.

No Space Track account is needed to access this data, even if the
'direct' attribute is false. But if the 'direct' attribute is true,
the setting of the 'with_name' attribute is ignored. On a successful
return, the response object will contain headers

 Pragma: spacetrack-type = orbit
 Pragma: spacetrack-source = amsat

These can be accessed by C<< $st->content_type( $resp ) >> and
C<< $st->content_source( $resp ) >> respectively.

This method is a web page scraper. any change in the location of the
web page will break this method.

=cut

sub amsat {
    my $self = shift;
    delete $self->{_pragmata};
    my $content = '';
    foreach my $url (
	'http://www.amsat.org/amsat/ftp/keps/current/nasabare.txt',
    ) {
	my $resp = $self->{agent}->get ($url);
	return $resp unless $resp->is_success;
	$self->_dump_headers( $resp );
	my @data;
	foreach (split '\n', $resp->content) {
	    push @data, "$_\n";
	    @data == 3 or next;
	    shift @data unless $self->{direct} || $self->{with_name};
	    $content .= join '', @data;
	    @data = ();
	}
    }

    $content or
	return HTTP::Response->new (RC_PRECONDITION_FAILED, NO_CAT_ID);

    my $resp = HTTP::Response->new (RC_OK, undef, undef, $content);
    $self->_add_pragmata($resp,
	'spacetrack-type' => 'orbit',
	'spacetrack-source' => 'amsat',
    );
    $self->_dump_headers( $resp );
    return $resp;
}

=item @names = $st->attribute_names

This method returns a list of legal attribute names.

=cut

sub attribute_names {
    return wantarray ? sort keys %mutator : [sort keys %mutator]
}


=for html <a name="banner"></a>

=item $resp = $st->banner ();

This method is a convenience/nuisance: it simply returns a fake
HTTP::Response with standard banner text. It's really just for the
benefit of the shell method.

=cut

{
    my $perl_version;

    sub banner {
	my $self = shift;
	$perl_version ||= do {
	    $] >= 5.01 ? $^V : do {
		require Config;
		'v' . $Config::Config{version};	## no critic (ProhibitPackageVars)
	    }
	};
	return HTTP::Response->new (RC_OK, undef, undef, <<"EOD");

@{[__PACKAGE__]} version $VERSION
Perl $perl_version under $^O

This package acquires satellite orbital elements and other data from a
variety of web sites. It is your responsibility to abide by the terms of
use of the individual web sites. In particular, to acquire data from
Space Track (http://$self->{domain_space_track}/) you must register and
get a username and password, and you may not make the data available to
a third party without prior permission from Space Track.

Copyright 2005-2011 by T. R. Wyant (wyant at cpan dot org).

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.
@{[$self->{addendum} || '']}
EOD
    }

}

=for html <a name="box_score"></a>

=item $resp = $st->box_score ();

This method returns the SATCAT Satellite Box Score information from the
Space Track web site. If it succeeds, the content will be the actual box
score data, including headings and totals, with the fields
tab-delimited.

This method requires a Space Track username and password. It implicitly
calls the login () method if the session cookie is missing or expired.
If login () fails, you will get the HTTP::Response from login ().

If this method succeeds, the response will contain headers

 Pragma: spacetrack-type = box_score
 Pragma: spacetrack-source = spacetrack

There are no options or arguments.

=cut

sub box_score {
    my ( $self ) = @_;

    my $p = Astro::SpaceTrack::Parser->new ();

    my $resp = $self->_post ( 'perl/boxscore.pl' );
    $resp->is_success()
	and not $self->{debug_url}
	or return $resp;

    my $content = $resp->content;
    $content =~ s/ &nbsp; / /smxg;
    my @this_page = @{$p->parse_string (table => $content)};
    ref $this_page[0] eq 'ARRAY'
	or return HTTP::Response->new (RC_INTERNAL_SERVER_ERROR,
	BAD_SPACETRACK_RESPONSE, undef, $content);
    my @data = @{$this_page[0]};
    $content = '';
    my $line = 0;
    foreach my $datum ( @data ) {
	if ( $line++ == 1 ) {
	    foreach ( @{ $datum } ) {
		s/ \s* [(] key [)] \s* \z //smxi;
	    }
	}
	$content .= join( "\t", @{ $datum } ) . "\n";
    }
    $resp = HTTP::Response->new (RC_OK, undef, undef, $content);
    $self->_add_pragmata($resp,
	'spacetrack-type' => 'box_score',
	'spacetrack-source' => 'spacetrack',
    );
    return wantarray ? ($resp, \@data) : $resp;
}


=for html <a name="celestrak"></a>

=item $resp = $st->celestrak ($name);

This method takes the name of a Celestrak data set and returns an
HTTP::Response object whose content is the relevant element sets.
If called in list context, the first element of the list is the
aforementioned HTTP::Response object, and the second element is a
list reference to list references  (i.e. a list of lists). Each
of the list references contains the catalog ID of a satellite or
other orbiting body and the common name of the body.

If the C<direct> attribute is true, or if the C<fallback> attribute is
true and the data are not available from Space Track, the elements will
be fetched directly from Celestrak, and no login is needed. Otherwise,
this method implicitly calls the login () method if the session cookie
is missing or expired, and returns the SpaceTrack data for the OIDs
fetched from Celestrak. If login () fails, you will get the
HTTP::Response from login ().

A list of valid names and brief descriptions can be obtained by calling
C<< $st->names ('celestrak') >>. If you have set the C<verbose> attribute true
(e.g. C<< $st->set (verbose => 1) >>), the content of the error response will
include this list. Note, however, that this list does not determine what
can be retrieved; if Dr.  Kelso adds a data set, it can be retrieved
even if it is not on the list, and if he removes one, being on the list
won't help.

In general, the data set names are the same as the file names given at
L<http://celestrak.com/NORAD/elements/>, but without the '.txt' on the
end; for example, the name of the 'International Space Station' data set
is 'stations', since the URL for this is
L<http://celestrak.com/NORAD/elements/stations.txt>.

The Celestrak web site makes a few items available for direct-fetching
only (C<< $st->set(direct => 1) >>, see below.) These are typically
debris from collisions or explosions. I have not corresponded with Dr.
Kelso on this, but I think it reasonable to believe that asking Space
Track for a couple thousand sets of data at once would not be a good
thing.

As of this release, the following data sets may be direct-fetched only:

=over

=item 1999-025

This is the debris of Chinese communication satellite Fengyun 1C,
created by an antisatellite test on January 11 2007. As of February 21
2010 there are 2631 pieces of debris in the data set. This is an
increase from the 2375 recorded on March 9 2009.

=item usa-193-debris

This is the debris of U.S. spy satellite USA-193 shot down by the U.S.
on February 20 2008. As of February 21 2010 there are no pieces of
debris in the data set. I noted 1 piece on March 9 2009, but this was an
error - that piece actually decayed October 9 2008, but I misread the
data. The maximum was 173. Note that as of February 21 2010 you still
get the remaining piece when you direct-fetch the data from Celestrak.

=item cosmos-2251-debris

This is the debris of Russian communication satellite Cosmos 2251,
created by its collision with Iridium 33 on February 10 2009. As of
February 21 2010 there are 1105 pieces of debris in the data set, up
from the 357 that had been cataloged as of March 9 2009.

=item iridium-33-debris

This is the debris of U.S. communication satellite Iridium 33, created
by its collision with Cosmos 2251 on February 10 2009. As of February 21
2010 there are 461 pieces of debris in the data set, up from the 159
that had been cataloged as of March 9 2009.

=back

The data set for the current US Space Shuttle Mission (if any) will be
available as data set 'sts'. If there is no current mission, you will
get a 404 error with text "Missing Celestrak catalog 'sts'." Since the
data ultimately come from NORAD, the shuttle will have to be up and
actually tracked by NORAD before this is available.

If this method succeeds, the response will contain headers

 Pragma: spacetrack-type = orbit
 Pragma: spacetrack-source = 

The spacetrack-source will be C<'spacetrack'> if the TLE data actually
came from Space Track, or C<'celestrak'> if the TLE data actually came
from Celestrak. The former will be the case if the C<direct> attribute
is false and either the C<fallback> attribute was false or the Space
Track web site was accessible. Otherwise, the latter will be the case.

These can be accessed by C<< $st->content_type( $resp ) >> and
C<< $st->content_source( $resp ) >> respectively.

You can specify the L</retrieve> options on this method as well, but
they will have no effect if the 'direct' attribute is true.

=cut

sub celestrak {
    my ($self, @args) = @_;
    delete $self->{_pragmata};

    @args = _parse_retrieve_args( @args );
    my $opt = shift @args;

    my $name = shift @args;
    $self->{direct}
	and return $self->_celestrak_direct ($opt, $name);
    my $resp = $self->{agent}->get (
	"http://celestrak.com/SpaceTrack/query/$name.txt");
    if (my $check = $self->_celestrak_response_check($resp, $name)) {
	return $check;
    }
    $self->_convert_content ($resp);
    $self->_dump_headers( $resp );
    $resp = $self->_handle_observing_list ($opt, $resp->content);
    return ($resp->is_success || !$self->{fallback}) ? $resp :
	$self->_celestrak_direct ($opt, $name);
}

sub _celestrak_direct {
    my ($self, @args) = @_;
    delete $self->{_pragmata};

    @args = _parse_retrieve_args( @args );
##  my $opt = shift @args;
    shift @args;	# $opt not used
    my $name = shift @args;
    my $resp = $self->{agent}->get (
	"http://celestrak.com/NORAD/elements/$name.txt");
    if (my $check = $self->_celestrak_response_check($resp, $name, 'direct')) {
	return $check;
    }
    $self->_convert_content ($resp);
    if ($name eq 'iridium') {
	_celestrak_repack_iridium( $resp );
    }
    $self->_add_pragmata($resp,
	'spacetrack-type' => 'orbit',
	'spacetrack-source' => 'celestrak',
    );
    $self->_dump_headers( $resp );
    return $resp;
}

sub _celestrak_repack_iridium {
    my ( $resp ) = @_;
    my @content;
    foreach ( split qr{ \n }smx, $resp->content() ) {
	s/ \s+ [[] . []] \s* \z //smx;
	push @content, $_;
    }
    $resp->content( join "\n", @content );
    return;
}

{	# Local symbol block.

    my %valid_type = ('text/plain' => 1, 'text/text' => 1);

    sub _celestrak_response_check {
	my ($self, $resp, $name, @args) = @_;
	unless ($resp->is_success) {
	    $resp->code == RC_NOT_FOUND
		and return $self->_no_such_catalog(
		celestrak => $name, @args);
	    return $resp;
	}
	if (my $loc = $resp->header('Content-Location')) {
	    if ($loc =~ m/ redirect [.] htm [?] ( \d{3} ) ; /smx) {
		my $msg = "redirected $1";
		@args and $msg = "@args; $msg";
		$1 == RC_NOT_FOUND
		    and return $self->_no_such_catalog(
		    celestrak => $name, $msg);
		return HTTP::Response->new (+$1, "$msg\n")
	    }
	}
	my $type = lc $resp->header('Content-Type')
	    or do {
	    my $msg = 'No Content-Type header found';
	    @args and $msg = "@args; $msg";
	    return $self->_no_such_catalog(
		celestrak => $name, $msg);
	};
	foreach ( _trim( split ',', $type ) ) {
	    s/ ; .* //smx;
	    $valid_type{$_} and return;
	}
	my $msg = "Content-Type: $type";
	@args and $msg = "@args; $msg";
	return $self->_no_such_catalog(
	    celestrak => $name, $msg);
    }

}	# End local symbol block.

=item $source = $st->content_source($resp);

This method takes the given HTTP::Response object and returns the data
source specified by the 'Pragma: spacetrack-source =' header. What
values you can expect depend on the content_type (see below) as follows:

If the C<content_type()> method returns C<'box_score'>, you can expect
a content-source value of C<'spacetrack'>.

If the content_type method returns C<'iridium-status'>, you can expect
content_source values of C<'kelso'>, C<'mccants'>, or C<'sladen'>,
corresponding to the main source of the data.

If the C<content_type()> method returns C<'orbit'>, you can expect
content-source values of C<'amsat'>, C<'celestrak'>, C<'spaceflight'>,
or C<'spacetrack'>, corresponding to the actual source of the TLE data.
Note that the C<celestrak()> method may return a content_type of
C<'spacetrack'> if the C<direct> attribute is false.

If the C<content_type()> method returns C<'search'>, you can expect a
content-source value of C<'spacetrack'>.

For any other values of content-type (e.g. C<'get'>, C<'help'>), the
expected values are undefined.  In fact, you will probably literally get
undef, but the author does not commit even to this.

If the response object is not provided, it returns the data source
from the last method call that returned an HTTP::Response object.

If the response object B<is> provided, you can call this as a static
method (i.e. as Astro::SpaceTrack->content_source($response)).

=cut

sub content_source {
    my ($self, $resp) = @_;
    defined $resp or return $self->{_pragmata}{'spacetrack-source'};
    foreach ($resp->header ('Pragma')) {
	m/ spacetrack-source \s+ = \s+ (.+) /smxi and return $1;
    }
    return;
}

=item $type = $st->content_type ($resp);

This method takes the given HTTP::Response object and returns the
data type specified by the 'Pragma: spacetrack-type =' header. The
following values are supported:

 'box_score': The content is the Space Track satellite
         box score.
 'get': The content is a parameter value.
 'help': The content is help text.
 'orbit': The content is NORAD data sets.
 'search': The content is Space Track search results.
 undef: No spacetrack-type pragma was specified. The
        content is something else (typically 'OK').

If the response object is not provided, it returns the data type
from the last method call that returned an HTTP::Response object.

If the response object B<is> provided, you can call this as a static
method (i.e. as Astro::SpaceTrack->content_type($response)).

=cut

sub content_type {
    my ($self, $resp) = @_;
    defined $resp or return $self->{_pragmata}{'spacetrack-type'};
    foreach ($resp->header ('Pragma')) {
	m/ spacetrack-type \s+ = \s+ (.+) /smxi and return $1;
    }
    return;
}


=for html <a name="file"></a>

=item $resp = $st->file ($name)

This method takes the name of an observing list file, or a handle to an
open observing list file, and returns an HTTP::Response object whose
content is the relevant element sets, retrieved from the Space Track web
site. If called in list context, the first element of the list is the
aforementioned HTTP::Response object, and the second element is a list
reference to list references  (i.e.  a list of lists). Each of the list
references contains the catalog ID of a satellite or other orbiting body
and the common name of the body.

This method requires a Space Track username and password. It implicitly
calls the login () method if the session cookie is missing or expired.
If login () fails, you will get the HTTP::Response from login ().

The observing list file is (how convenient!) in the Celestrak format,
with the first five characters of each line containing the object ID,
and the rest containing a name of the object. Lines whose first five
characters do not look like a right-justified number will be ignored.

If this method succeeds, the response will contain headers

 Pragma: spacetrack-type = orbit
 Pragma: spacetrack-source = spacetrack

These can be accessed by C<< $st->content_type( $resp ) >> and
C<< $st->content_source( $resp ) >> respectively.

You can specify the L</retrieve> options on this method as well.

=cut

sub file {
    my ($self, @args) = @_;
    @args = _parse_retrieve_args( @args );
    my $opt = shift @args;

    delete $self->{_pragmata};
    my $name = shift @args;
    ref $name and fileno ($name)
	and return $self->_handle_observing_list (<$name>);
    -e $name or return HTTP::Response->new (
	RC_NOT_FOUND, "Can't find file $name");
    my $fh = IO::File->new($name, '<') or
	return HTTP::Response->new (
	    RC_INTERNAL_SERVER_ERROR, "Can't open $name: $!");
    local $/ = undef;
    return $self->_handle_observing_list ($opt, <$fh>)
}


=for html <a name="get"></a>

=item $resp = $st->get (attrib)

B<This method returns an HTTP::Response object> whose content is the value
of the given attribute. If called in list context, the second element
of the list is just the value of the attribute, for those who don't want
to winkle it out of the response object. We croak on a bad attribute name.

If this method succeeds, the response will contain header

 Pragma: spacetrack-type = get

This can be accessed by C<< $st->content_type( $resp ) >>.

See L</Attributes> for the names and functions of the attributes.

=cut

sub get {
    my ( $self, $name ) = @_;
    delete $self->{_pragmata};
    my $value = $self->getv( $name );
    my $resp = HTTP::Response->new( RC_OK, undef, undef, $value );
    $self->_add_pragmata( $resp,
	'spacetrack-type' => 'get',
    );
    $self->_dump_headers( $resp );
    return wantarray ? ($resp, $value ) : $resp;
}


=for html <a name="getv"></a>

=item $value = $st->getv (attrib)

This method returns the value of the given attribute, which is what
C<get()> should have done.

See L</Attributes> for the names and functions of the attributes.

=cut

sub getv {
    my ( $self, $name ) = @_;
    defined $name
	or croak 'No attribute name specified',
    $mutator{$name}
	or croak "No such attribute as '$name'";
    return $self->{$name};
}


=for html <a name="help"></a>

=item $resp = $st->help ()

This method exists for the convenience of the shell () method. It
always returns success, with the content being whatever it's
convenient (to the author) to include.

If the L<webcmd|/webcmd> attribute is set, the L<http://search.cpan.org/>
web page for this version of Astro::Satpass is launched.

If this method succeeds B<and> the webcmd attribute is not set, the
response will contain header

 Pragma: spacetrack-type = help

This can be accessed by C<< $st->content_type( $resp ) >>.

Otherwise (i.e. in any case where the response does B<not> contain
actual help text) this header will be absent.

=cut

sub help {
    my $self = shift;
    delete $self->{_pragmata};
    if ($self->{webcmd}) {
	system (join ' ', $self->{webcmd},
	    "http://search.cpan.org/~wyant/Astro-SpaceTrack-$VERSION/");
	return HTTP::Response->new (RC_OK, undef, undef, 'OK');
    } else {
	my $resp = HTTP::Response->new (RC_OK, undef, undef, <<'EOD');
The following commands are defined:
  box_score
    Retrieve the SATCAT box score. A Space Track login is needed.
  celestrak name
    Retrieves the named catalog of IDs from Celestrak. If the
    direct attribute is false (the default), the corresponding
    orbital elements come from Space Track. If true, they come
    from Celestrak, and no login is needed.
  exit (or bye)
    Terminate the shell. End-of-file also works.
  file filename
    Retrieve the catalog IDs given in the named file (one per
    line, with the first five characters being the ID).
  get
    Get the value of a single attribute.
  help
    Display this help text.
  iridium_status
    Status of Iridium satellites, from Mike McCants or Rod Sladen and/or
    T. S. Kelso.
  login
    Acquire a session cookie. You must have already set the
    username and password attributes. This will be called
    implicitly if needed by any method that accesses data.
  names source
    Lists the catalog names from the given source.
  retrieve number ...
    Retieves the latest orbital elements for the given
    catalog numbers.
  search_date date ...
    Retrieves orbital elements by launch date.
  search_decay date ...
    Retrieves orbital elements by decay date.
  search_id id ...
    Retrieves orbital elements by international designator.
  search_name name ...
    Retrieves orbital elements by satellite common name.
  set attribute value ...
    Sets the given attributes. Legal attributes are
      addendum = extra text for the shell () banner;
      banner = false to supress the shell () banner;
      cookie_expires = Perl date the session cookie expires;
      debug_url = Override canned url for debugging - do not
        set this in normal use;
      direct = true to fetch orbital elements directly
        from a redistributer. Currently this only affects the
        celestrak() method. The default is false.
      dump_headers is unsupported, and intended for debugging -
        don't be suprised at anything it does, and don't rely
        on anything it does;
      filter = true supresses all output to stdout except
        orbital elements;
      max_range = largest range of numbers that can be re-
        trieved (default: 500);
      password = the Space-Track password;
      session_cookie = the text of the session cookie;
      username = the Space-Track username;
      verbose = true for verbose catalog error messages;
      webcmd = command to launch a URL (for web-based help);
      with_name = true to retrieve common names as well.
    The session_cookie and cookie_expires attributes should
    only be set to previously-retrieved, matching values.
  source filename
    Executes the contents of the given file as shell commands.
  spaceflight
    Retrieves orbital elements from http://spaceflight.nasa.gov/.
    No login needed, but you get at most the ISS and the current
    shuttle mission.
  spacetrack name
    Retrieves the named catalog of orbital elements from
    Space Track.
The shell supports a pseudo-redirection of standard output,
using the usual Unix shell syntax (i.e. '>output_file').
EOD
	$self->_add_pragmata($resp,
	    'spacetrack-type' => 'help',
	);
	$self->_dump_headers( $resp );
	return $resp;
    }
}


=for html <a name="iridium_status"></a>

=item $resp = $st->iridium_status ($format);

This method queries its sources of Iridium status, returning an
HTTP::Response object containing the relevant data (if all queries
succeeded) or the status of the first failure. If the queries succeed,
the content is a series of lines formatted by "%6d   %-15s%-8s %s\n",
with NORAD ID, name, status, and comment substituted in.

No Space Track username and password are required to use this method.

If this method succeeds, the response will contain headers

 Pragma: spacetrack-type = iridium_status
 Pragma: spacetrack-source = 

The spacetrack-source will be 'kelso', 'mccants', or 'sladen', depending
on the format requested.

These can be accessed by C<< $st->content_type( $resp ) >> and
C<< $st->content_source( $resp ) >> respectively.

The source of the data and, to a certain extent, the format of the
results is determined by the optional $format argument, which defaults
to the value of the L</iridium_status_format> attribute.

If the format is 'kelso', only Dr. Kelso's Celestrak web site
(L<http://celestrak.com/SpaceTrack/query/iridium.txt>) is queried for
the data. The possible status values are:

    '[S]' - Spare;
    '[-]' - Tumbling (or otherwise unservicable);
    '[+]' - In service and able to produce predictable flares.

The comment will be 'Spare', 'Tumbling', or '' depending on the status.

If the format is 'mccants', the primary source of information will be
Mike McCants' "Status of Iridium Payloads" web page,
L<http://www.io.com/~mmccants/tles/iridium.html> (which gives status on
non-functional Iridium satellites). The Celestrak list will be used to
fill in the functioning satellites so that a complete list is generated.
The comment will be whatever text is provided by Mike McCants' web page,
or 'Celestrak' if the satellite data came from that source.

As of 03-Dec-2010 Mike's web page documented the possible statuses as
follows:

 blank   Object is operational
 tum     tumbling - no flares, but flashes seen on favorable
         transits.
 unc     uncontrolled
 ?       controlled, but not at operational altitude -
         flares may be unreliable.
 man     maneuvering, at least slightly. Flares may be
	 unreliable and the object may be early or late
         against prediction.

In addition, the data from Celestrak may contain the following
status:

 'dum' - Dummy mass

A blank status indicates that the satellite is in service and
therefore capable of producing flares.

If the format is 'sladen', the primary source of information will be Rod
Sladen's "Iridium Constellation Status" web page,
L<http://www.rod.sladen.org.uk/iridium.htm>, which gives status on all
Iridium satellites, but no OID. The Celestrak list will be used to
provide OIDs for Iridium satellite numbers, so that a complete list is
generated. Mr. Sladen's page simply lists operational and failed
satellites in each plane, so this software imposes Kelso-style statuses
on the data. That is to say, operational satellites will be marked
'[+]', spares will be marked '[S]', and failed satellites will be
marked '[-]', with the corresponding portable statuses. As of version
0.035, all failed satellites will be marked '[-]'. Previous to this
release, failed satellites not specifically marked as tumbling were
considered spares.

The comment field in 'sladen' format data will contain the orbital plane
designation for the satellite, 'Plane n' with 'n' being a number from 1
to 6. If the satellite is failed but not tumbling, the text ' - Failed
on station?' will be appended to the comment. The dummy masses will be
included from the Kelso data, with status '[-]' but comment 'Dummy'.

If the method is called in list context, the first element of the
returned list will be the HTTP::Response object, and the second
element will be a reference to a list of anonymous lists, each
containing [$id, $name, $status, $comment, $portable_status] for
an Iridium satellite. The portable statuses are:

  0 = BODY_STATUS_IS_OPERATIONAL means object is operational
  1 = BODY_STATUS_IS_SPARE means object is a spare
  2 = BODY_STATUS_IS_TUMBLING means object is tumbling
      or otherwise unservicable.

The correspondence between the Kelso statuses and the portable statuses
is pretty much one-to-one. In the McCants statuses, '?' identifies a
spare, '+' identifies an in-service satellite, and anything else is
considered to be tumbling.

The BODY_STATUS constants are exportable using the :status tag.

=cut

{	# Begin local symbol block.

    use constant BODY_STATUS_IS_OPERATIONAL => 0;

    use constant BODY_STATUS_IS_SPARE => 1;
    use constant BODY_STATUS_IS_TUMBLING => 2;

    my %kelso_comment = (	# Expand Kelso status.
	'[S]' => 'Spare',
	'[-]' => 'Tumbling',
	);
    my %status_map = (	# Map Kelso status to McCants status.
	kelso => {
	    mccants => {
		'[S]' => '?',	# spare
		'[-]' => 'tum',	# tumbling
		'[+]' => '',	# operational
		},
	    },
	);
    my %status_portable = (	# Map statuses to portable.
	kelso => {
	    ''	=> BODY_STATUS_IS_OPERATIONAL,
	    '[-]' => BODY_STATUS_IS_TUMBLING,
	    '[S]' => BODY_STATUS_IS_SPARE,
	    '[+]' => BODY_STATUS_IS_OPERATIONAL,
	},
	mccants => {
	    '' => BODY_STATUS_IS_OPERATIONAL,
	    '?' => BODY_STATUS_IS_SPARE,
	    'dum' => BODY_STATUS_IS_TUMBLING,
	    'man' => BODY_STATUS_IS_TUMBLING,
	    'tum' => BODY_STATUS_IS_TUMBLING,
	    'tum?' => BODY_STATUS_IS_TUMBLING,
	},
#	sladen => undef,	# Not needed; done programmatically.
    );
    while (my ($key, $val) = each %{$status_portable{kelso}}) {
	$key and $status_portable{kelso_inverse}{$val} = $key;
    }

    sub iridium_status {
	my $self = shift;
	my $fmt = shift || $self->{iridium_status_format};
	delete $self->{_pragmata};
	my %rslt;
	my $resp = $self->_iridium_status_kelso( $fmt, \%rslt );
	$resp->is_success() or return $resp;
	if ($fmt eq 'mccants') {
	    ( $resp = $self->_iridium_status_mccants( $fmt, \%rslt ) )
		->is_success() or return $resp;
	} elsif ($fmt eq 'sladen') {
	    ( $resp = $self->_iridium_status_sladen( $fmt, \%rslt ) )
		->is_success() or return $resp;
	}
	$resp->content (join '', map {
		sprintf "%6d   %-15s%-8s %s\n", @{$rslt{$_}}}
	    sort {$a <=> $b} keys %rslt);
	$self->_add_pragmata($resp,
	    'spacetrack-type' => 'iridium-status',
	    'spacetrack-source' => $fmt,
	);
	$self->_dump_headers( $resp );
	return wantarray ? ($resp, [values %rslt]) : $resp;
    }

    # Get Iridium data from Celestrak.
    sub _iridium_status_kelso {
	my ( $self, $fmt, $rslt ) = @_;
	my $resp = $self->{agent}->get(
	    $self->getv( 'url_iridium_status_kelso' )
	);
	$resp->is_success or return $resp;
	foreach my $buffer (split '\n', $resp->content) {
	    $buffer =~ s/ \s+ \z //smx;
	    my $id = substr ($buffer, 0, 5) + 0;
	    my $name = substr ($buffer, 5);
	    my $status = '';
	    $name =~ s/ \s+ ( [[] .+? []] ) \s* \z //smx
		and $status = $1;
	    my $portable_status = $status_portable{kelso}{$status};
	    my $comment;
	    if ($fmt eq 'kelso' || $fmt eq 'sladen') {
		$comment = $kelso_comment{$status} || '';
		}
	      else {
		$status = $status_map{kelso}{$fmt}{$status} || '';
		$status = 'dum' unless $name =~ m/ \A IRIDIUM /smxi;
		$comment = 'Celestrak';
		}
	    $name = ucfirst lc $name;
	    $rslt->{$id} = [ $id, $name, $status, $comment,
		$portable_status ];
	}
	return $resp;
    }

    # Get Iridium status from Mike McCants
    sub _iridium_status_mccants {
	my ( $self, undef, $rslt ) = @_;	# $fmt arg not used
	my $resp = $self->{agent}->get(
	    $self->getv( 'url_iridium_status_mccants' )
	);
	$resp->is_success or return $resp;
	foreach my $buffer (split '\n', $resp->content) {
	    $buffer =~ m/ \A \s* (\d+) \s+ Iridium \s+ \S+ /smxi
		or next;
	    my ($id, $name, $status, $comment) = _trim(
		$buffer =~ m/ (.{8}) (.{0,15}) (.{0,9}) (.*) /smx
	    );
	    my $portable_status =
		exists $status_portable{mccants}{$status} ?
		    $status_portable{mccants}{$status} :
		    BODY_STATUS_IS_TUMBLING;
	    $rslt->{$id} = [ $id, $name, $status, $comment,
		$portable_status ];
#0         1         2         3         4         5         6         7
#01234567890123456789012345678901234567890123456789012345678901234567890
# 24836   Iridium 914    tum      Failed; was called Iridium 14
	}
	return $resp;
    }

    my %sladen_interpret_detail = (
	'' => sub {
	    my ( $rslt, $id, $name, $plane ) = @_;
	    $rslt->{$id} = [ $id, $name, '[-]',
		"$plane - Failed on station?",
		BODY_STATUS_IS_TUMBLING ];
	    return;
	},
	d => sub {
	    return;
	},
	t => sub {
	    my ( $rslt, $id, $name, $plane ) = @_;
	    $rslt->{$id} = [ $id, $name, '[-]', $plane,
		BODY_STATUS_IS_TUMBLING ];
	},
    );

    # Get Iridium status from Rod Sladen.
    sub _iridium_status_sladen {
	my ( $self, undef, $rslt ) = @_;	# $fmt arg not used

	my $resp = $self->{agent}->get(
	    $self->getv( 'url_iridium_status_sladen' )
	);
	$resp->is_success or return $resp;
	my %oid;
	my %dummy;
	foreach my $id (keys %{ $rslt } ) {
	    $rslt->{$id}[1] =~ m/ dummy /smxi and do {
		$dummy{$id} = $rslt->{$id};
		$dummy{$id}[3] = 'Dummy';
		next;
	    };
	    $rslt->{$id}[1] =~ m/ (\d+) /smx or next;
	    $oid{+$1} = $id;
	}
	%{ $rslt } = %dummy;

	my $fail;
	my $re = qr{ (\d+) }smx;
	local $_ = $resp->content;
####	s{ <em> .*? </em> }{}smxgi;	# Strip emphasis notes
	s/ < .*? > //smxg;	# Strip markup
	# Parenthesized numbers are assumed to represent tumbling
	# satellites in the in-service or spare grids.
	my %exception;
	{	## no critic (ProhibitUnusedCapture)
	    s< [(] (\d+) [)] >
		< $exception{$1} = BODY_STATUS_IS_TUMBLING; $1>smxge;
	}
	s/ [(] .*? [)] //smxg;	# Strip parenthetical comments
	foreach (split '\n', $_) {
	    if (m/ &lt; -+ \s+ failed \s+ -+ &gt; /smxi) {
		$fail++;
		$re = qr{ (\d+) (\w?) }smx;
	    } elsif ( s/ \A \s* ( plane \s+ \d+ ) \s* : \s* //smxi ) {
		my $plane = $1;
##		s/ \A \D+ //smx;	# Strip leading non-digits
		s/ \b [[:alpha:]] .* //smx;	# Strip trailing comments
		s/ \s+ \z //smx;		# Strip trailing whitespace
		my $inx = 0;	# First 11 functional are in service
		while (m/ $re /smxg) {
		    my $num = +$1;
		    my $detail = $2;
		    my $id = $oid{$num} or do {
#			This is normal for decayed satellites.
#			warn "No oid for Iridium $num\n";
			next;
		    };
		    my $name = "Iridium $num";
		    if ($fail) {
			my $interp = $sladen_interpret_detail{$detail}
			    || $sladen_interpret_detail{''};
			$interp->( $rslt, $id, $name, $plane );
		    } else {
			my $status = $inx++ > 10 ?
			    BODY_STATUS_IS_SPARE :
			    BODY_STATUS_IS_OPERATIONAL;
			exists $exception{$num}
			    and $status = $exception{$num};
			$rslt->{$id} = [ $id, $name,
			    $status_portable{kelso_inverse}{$status},
			    $plane, $status ];
		    }
		}
	    } elsif ( m/ Notes: /smx ) {
		last;
	    }
	}

	return $resp;
    }

}	# End of local symbol block.


=for html <a name="login"></a>

=item $resp = $st->login ( ... )

If any arguments are given, this method passes them to the set ()
method. Then it executes a login to the Space Track web site. The return
is normally the HTTP::Response object from the login. But if no session
cookie was obtained, the return is an HTTP::Response with an appropriate
message and the code set to RC_UNAUTHORIZED from HTTP::Status (a.k.a.
401). If a login is attempted without the username and password being
set, the return is an HTTP::Response with an appropriate message and the
code set to RC_PRECONDITION_FAILED from HTTP::Status (a.k.a. 412).

A Space Track username and password are required to use this method.

=cut

sub login {
    my ($self, @args) = @_;
    delete $self->{_pragmata};
    @args and $self->set (@args);
    ($self->{username} && $self->{password}) or
	return HTTP::Response->new (
	    RC_PRECONDITION_FAILED, NO_CREDENTIALS);
    $self->{dump_headers} and warn <<"EOD";
Logging in as $self->{username}.
EOD

    #	Do not use the _post method to retrieve the session cookie,
    #	unless you like bottomless recursions.
    my $resp = $self->{agent}->post (
	"http://$self->{domain_space_track}/perl/login.pl", [
	    username => $self->{username},
	    password => $self->{password},
	    _submitted => 1,
	    _sessionid => "",
	    ]);

    $resp->is_success or return $resp;
    $self->_dump_headers( $resp );

    $self->_check_cookie () > time ()
	or return HTTP::Response->new (RC_UNAUTHORIZED, LOGIN_FAILED);

    $self->{dump_headers} and warn <<'EOD';
Login successful.
EOD
    return HTTP::Response->new (RC_OK, undef, undef, "Login successful.\n");
}


=for html <a name="names"></a>

=item $resp = $st->names (source)

This method retrieves the names of the catalogs for the given source,
either 'celestrak', 'spacetrack', or 'iridium_status', in the content of
the given HTTP::Response object. In list context, you also get a
reference to a list of two-element lists; each inner list contains the
description and the catalog name, in that order (suitable for inserting
into a Tk Optionmenu).

No Space Track username and password are required to use this method,
since all it is doing is returning data kept by this module.

=cut

sub names {
    my $self = shift;
    delete $self->{_pragmata};
    my $name = lc shift;
    $catalogs{$name} or return HTTP::Response (
	    RC_NOT_FOUND, "Data source '$name' not found.");
    my $src = $catalogs{$name};
    my @list;
    foreach my $cat (sort keys %$src) {
	push @list, defined ($src->{$cat}{number}) ?
	    "$cat ($src->{$cat}{number}): $src->{$cat}{name}\n" :
	    "$cat: $src->{$cat}{name}\n";
    }
    my $resp = HTTP::Response->new (RC_OK, undef, undef, join ('', @list));
    return $resp unless wantarray;
    @list = ();
    foreach my $cat (sort {$src->{$a}{name} cmp $src->{$b}{name}}
	keys %$src) {
	push @list, [$src->{$cat}{name}, $cat];
    }
    return ($resp, \@list);
}


=for html <a name="retrieve"></a>

=item $resp = $st->retrieve (number_or_range ...)

This method retrieves the latest element set for each of the given
satellite ID numbers (also known as SATCAT IDs, NORAD IDs, or OIDs) from
The Space Track web site.  Non-numeric catalog numbers are ignored, as
are (at a later stage) numbers that do not actually represent a
satellite.

A Space Track username and password are required to use this method.

If this method succeeds, the response will contain headers

 Pragma: spacetrack-type = orbit
 Pragma: spacetrack-source = spacetrack

These can be accessed by C<< $st->content_type( $resp ) >> and
C<< $st->content_source( $resp ) >> respectively.

Number ranges are represented as 'start-end', where both 'start' and
'end' are catalog numbers. If 'start' > 'end', the numbers will be
taken in the reverse order. Non-numeric ranges are ignored.

You can specify options for the retrieval as either command-type
options (e.g. retrieve ('-last5', ...)) or as a leading hash reference
(e.g. retrieve ({last5 => 1}, ...)). If you specify the hash reference,
option names must be specified in full, without the leading '-', and
the argument list will not be parsed for command-type options. If you
specify command-type options, they may be abbreviated, as long as
the abbreviation is unique. Errors in either sort result in an
exception being thrown.

The legal options are:

 descending
   specifies the data be returned in descending order.
 end_epoch date
   specifies the end epoch for the desired data.
 last5
   specifies the last 5 element sets be retrieved.
   Ignored if start_epoch or end_epoch specified.
 start_epoch date
   specifies the start epoch for the desired data.
 sort type
   specifies how to sort the data. Legal types are
   'catnum' and 'epoch', with 'catnum' the default.

If you specify either start_epoch or end_epoch, you get data with
epochs at least equal to the start epoch, but less than the end
epoch (i.e. the interval is closed at the beginning but open at
the end). If you specify only one of these, you get a one-day
interval. Dates are specified either numerically (as a Perl date)
or as numeric year-month-day, punctuated by any non-numeric string.
It is an error to specify an end_epoch before the start_epoch.

If you are passing the options as a hash reference, you must specify
a value for the boolean options 'descending' and 'last5'. This value is
interpreted in the Perl sense - that is, undef, 0, and '' are false,
and anything else is true.

In order not to load the Space Track web site too heavily, data are
retrieved in batches of 50. Ranges will be subdivided and handled in
more than one retrieval if necessary. To limit the damage done by a
pernicious range, ranges greater than the max_range setting (which
defaults to 500) will be ignored with a warning to STDERR.

This method implicitly calls the login () method if the session cookie
is missing or expired. If login () fails, you will get the
HTTP::Response from login ().

If this method succeeds, a 'Pragma: spacetrack-type = orbit' header is
added to the HTTP::Response object returned.

=cut

use constant RETRIEVAL_SIZE => 50;

sub retrieve {
    my ($self, @args) = @_;
    delete $self->{_pragmata};

    @args = _parse_retrieve_args( @args );
    my $opt = _parse_retrieve_dates (shift @args);

    my @params = $opt->{start_epoch} ?
	(timeframe => 'timespan',
	    start_year => $opt->{start_epoch}[5] + 1900,
	    start_month => $opt->{start_epoch}[4] + 1,
	    start_day => $opt->{start_epoch}[3],
	    end_year => $opt->{end_epoch}[5] + 1900,
	    end_month => $opt->{end_epoch}[4] + 1,
	    end_day => $opt->{end_epoch}[3],
	) :
	$opt->{last5} ? (timeframe => 'last5') : (timeframe => 'latest');
    push @params, common_name => $self->{with_name} ? 'yes' : '';
    push @params, sort => $opt->{sort};
    push @params, descending => $opt->{descending} ? 'yes' : '';

    @args = grep { m/ \A \d+ (?: - \d+)? \z /smx } @args;

    @args or return HTTP::Response->new (RC_PRECONDITION_FAILED, NO_CAT_ID);
    my $content = '';
    local $_ = undef;
    my $resp;
    while (@args) {
	my @batch;
	my $ids = 0;
	while (@args && $ids < RETRIEVAL_SIZE) {
	    $ids++;
	    my ($lo, $hi) = split '-', shift @args;
	    $lo > 0 or defined $hi or next;
	    defined $hi and do {
		($lo, $hi) = ($hi, $lo) if $lo > $hi;
		$lo or $lo = 1;	# 0 is illegal
		$hi - $lo >= $self->{max_range} and do {
		    carp <<"EOD";
Warning - Range $lo-$hi ignored because it is greater than the
	  currently-set maximum of $self->{max_range}.
EOD
		    next;
		};
		$ids += $hi - $lo;
		$ids > RETRIEVAL_SIZE and do {
		    my $mid = $hi - $ids + RETRIEVAL_SIZE;
		    unshift @args, "@{[$mid + 1]}-$hi";
		    $hi = $mid;
		};
		$lo = "$lo-$hi" if $hi > $lo;
	    };
	    push @batch, $lo;
	}
	next unless @batch;
	$resp = $self->_post ('perl/id_query.pl',
	    ids => "@batch",
	    @params,
	    ascii => 'yes',		# or ''
	    _sessionid => '',
	    _submitted => 1,
	);
	return $resp unless $resp->is_success;
	$_ = $resp->content;
	next if m/ No \s records \s found /smxi;
	if ( m/ ERROR: /smx ) {
	    return HTTP::Response->new (RC_INTERNAL_SERVER_ERROR,
		"Failed to retrieve IDs @batch.\n",
		undef, $content);
	}
	s{ </pre> .* }{}smx;
	s{ .* <pre> }{}smx;
	s{ \A \n }{}smx;
	$content .= $_;
    }
    $content or return HTTP::Response->new (RC_NOT_FOUND, NO_RECORDS);
    $resp->content ($content);
    $self->_convert_content ($resp);
    $self->_add_pragmata($resp,
	'spacetrack-type' => 'orbit',
	'spacetrack-source' => 'spacetrack',
    );
    return $resp;
}


=for html <a name="search_date"></a>

=item $resp = $st->search_date (date ...)

This method searches the Space Track database for objects launched on
the given date. The date is specified as year-month-day, with any
non-digit being legal as the separator. You can omit -day or specify it
as 0 to get all launches for the given month. You can omit -month (or
specify it as 0) as well to get all launches for the given year.

A Space Track username and password are required to use this method.

You can specify options for the search as either command-type options
(e.g. C<< $st->search_date (-status => 'onorbit', ...) >>) or as a
leading hash reference (e.g.
C<< $st->search_date ({status => onorbit}, ...) >>). If you specify the
hash reference, option names must be specified in full, without the
leading '-', and the argument list will not be parsed for command-type
options.  Options that take multiple values (i.e. 'exclude') must have
their values specified as a hash reference, even if you only specify one
value - or none at all.

If you specify command-type options, they may be abbreviated, as long as
the abbreviation is unique. Errors in either sort of specification
result in an exception being thrown.

In addition to the options available for L</retrieve>, the following
options may be specified:

 exclude
   specifies the types of bodies to exclude. The
   value is one or more of 'debris' or 'rocket'.
   If you specify both as command-style options,
   you may either specify the option more than once,
   or specify the values comma-separated.
 rcs
   specifies that the radar cross-section returned by
   the search is to be appended to the name, in the form
   --rcs radar_cross_section. If the with_name attribute
   is false, the radar cross-section will be inserted as
   the name. Historical rcs data appear NOT to be
   available.
 status
   specifies the desired status of the returned body
   (or bodies). Must be 'onorbit', 'decayed', or 'all'.
   The default is 'all'. Note that this option
   represents status at the time the search was done;
   you can not combine it with the retrieve() date
   options to find bodies onorbit as of a given date
   in the past.
 tle
   specifies that you want TLE data retrieved for all
   bodies that satisfy the search criteria. This is
   true by default, but may be negated by specifying
   -notle ( or { tle => 0 } ). If negated, the content
   of the response object is the results of the search,
   one line per body found, with the fields tab-
   delimited.

Examples:

 search_date (-status => 'onorbit', -exclude =>
    'debris,rocket', -last5 '2005-12-25');
 search_date (-exclude => 'debris',
    -exclude => 'rocket', '2005/12/25');
 search_date ({exclude => ['debris', 'rocket']},
    '2005-12-25');
 search_date ({exclude => 'debris,rocket'}, # INVALID!
    '2005-12-25');
 search_date ( '-notle', '2005-12-25' );

This method implicitly calls the C<login()> method if the session cookie
is missing or expired. If C<login()> fails, you will get the
HTTP::Response from C<login()>.

What you get on success depends on the value specified for the -tle
option.

Unless you explicitly specified C<-notle> (or C<< { tle => 0 } >>), this
method returns an HTTP::Response object whose content is the relevant
element sets. It will also have the following headers set:

 Pragma: spacetrack-type = orbit
 Pragma: spacetrack-source = spacetrack

These can be accessed by C<< $st->content_type( $resp ) >> and
C<< $st->content_source( $resp ) >> respectively.

If you explicitly specified C<-notle> (or C<< { tle => 0 } >>), this
method returns an HTTP::Response object whose content is the results of
the relevant search, one line per object found. Within a line the fields
are tab-delimited, and occur in the same order as the underlying web
page. The first line of the content is the header lines from the
underlying web page. It will also have the following headers set:

 Pragma: spacetrack-type = search
 Pragma: spacetrack-source = spacetrack

If you call this method in list context, the first element of the
returned object is the aforementioned HTTP::Response object, and the
second is a reference to an array containing the search results. The
first element is a reference to an array containing the header lines
from the web page. Subsequent elements are references to arrays
containing the actual search results.

=cut

sub search_date {
    my ($self, @args) = @_;
    @args = _parse_search_args (@args);
    return $self->_search_generic (sub {
	my ($self, $name, $opt) = @_;
	my ($year, $month, $day) =
	    $name =~ m/ \A (\d+) (?:\D+ (\d+) (?: \D+ (\d+) )? )? /smx
		or return;
	$year += $year < 57 ? 2000 : $year < 100 ? 1900 : 0;
	$month ||= 0;
	$day ||= 0;
	my $resp = $self->_post ('perl/launch_query.pl',
	    date_spec => 'month',
	    launch_year => $year,
	    launch_month => $month,
	    launch_day => $day,
	    status => $opt->{status},	# 'all', 'onorbit' or 'decayed'.
	    exclude => $opt->{exclude},	# ['debris', 'rocket', or both]
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	);
	return $resp;
    }, @args );
}


=for html <a name="search_decay"></a>

=item $resp = $st->search_decay (decay ...)

This method searches the Space Track database for objects decayed on
the given date. The date is specified as year-month-day, with any
non-digit being legal as the separator. You can omit -day or specify it
as 0 to get all decays for the given month. You can omit -month (or
specify it as 0) as well to get all decays for the given year.

The options are the same as for L</search_date>.

A Space Track username and password are required to use this method.

What you get on success depends on the value specified for the -tle
option.

Unless you explicitly specified C<-notle> (or C<< { tle => 0 } >>), this
method returns an HTTP::Response object whose content is the relevant
element sets. It will also have the following headers set:

 Pragma: spacetrack-type = orbit
 Pragma: spacetrack-source = spacetrack

These can be accessed by C<< $st->content_type( $resp ) >> and
C<< $st->content_source( $resp ) >> respectively.

If you explicitly specified C<-notle> (or C<< { tle => 0 } >>), this
method returns an HTTP::Response object whose content is the results of
the relevant search, one line per object found. Within a line the fields
are tab-delimited, and occur in the same order as the underlying web
page. The first line of the content is the header lines from the
underlying web page. It will also have the following headers set:

 Pragma: spacetrack-type = search
 Pragma: spacetrack-source = spacetrack

If you call this method in list context, the first element of the
returned object is the aforementioned HTTP::Response object, and the
second is a reference to an array containing the search results. The
first element is a reference to an array containing the header lines
from the web page. Subsequent elements are references to arrays
containing the actual search results.

=cut

sub search_decay {
    my ($self, @args) = @_;
    @args = _parse_search_args (@args);
    return $self->_search_generic (
	{
	    splice => -1,
	    poster => sub {
		my ($self, $name, $opt) = @_;
		my ($year, $month, $day) =
		    $name =~ m{ \A (\d+) (?: \D+ (\d+) (?: \D+ (\d+) )?
			)? }smx
			or return;
		$year += $year < 57 ? 2000 : $year < 100 ? 1900 : 0;
		$month ||= 0;
		$day ||= 0;
		my $resp = $self->_post ('perl/decay_query.pl',
		    decay_year => $year,
		    decay_month => $month,
		    decay_day => $day,
		    status => $opt->{status},	# 'all', 'onorbit' or 'decayed'.
		    exclude => $opt->{exclude},	# ['debris', 'rocket', or both]
		    _sessionid => '',
		    _submit => 'Submit',
		    _submitted => 1,
		);
		return $resp;
	    },
	}, @args);
}


=for html <a name="search_id"></a>

=item $resp = $st->search_id (id ...)

This method searches the Space Track database for objects having the
given international IDs. The international ID is the last two digits of
the launch year (in the range 1957 through 2056), the three-digit
sequence number of the launch within the year (with leading zeroes as
needed), and the piece (A through ZZZ, with A typically being the
payload). You can omit the piece and get all pieces of that launch, or
omit both the piece and the launch number and get all launches for the
year. There is no mechanism to restrict the search to a given on-orbit
status, or to filter out debris or rocket bodies.

The options are the same as for L</search_date>.

A Space Track username and password are required to use this method.

This method implicitly calls the login () method if the session cookie
is missing or expired. If login () fails, you will get the
HTTP::Response from login ().

What you get on success depends on the value specified for the C<-tle>
option.

Unless you explicitly specified C<-notle> (or C<< { tle => 0 } >>), this
method returns an HTTP::Response object whose content is the relevant
element sets. It will also have the following headers set:

 Pragma: spacetrack-type = orbit
 Pragma: spacetrack-source = spacetrack

These can be accessed by C<< $st->content_type( $resp ) >> and
C<< $st->content_source( $resp ) >> respectively.

If you explicitly specified C<-notle> (or C<< { tle => 0 } >>), this
method returns an HTTP::Response object whose content is the results of
the relevant search, one line per object found. Within a line the fields
are tab-delimited, and occur in the same order as the underlying web
page. The first line of the content is the header lines from the
underlying web page. It will also have the following headers set:

 Pragma: spacetrack-type = search
 Pragma: spacetrack-source = spacetrack

If you call this method in list context, the first element of the
returned object is the aforementioned HTTP::Response object, and the
second is a reference to an array containing the search results. The
first element is a reference to an array containing the header lines
from the web page. Subsequent elements are references to arrays
containing the actual search results.
 
=cut

sub search_id {
    my ($self, @args) = @_;
    @args = _parse_search_args (@args);
    return $self->_search_generic (sub {
	my ($self, $name, $opt) = @_;
	my ($year, $number, $piece) =
	    $name =~ m/ \A (\d\d) (\d{3})? ( [[:alpha:]] )? \z /smx
		or return;
	$year += $year < 57 ? 2000 : 1900;
	my $resp = $self->_post ('perl/launch_query.pl',
	    date_spec => 'number',
	    launch_year => $year,
	    launch_number => $number || '',
	    piece => uc ($piece || ''),
	    status => $opt->{status},	# 'all', 'onorbit' or 'decayed'.
	    exclude => $opt->{exclude},	# ['debris', 'rocket', or both]
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	);
	return $resp;
    }, @args);
}


=for html <a name="search_name"></a>

=item $resp = $st->search_name (name ...)

This method searches the Space Track database for the named objects.
Matches are case-insensitive and all matches are returned.

The options are the same as for L</search_date>. The C<-status> option
is known to work, but I am not sure about the efficacy the C<-exclude>
option.

A Space Track username and password are required to use this method.

This method implicitly calls the login () method if the session cookie
is missing or expired. If login () fails, you will get the
HTTP::Response from login ().

What you get on success depends on the value specified for the -tle
option.

Unless you explicitly specified C<-notle> (or C<< { tle => 0 } >>), this
method returns an HTTP::Response object whose content is the relevant
element sets. It will also have the following headers set:

 Pragma: spacetrack-type = orbit
 Pragma: spacetrack-source = spacetrack

These can be accessed by C<< $st->content_type( $resp ) >> and
C<< $st->content_source( $resp ) >> respectively.

If you explicitly specified C<-notle> (or C<< { tle => 0 } >>), this
method returns an HTTP::Response object whose content is the results of
the relevant search, one line per object found. Within a line the fields
are tab-delimited, and occur in the same order as the underlying web
page. The first line of the content is the header lines from the
underlying web page. It will also have the following headers set:

 Pragma: spacetrack-type = search
 Pragma: spacetrack-source = spacetrack

If you call this method in list context, the first element of the
returned object is the aforementioned HTTP::Response object, and the
second is a reference to an array containing the search results. The
first element is a reference to an array containing the header lines
from the web page. Subsequent elements are references to arrays
containing the actual search results.

=cut

sub search_name {
    my ($self, @args) = @_;
    @args = _parse_search_args (@args);
    return $self->_search_generic (sub {
	my ($self, $name, $opt) = @_;
	$self->_post ('perl/name_query.pl',
	    _submitted => 1,
	    _sessionid => '',
	    name => $name,
	    launch_year_start => 1957,
	    launch_year_end => (gmtime)[5] + 1900,
	    status => $opt->{status},	# 'all', 'onorbit' or 'decayed'.
	    exclude => $opt->{exclude},	# ['debris', 'rocket', or both]
	    _submit => 'Submit',
	    );
	}, @args);
}


=for html <a name="search_oid"></a>

=item $resp = $st->search_oid (name ...)

This method searches the Space Track database for the given Space Track
IDs (also known as OIDs, hence the method name).

B<Note> that in effect this is just a stupid, inefficient version of
L<retrieve()|/retrieve>, which does not understand ranges. Unless you
assert C<-notle> or C<-rcs>, or call it in list context to get the
search data, you should simply call L<retrieve()|/retrieve> instead.

In addition to the options available for L</retrieve>, the following
option may be specified:

 rcs
   specifies that the radar cross-section returned by
   the search is to be appended to the name, in the form
   --rcs radar_cross_section. If the with_name attribute
   is false, the radar cross-section will be inserted as
   the name. Historical rcs data appear NOT to be
   available.
 tle
   specifies that you want TLE data retrieved for all
   bodies that satisfy the search criteria. This is
   true by default, but may be negated by specifying
   -notle ( or { tle => 0 } ). If negated, the content
   of the response object is the results of the search,
   one line per body found, with the fields tab-
   delimited.

If you specify C<-notle>, all other options are ignored, except for
C<-descending>.

A Space Track username and password are required to use this method.

This method implicitly calls the login () method if the session cookie
is missing or expired. If login () fails, you will get the
HTTP::Response from login ().

What you get on success depends on the value specified for the -tle
option.

Unless you explicitly specified C<-notle> (or C<< { tle => 0 } >>), this
method returns an HTTP::Response object whose content is the relevant
element sets. It will also have the following headers set:

 Pragma: spacetrack-type = orbit
 Pragma: spacetrack-source = spacetrack

If the C<content_type()> method returns C<'box_score'>, you can expect
a content-source value of C<'spacetrack'>.

If you explicitly specified C<-notle> (or C<< { tle => 0 } >>), this
method returns an HTTP::Response object whose content is the results of
the relevant search, one line per object found. Within a line the fields
are tab-delimited, and occur in the same order as the underlying web
page. The first line of the content is the header lines from the
underlying web page. It will also have the following headers set:

 Pragma: spacetrack-type = search
 Pragma: spacetrack-source = spacetrack

If you call this method in list context, the first element of the
returned object is the aforementioned HTTP::Response object, and the
second is a reference to an array containing the search results. The
first element is a reference to an array containing the header lines
from the web page. Subsequent elements are references to arrays
containing the actual search results.

=cut

sub search_oid {
    my ($self, @args) = @_;
    @args = _parse_retrieve_args(
	[
	    'rcs!' => '(append --rcs radar_cross_section to name)',
	    'tle!' => '(return TLE data from search (defaults true))'
	],
	@args );
    my $opt = shift @args;
    exists $opt->{tle} or $opt->{tle} = 1;
    my $ids = join ' ', @args;
    return $self->_search_generic ( \&_search_oid_generic, $opt, $ids );
}

sub _search_oid_generic {
    my ( $self, $ids, $opt ) = @_;
    return $self->_post (
	'perl/satcat_id_query.pl',
	_submitted => 1,
	_sessionid => '',
	ids => $ids,
	desc => ( $opt->{descending} ? 'yes' : '' ),
	_submit => 'Submit',
    );
}


=for html <a name="set"></a>

=item $st->set ( ... )

This is the mutator method for the object. It can be called explicitly,
but other methods as noted may call it implicitly also. It croaks if
you give it an odd number of arguments, or if given an attribute that
either does not exist or cannot be set.

For the convenience of the shell method we return a HTTP::Response
object with a success status if all goes well. But if we encounter an
error we croak.

See L</Attributes> for the names and functions of the attributes.

=cut

sub set {	## no critic (ProhibitAmbiguousNames)
    my ($self, @args) = @_;
    delete $self->{_pragmata};
    @args % 2
	and croak __PACKAGE__, '->set( ',
	join( ', ', map { "'$_'" } @args ),
	') requires an even number of arguments';
    while (@args) {
	my $name = shift @args;
	croak "Attribute $name may not be set. Legal attributes are ",
		join (', ', sort keys %mutator), ".\n"
	    unless $mutator{$name};
	my $value = shift @args;
	$mutator{$name}->($self, $name, $value);
    }
    return HTTP::Response->new (RC_OK, undef, undef, COPACETIC);
}


=for html <a name="shell"></a>

=item $st->shell ()

This method implements a simple shell. Any public method name except
'new' or 'shell' is a command, and its arguments if any are parameters.
We use Text::ParseWords to parse the line, and blank lines or lines
beginning with a hash mark ('#') are ignored. Input is via
Term::ReadLine if that is available. If not, we do the best we can.

We also recognize 'bye' and 'exit' as commands, which terminate the
method. In addition, 'show' is recognized as a synonym for 'get', and
'get' (or 'show') without arguments is special-cased to list all
attribute names and their values. Attributes listed without a value have
the undefined value.

For commands that produce output, we allow a sort of pseudo-redirection
of the output to a file, using the syntax ">filename" or ">>filename".
If the ">" is by itself the next argument is the filename. In addition,
we do pseudo-tilde expansion by replacing a leading tilde with the
contents of environment variable HOME. Redirection can occur anywhere
on the line. For example,

 SpaceTrack> catalog special >special.txt

sends the "Special Interest Satellites" to file special.txt. Line
terminations in the file should be appropriate to your OS.

This method can also be called as a subroutine - i.e. as

 Astro::SpaceTrack::shell (...)

Whether called as a method or as a subroutine, each argument passed
(if any) is parsed as though it were a valid command. After all such
have been executed, control passes to the user. Unless, of course,
one of the arguments was 'exit'.

Unlike most of the other methods, this one returns nothing.

=cut

my $rdln;

sub shell {
    my @args = @_;
    my $self = _instance( $args[0], __PACKAGE__ ) ? shift @args :
	Astro::SpaceTrack->new (addendum => <<'EOD');

'help' gets you a list of valid commands.
EOD

    my $prompt = 'SpaceTrack> ';

    my $stdout = \*STDOUT;
    my $read;

    unshift @args, 'banner' if $self->{banner} && !$self->{filter};
    # Perl::Critic wants IO::Interactive::is_interactive() here. But
    # that assumes we're using the *ARGV input mechanism, which we're
    # not (command arguments are SpaceTrack commands.) Also, we would
    # like to be prompted even if output is to a pipe, but the
    # recommended module calls that non-interactive even if input is
    # from a terminal. So:
    my $interactive = -t STDIN;
    while (1) {
	my $buffer;
	if (@args) {
	    $buffer = shift @args;
	} else {
	    $read ||= $interactive ? ( eval {
		    require Term::ReadLine;
		    $rdln ||= Term::ReadLine->new (
			'SpaceTrack orbital element access');
		    $stdout = $rdln->OUT || \*STDOUT;
		    sub { $rdln->readline ($prompt) };
		} || sub { print { $stdout } $prompt; return <STDIN> } ) :
		sub { return<STDIN> };
	    $buffer = $read->();
	}
	last unless defined $buffer;

	$buffer =~ s/ \A \s+ //smx;
	$buffer =~ s/ \s+ \z //smx;
	next unless $buffer;
	next if $buffer =~ m/ \A [#] /smx;
	my @cmdarg = parse_line ('\s+', 0, $buffer);
	my $redir = '';
	@cmdarg = map {m/ \A > /smx ? do {$redir = $_; ()} :
	    $redir =~ m/ \A >+ \z /smx ? do {$redir .= $_; ()} :
	    $_} @cmdarg;
	$redir =~ s/ \A (>+) ~ /$1$ENV{HOME}/smx;
	my $verb = lc shift @cmdarg;
	last if $verb eq 'exit' || $verb eq 'bye';
	$verb eq 'show' and $verb = 'get';
	$verb eq 'source' and do {
	    eval {
		splice @args, 0, 0, $self->_source (shift @cmdarg);
		1;
	    } or warn ( $@ || 'An unknown error occurred' );	## no critic (RequireCarping)
	    next;
	};
	($verb eq 'new' || $verb =~ m/ \A _ /smx || $verb eq 'shell' ||
	    !$self->can ($verb)) and do {
	    warn <<"EOD";
Verb '$verb' undefined. Use 'help' to get help.
EOD
	    next;
	};
	my $out;
	if ( $redir ) {
	    $out = IO::File->new( $redir ) or do {
		warn <<"EOD";
Error - Failed to open $redir
	$^E
EOD
		next;
	    };
	} else {
	    $out = $stdout;
	}
	my $rslt;
	if ($verb eq 'get' && @cmdarg == 0) {
	    $rslt = [];
	    foreach my $name ($self->attribute_names ()) {
		my $val = $self->getv( $name );
		push @$rslt, defined $val ? "$name $val" : $name;
	    }
	} else {
	    eval {
		$rslt = $self->$verb (@cmdarg);
		1;
	    } or do {
		warn $@;	## no critic (RequireCarping)
		next;
	    };
	}
	if (ref $rslt eq 'ARRAY') {
	    foreach (@$rslt) {print { $out } "$_\n"}
	} elsif ($rslt->is_success) {
	    $self->content_type()
		or not $self->{filter}
		or next;
	    my $content = $rslt->content;
	    chomp $content;
	    print { $out } "$content\n";
	} else {
	    my $status = $rslt->status_line;
	    chomp $status;
	    warn $status, "\n";
	}
    }
    $interactive
	and not $self->{filter}
	and print { $stdout } "\n";
    return;
}


=for html <a name="source"></a>

=item $st->source ($filename);

This convenience method reads the given file, and passes the individual
lines to the shell method. It croaks if the file is not provided or
cannot be read.

=cut

# We really just delegate to _source, which unpacks.
sub source {
    my $self = _instance( $_[0], __PACKAGE__ ) ? shift :
	Astro::SpaceTrack->new ();
    $self->shell ($self->_source (@_), 'exit');
    return;
}


=for html <a name="spaceflight"></a>

=item $resp = $st->spaceflight ()

This method downloads current orbital elements from NASA's human
spaceflight site, L<http://spaceflight.nasa.gov/>. As of July 2006
you get the International Space Station, and the current Space Shuttle
mission, if any.

You can specify either or both of the arguments 'ISS' and 'SHUTTLE'
(case-insensitive) to retrieve the data for the international space
station or the space shuttle respectively. If neither of these is
specified, both are retrieved.

In addition you can specify options, either as command-style options
(e.g. C<-all>) or by passing them in a hash as the first argument (e.g.
C<{all => 1}>). The options specific to this method are:

 all
  causes all TLEs for a body to be downloaded;
 effective
  causes the effective date to be added to the data.

In addition, any of the L</retrieve> options is valid for this method as
well.

The -all option is recommended, but is not the default for historical
reasons. If you specify -start_epoch, -end_epoch, or -last5, -all will
be ignored.

The -effective option hacks the effective date of the data onto the end
of the common name (i.e. the first line of the 'NASA TLE') in the form
C<--effective=date> where the effective date is encoded the same way the
epoch is. Specifying this forces the generation of a 'NASA TLE'.

No Space Track account is needed to access this data, even if the
'direct' attribute is false. But if the 'direct' attribute is true,
the setting of the 'with_name' attribute is ignored.

If this method succeeds, the response will contain headers

 Pragma: spacetrack-type = orbit
 Pragma: spacetrack-source = spaceflight

These can be accessed by C<< $st->content_type( $resp ) >> and
C<< $st->content_source( $resp ) >> respectively.

This method is a web page scraper. any change in the location of the
web pages, or any substantial change in their format, will break this
method.

=cut

sub spaceflight {
    my ($self, @args) = @_;
    delete $self->{_pragmata};

    @args = _parse_retrieve_args(
	[
	    'all!' => 'retrieve all data',
	    'effective!' => 'include effective date',
	],
	@args );
    my $opt = _parse_retrieve_dates (shift @args, {perldate => 1});

    $opt->{all} = 0 if $opt->{last5} || $opt->{start_epoch};

    my @list;
    if (@args) {
	foreach (@args) {
	    my $info = $catalogs{spaceflight}{lc $_} or
		return $self->_no_such_catalog (spaceflight => $_);
	    push @list, $info->{url};
	}
    } else {
	my $hash = $catalogs{spaceflight};
	@list = map {$hash->{$_}{url}} sort keys %$hash;
    }

    my $content = '';
    my $html = '';
    my $now = time ();
    my %tle;
    foreach my $url (@list) {
	my $resp = $self->{agent}->get ($url);
	return $resp unless $resp->is_success;
	$html .= $resp->content();
	my (@data, $acquire, $effective);
	foreach (split qr{ \n }smx, $resp->content) {
	    chomp;
	    m{ Vector \s+ Time \s+ [(] GMT [)] : \s+
		( \d+ / \d+ / \d+ : \d+ : \d+ [.] \d+ )}smx and do {
		$effective = join ' ', '--effective', $1;
		next;
	    };
	    m/TWO LINE MEAN ELEMENT SET/ and do {
		$acquire = 1;
		@data = ();
		next;
	    };
	    next unless $acquire;
	    s/ \A \s+ //smx;
	    $_ and do {push @data, $_; next};
	    @data and do {
		$acquire = undef;
		@data == 2 or @data == 3 or next;
		@data == 3
		    and not $self->{direct}
		    and not $self->{with_name}
		    and shift @data;
		if ($effective && $opt->{effective}) {
		    if (@data == 2) {
			unshift @data, $effective;
		    } else {
			$data[0] .= " $effective";
		    }
		}
		$effective = undef;
		my $id = 0 + substr $data[-2], 2, 5;
		my $yr = substr $data[-2], 18, 2;
		my $da = substr $data[-2], 20, 12;
		$yr += 100 if $yr < 57;
		my $ep = timegm (0, 0, 0, 1, 0, $yr) + ($da - 1) * 86400;
		if ( $opt->{all} ||
		    $opt->{start_epoch} && $ep >= $opt->{start_epoch} &&
			$ep < $opt->{end_epoch} ||
		    $ep <= $now ) {
##		unless (!$opt->{all} && ($opt->{start_epoch} ?
##			($ep > $opt->{end_epoch} || $ep <= $opt->{start_epoch}) :
##			$ep > $now)) {
		    $tle{$id} ||= [];
		    my @keys = $opt->{descending} ? (-$id, -$ep) : ($id, $ep);
		    @keys = reverse @keys if $opt->{sort} eq 'epoch';
		    push @{$tle{$id}}, [@keys, join '', map {"$_\n"} @data];
		}
		@data = ();
	    };
	}
    }

    unless ($opt->{all} || $opt->{start_epoch}) {
	my $keep = $opt->{last5} ? 5 : 1;
	foreach (values %tle) {splice @{ $_ }, $keep}
    }
    $content .= join '',
	map {$_->[2]}
	sort {$a->[0] <=> $b->[0] || $a->[1] <=> $b->[1]}
	map {@$_} values %tle;

    $content
	or return HTTP::Response->new( RC_PRECONDITION_FAILED,
	    NO_RECORDS, undef, $html );

    my $resp = HTTP::Response->new (RC_OK, undef, undef, $content);
    $self->_add_pragmata($resp,
	'spacetrack-type' => 'orbit',
	'spacetrack-source' => 'spaceflight',
    );
    $self->_dump_headers( $resp );
    return $resp;
}

=for html <a name="spacetrack"></a>

=item $resp = $st->spacetrack ($name_or_number);

This method downloads the given bulk catalog of orbital elements from
the Space Track web site. If the argument is an integer, it represents
the number of the catalog to download. Otherwise, it is expected to be
the name of the catalog, and whether you get a two-line or three-line
dataset is specified by the setting of the with_name attribute. The
return is the HTTP::Response object fetched. If an invalid catalog name
is requested, an HTTP::Response object is returned, with an appropriate
message and the error code set to RC_NOTFOUND from HTTP::Status (a.k.a.
404). This will also happen if the HTTP get succeeds but we do not get
the expected content.

A Space Track username and password are required to use this method.

If this method succeeds, the response will contain headers

 Pragma: spacetrack-type = orbit
 Pragma: spacetrack-source = spacetrack

These can be accessed by C<< $st->content_type( $resp ) >> and
C<< $st->content_source( $resp ) >> respectively.

Note that when requesting spacetrack data sets by catalog number the
setting of the C<with_name> attribute is ignored.

Assuming success, the content of the response is the literal element
set requested. Yes, it comes down gzipped, but we unzip it for you.
See the synopsis for sample code to retrieve and print the 'special'
catalog in three-line format.

A list of valid names and brief descriptions can be obtained by calling
C<< $st->names ('spacetrack') >>. If you have set the C<verbose>
attribute true (e.g. C<< $st->set (verbose => 1) >>), the content of the
error response will include this list. Note, however, that this list
does not determine what can be retrieved; if Space Track adds a data
set, it can still be retrieved by number, even if it does not appear in
the list by either number or name. Similarly, if they remove a data set,
being on the list will not help. If they decide to renumber the data
sets, retrieval by name will become useless until I get the code
updated. The numbers correspond to the 'id=' portion of the URL for the
dataset on the Space Track web site

This method implicitly calls the C<login()> method if the session cookie
is missing or expired. If C<login()> fails, you will get the
HTTP::Response from C<login()>.

=cut

sub spacetrack {
    my $self = shift;
    delete $self->{_pragmata};
    my $catnum = shift;
    $catnum =~ m/ \D /smx and do {
	my $info = $catalogs{spacetrack}{$catnum} or
	    return $self->_no_such_catalog (spacetrack => $catnum);
	$catnum = $info->{number};
	$self->{with_name} && $catnum++ unless $info->{special};
    };
    my $resp = $self->_get ('perl/dl.pl', ID => $catnum);
# At this point, assuming we succeeded, we should have headers
# content-disposition: attachment; filename=the_desired_file_name
# content-type: application/force-download
# In the above, the_desired_file_name is (e.g.) something like
#   spec_interest_2l_2005_03_22_am.txt.gz

=begin comment

It is possible (e.g. 04-May-2007) to get the following instead:

<html>
<body><script type="text/javascript">
alert("There was a problem processing your request!\nPlease email admin@space-track.org
Requested file  doesn't exist");history.go(-1);
</script>
</body></html>

=end comment

=cut

    ($resp->is_success() && !$self->{debug_url}) and do {
	my $content = $resp->content ();
	if ($content =~ m/ <html> /smx) {
	    if ($content =~ m/ Requested \s file \s doesn't \s exist/smxi) {
		$resp = HTTP::Response->new (RC_NOT_FOUND,
		    "The file for catalog $catnum is missing.\n",
		    undef, $content);
	    } else {
		$resp = HTTP::Response->new (RC_INTERNAL_SERVER_ERROR,
		    "The file for catalog $catnum could not be retrieved.\n",
		    undef, $content);
	    }
	} else {
	    $catnum and $resp->content (
		Compress::Zlib::memGunzip ($resp->content));
	    # SpaceTrack returns status 200 on a non-existent catalog
	    # number, but whatever content they send back doesn't unzip, so
	    # we catch it here.
	    defined ($resp->content ())
		or return $self->_no_such_catalog (spacetrack => $catnum);
	    $resp->remove_header ('content-disposition');
	    $resp->header (
		'content-type' => 'text/plain',
##		'content-length' => length ($resp->content),
	    );
	    $self->_convert_content ($resp);
	    $self->_add_pragmata($resp,
		'spacetrack-type' => 'orbit',
		'spacetrack-source' => 'spacetrack',
	    );
	}
    };
    return $resp;
}


####
#
#	Private methods.
#

#	$self->_add_pragmata ($resp, $name => $value, ...);
#
#	This method adds pragma headers to the given HTTP::Response
#	object, of the form pragma => "$name = $value". The pragmata are
#	also cached in $self.

sub _add_pragmata {
    my ($self, $resp, @args) = @_;
    while (@args) {
	my $name = shift @args;
	my $value = shift @args;
	$self->{_pragmata}{$name} = $value;
	$resp->push_header(pragma => "$name = $value");
    }
    return;
}

#	_check_cookie looks for our session cookie. If it's found, it returns
#	the cookie's expiration time and sets the relevant attributes.
#	Otherwise it returns zero.

sub _check_cookie {
    my $self = shift;
    my ($cookie, $expir);
    $expir = 0;
    $self->{agent}->cookie_jar->scan (sub {
	$self->{dump_headers} > 1 and _dump_cookie ("_check_cookie:\n", @_);
	($cookie, $expir) = @_[2, 8] if $_[4] eq $self->{domain_space_track} &&
	    $_[3] eq SESSION_PATH && $_[1] eq SESSION_KEY;
	});
    $self->{dump_headers} and warn $expir ? <<"EOD" : <<'EOD';	## no critic (RequireCarping)
Session cookie: $cookie
Cookie expiration: @{[strftime '%d-%b-%Y %H:%M:%S', localtime $expir]} ($expir)
EOD
Session cookie not found
EOD
    $self->{session_cookie} = $cookie;
    $self->{cookie_expires} = $expir;
    return $expir || 0;
}

#	_convert_content converts the content of an HTTP::Response
#	from crlf-delimited to lf-delimited.

{	# Begin local symbol block

    my $lookfor = $^O eq 'MacOS' ? qr{ \012|\015+ }smx : qr{ \r \n }smx;

    sub _convert_content {
	my ($self, @args) = @_;
	local $/ = undef;	# Slurp mode.
	foreach my $resp (@args) {
	    my $buffer = $resp->content;
	    # If we request a non-existent Space Track catalog number,
	    # we get 200 OK but the unzipped content is undefined. We
	    # catch this before we get this far, but the buffer check is
	    # left in in case something else leaks through.
	    defined $buffer or $buffer = '';
	    $buffer =~ s/$lookfor/\n/smxgo;
	    1 while ($buffer =~ s/ \A \n+ //smx);
	    $buffer =~ s/ \s+ \n /\n/smxg;
	    $buffer =~ m/ \n \z /smx or $buffer .= "\n";
	    $resp->content ($buffer);
	    $resp->header (
		'content-length' => length ($buffer),
		);
	}
	return;
    }
}	# End local symbol block.

#	_dump_cookie is intended to be called from inside the
#	HTTP::Cookie->scan method. The first argument is prefix text
#	for the dump, and the subsequent arguments are the arguments
#	passed to the scan method.
#	It dumps the contents of the cookie to STDERR via a warn ().
#	A typical session cookie looks like this:
#	    version => 0
#	    key => 'spacetrack_session'
#	    val => whatever
#	    path => '/'
#	    domain => 'www.space-track.org'
#	    port => undef
#	    path_spec => 1
#	    secure => undef
#	    expires => undef
#	    discard => 1
#	    hash => {}
#	The response to the login, though, has an actual expiration
#	time, which we take cognisance of.

use Data::Dumper;

{	# begin local symbol block

    my @names = qw{version key val path domain port path_spec secure
	    expires discard hash};

    sub _dump_cookie {
	my ($prefix, @args) = @_;
	local $Data::Dumper::Terse = 1;
	$prefix and warn $prefix;	## no critic (RequireCarping)
	for (my $inx = 0; $inx < @names; $inx++) {
	    warn "    $names[$inx] => ", Dumper ($args[$inx]);	## no critic (RequireCarping)
	}
	return;
    }
}	# end local symbol block


#	_dump_headers dumps the headers of the passed-in response
#	object.

sub _dump_headers {
    my ( $self, $resp ) = @_;
    $self->{dump_headers} or return;
    local $Data::Dumper::Terse = 1;
    my $rqst = $resp->request;
    $rqst = ref $rqst ? $rqst->as_string : "undef\n";
    chomp $rqst;
    warn "\nRequest:\n$rqst\nHeaders:\n",
	$resp->headers->as_string, "\nCookies:\n";
    $self->{agent}->cookie_jar->scan (sub {
	_dump_cookie ("\n", @_);
	});
    warn "\n";
    return;
}

#	_dump_request dumps the request if desired.
#
#	If the debug_url is defined, and has the 'dump-request:' scheme,
#	AND any of several YAML modules can be loaded, this routine
#	returns an HTTP::Response object with status RC_OK and whose
#	content is the request and its arguments encoded in YAML.
#
#	If any of the conditions fails, this module simply returns. The
#	moral: don't try to dump requests unless YAML is installed.

sub _dump_request {
    my ($self, $url, @args) = @_;
    my $display = $self->{dump_headers} & 0x02;
    my $respond = ( $self->{debug_url} || '' ) =~ m/ \A dump-request: /smx;
    $display or $respond or return;
    my $dumper = _get_yaml_dumper() or return;
    (my $method = (caller 1)[3]) =~ s/ \A (?: .* :: )? _? //smx;
    my %data = (
	args => {@args},
	method => $method,
	url => $url,
    );
    my $yaml = $dumper->( \%data );
    $yaml =~ s/ \n{2,} /\n/smxg;
    $display and print $yaml;
    $respond and return HTTP::Response->new( RC_OK, undef, undef, $yaml );
    return;
}

#	_get gets the given path on the domain. Arguments after the
#	first are the CGI parameters. It checks the currency of the
#	session cookie, and executes a login if it deems it necessary.
#	The normal return is the HTTP::Response object from the get (),
#	but if a login was attempted and failed, the HTTP::Response
#	object from the login will be returned.

sub _get {
    my ($self, $path, @args) = @_;
    my $cgi = '';
    {
	my @unpack = @args;
	while (@unpack) {
	    my $name = shift @unpack;
	    my $val = shift @unpack || '';
	    $cgi .= "&$name=$val";
	}
    }
    $cgi and substr( $cgi, 0, 1, '?' );
    {	# Single-iteration loop
	$self->{debug_url} or $self->{cookie_expires} > time () or do {
	    my $resp = $self->login ();
	    return $resp unless $resp->is_success;
	};
	my $url = "http://$self->{domain_space_track}/$path";
	my $resp = $self->_dump_request($url, @args) ||
	    $self->{agent}->get (($self->{debug_url} || $url) . $cgi);
	$self->_dump_headers( $resp );
##	return $resp unless $resp->is_success && !$self->{debug_url};
	$resp->is_success()
	    and not $self->{debug_url}
	    or return $resp;
	local $_ = $resp->content;
	m/ login [.] pl /smxi and do {
	    $self->{cookie_expires} = 0;
	    redo;
	};
	return $resp;
    }	# end of single-iteration loop
    return;	# Should never get here.
}

#	Note: If we have a bad cookie, we get a success status, with
#	the text
# <?xml version="1.0" encoding="iso-8859-1"?>
# <!DOCTYPE html
#         PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
#          "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
# <html xmlns="http://www.w3.org/1999/xhtml" lang="en-US" xml:lang="en-US"><head><title>Space-Track</title>
# </head><body>
# <body bgcolor='#fffacd' text='#191970' link='#3333e6'>
#          <div align='center'><img src='http://www.space-track.org/icons/spacetrack_logo3.jpg' width=640 height=128 align='top' border=0></div>
# <h2>Error, Corrupted session cookie<br>
# Please <A HREF='login.pl'>LOGIN</A> again.<br>
# </h2>
# </body></html>
#	If this happens, it would be good to retry the login.

	
{

    my ($dumper, $loader, $package, $tried);

#	_get_yaml_dumper retrieves a YAML dumper. If one can be found,
#	a code reference to it is returned. Otherwise we simply return.

    sub _get_yaml_dumper {
	$dumper and return $dumper;
	($package ||= _get_yaml_package()) or return;
	$dumper = $package->can('Dump');
	return $dumper;
    }
 
#	__get_yaml_loader retrieves a YAML loader. If one can be found,
#	a code reference to it is returned. Otherwise we simply return.
#
#	NOTE WELL: This subroutine is for the benefit of
#	t/spacetrack_request.t, and is called by that code. The leading
#	double underscore is to flag it to Perl::Critic as package
#	private rather than module private.

    sub __get_yaml_loader {
	$loader and return $loader;
	($package ||= _get_yaml_package()) or return;
	$loader = $package->can('Load');
	return $loader;
    }

#	_get_yaml_package tries to load several YAML packages, returning
#	the name of the first which is loaded successfully. If none can
#	be loaded, it returns undef. Subsequent calls simply return
#	whatever the first call did.

    sub _get_yaml_package {
	$tried and return $package;
	$tried++;
	$package =
	    eval { require YAML::XS;   'YAML::XS'   } ||
	    eval { require YAML::Syck; 'YAML::Syck' } ||
	    eval { require YAML;       'YAML'       } ||
	    eval { require YAML::Tiny; 'YAML::Tiny' }
	;
	return $package;
    }
}

#	_handle_observing_list takes as input any number of arguments.
#	each is split on newlines, and lines beginning with a five-digit
#	number (with leading spaces allowed) are taken to specify the
#	catalog number (first five characters) and common name (the rest)
#	of an object. The resultant catalog numbers are run through the
#	retrieve () method. If called in scalar context, the return is
#	the resultant HTTP::Response object. In list context, the first
#	return is the HTTP::Response object, and the second is a reference
#	to a list of list references, each lower-level reference containing
#	catalog number and name.

sub _handle_observing_list {
    my ($self, @args) = @_;
    my (@catnum, @data);

    @args = _parse_retrieve_args( @args );
    my $opt = shift;

    foreach (map {split qr{ \n }smx, $_} @args) {
	s/ \s+ \z //smx;
	my ( $id ) = m/ \A ( [\s\d]{5} ) /smx or next;
	$id =~ m/ \A \s* \d+ \z /smx or next;
	push @catnum, $id;
	push @data, [$id, substr $_, 5];
    }
    my $resp = $self->retrieve ($opt, sort {$a <=> $b} @catnum);
    if ($resp->is_success) {
	unless ($self->{_pragmata}) {
	    $self->_add_pragmata($resp,
		'spacetrack-type' => 'orbit',
		'spacetrack-source' => 'spacetrack',
	    );
	}
	$self->_dump_headers( $resp );
    }
    return wantarray ? ($resp, \@data) : $resp;
}

#	_instance takes a variable and a class, and returns true if the
#	variable is blessed into the class. It returns false for
#	variables that are not references.
sub _instance {
    my ( $object, $class ) = @_;
    ref $object or return;
    blessed( $object ) or return;
    return $object->isa( $class );
}

#	_mutate_attrib takes the name of an attribute and the new value
#	for the attribute, and does what its name says.

# We supress Perl::Critic because we're a one-liner. CAVEAT: we MUST
# not modify the contents of @_. Modifying @_ itself is fine.
sub _mutate_attrib {
    return ($_[0]{$_[1]} = $_[2]);
}

#	_mutate_authen clears the session cookie and then sets the
#	desired attribute

# This clears the session cookie and cookie expiration, then co-routines
# off to _mutate attrib.
sub _mutate_authen {
    $_[0]->set (session_cookie => undef, cookie_expires => 0);
    goto &_mutate_attrib;
}

#	_mutate_cookie sets the session cookie, in both the object and
#	the user agent's cookie jar. If the session cookie is undef, we
#	delete the session cookie from the cookie jar; otherwise we set
#	it to the specified value.

# This mutates the user agent's cookie jar, then co-routines off to
# _mutate attrib.
sub _mutate_cookie {
    if ($_[0]->{agent} && $_[0]->{agent}->cookie_jar) {
	if (defined $_[2]) {
	    $_[0]->{agent}->cookie_jar->set_cookie (0, SESSION_KEY, $_[2],
		SESSION_PATH, $_[0]{domain_space_track},
		undef, 1, undef, undef, 1, {});
	} else {
	    $_[0]->{agent}->cookie_jar->clear(
		$_[0]{domain_space_track}, SESSION_PATH, SESSION_KEY);
	}
    }
    goto &_mutate_attrib;
}

# This subroutine just does some argument checking and then co-routines
# off to _mutate_attrib.
sub _mutate_iridium_status_format {
    croak "Error - Illegal status format '$_[2]'"
	unless $catalogs{iridium_status}{$_[2]};
    goto &_mutate_attrib;
}

#	_mutate_number croaks if the value to be set is not numeric.
#	Otherwise it sets the value. Only unsigned integers pass.

# This subroutine just does some argument checking and then co-routines
# off to _mutate_attrib.
sub _mutate_number {
    $_[2] =~ m/ \D /smx and croak <<"EOD";
Attribute $_[1] must be set to a numeric value.
EOD
    goto &_mutate_attrib;
}


#	_no_such_catalog takes as arguments a source and catalog name,
#	and returns the appropriate HTTP::Response object based on the
#	current verbosity setting.

my %no_such_name = (
    celestrak => 'CelesTrak',
    spaceflight => 'Manned Spaceflight',
    spacetrack => 'Space Track',
);
my %no_such_trail = (
    spacetrack => <<'EOD',
The Space Track data sets are actually numbered. The given number
corresponds to the data set without names; if you are requesting data
sets by number and want names, add 1 to the given number. When
requesting Space Track data sets by number the 'with_name' attribute is
ignored.
EOD
);
sub _no_such_catalog {
    my $self = shift;
    my $source = lc shift;
    my $catalog = shift;
    my $note = shift;
    my $name = $no_such_name{$source} || $source;
    my $lead = $catalogs{$source}{$catalog} ?
	"Missing $name catalog '$catalog'" :
	"No such $name catalog as '$catalog'";
    $lead .= defined $note ? " ($note)." : '.';
    return HTTP::Response->new (RC_NOT_FOUND, "$lead\n")
	unless $self->{verbose};
    my $resp = $self->names ($source);
    return HTTP::Response->new (RC_NOT_FOUND,
	join '', "$lead Try one of:\n", $resp->content,
	$no_such_trail{$source} || ''
    );
}

#	_parse_args parses options off an argument list. The first
#	argument must be a list reference of options to be parsed.
#	This list is pairs of values, the first being the Getopt::Long
#	specification for the option, and the second being a description
#	of the option suitable for help text. Subsequent arguments are
#	the arguments list to be parsed. It returns a reference to a
#	hash containing the options, followed by any remaining
#	non-option arguments. If the first argument after the list
#	reference is a hash reference, it simply returns.

sub _parse_args {
    my ( $lgl_opts, @args ) = @_;
    ref $args[0] eq 'HASH' and return @args;
    my %lgl = @{ $lgl_opts };
    my $opt = {};
    local @ARGV = @args;
    GetOptions ($opt, keys %lgl) or croak <<"EOD";
Error - Legal options are@{[map {(my $q = $_) =~ s/=.*//;
	$q =~ s/!//;
	"\n  -$q $lgl{$_}"} sort keys %lgl]}
with dates being either Perl times, or numeric year-month-day, with any
non-numeric character valid as punctuation.
EOD
    return ( $opt, @ARGV );
}

#	_parse_retrieve_args parses the retrieve() options off its
#	arguments, prefixes a reference to the resultant options hash to
#	the remaining arguments, and returns the resultant list. If the
#	first argument is a list reference, it is taken as extra
#	options, and removed from the argument list. If the next
#	argument after the list reference (if any) is a hash reference,
#	it simply returns its argument list, under the assumption that
#	it has already been called.

my @legal_retrieve_args = (
    descending => '(direction of sort)',
    'end_epoch=s' => 'date',
    last5 => '(ignored if -start_epoch or -end_epoch specified)',
    'sort=s' => "type ('catnum' or 'epoch', with 'catnum' the default)",
    'start_epoch=s' => 'date',
);

sub _parse_retrieve_args {
    my @args = @_;
    my $extra_args = ref $args[0] eq 'ARRAY' ? shift @args : undef;

    my $opt;

    if ( 'HASH' eq ref $args[0] ) {

	$opt = { %{ shift @args } };	# Poor man's clone

    } else {

	( $opt, @args ) = _parse_args(
	    ( $extra_args ? [ @legal_retrieve_args, @{ $extra_args } ] :
		\@legal_retrieve_args ), @args );

    }

    $opt->{sort} ||= 'catnum';

    $opt->{sort} eq 'catnum' or $opt->{sort} eq 'epoch' or die <<"EOD";
Error - Illegal sort '$opt->{sort}'. You must specify 'catnum'
        (the default) or 'epoch'.
EOD

    return ( $opt, @args );
}

#	$opt = _parse_retrieve_dates ($opt);

#	This subroutine looks for keys start_epoch and end_epoch in the
#	given option hash, parses them as YYYY-MM-DD (where the letters
#	are digits and the dashes are any non-digit punctuation), and
#	replaces those keys' values with a reference to a list
#	containing the output of timegm() for the given time. If only
#	one epoch is provided, the other is defaulted to provide a
#	one-day date range. If the syntax is invalid, we croak.
#
#	The return is the same hash reference that was passed in.

sub _parse_retrieve_dates {
    my $opt = shift;
    my $ctl = shift || {};

    my $found;
    foreach my $key (qw{end_epoch start_epoch}) {
	next unless $opt->{$key};
	$opt->{$key} !~ m/ \D /smx or
	    $opt->{$key} =~ m/ \A (\d+) \D+ (\d+) \D+ (\d+) \z /smx
		and $opt->{$key} = eval {timegm (0, 0, 0, +$3, $2-1, +$1)}
		or croak <<"EOD";
Error - Illegal date '$opt->{$key}'. Valid dates are a number
	(interpreted as a Perl date) or numeric year-month-day.
EOD
	$found++;
    }

    if ($found) {
	if ($found == 1) {
	    $opt->{start_epoch} ||= $opt->{end_epoch} - 86400;
	    $opt->{end_epoch} ||= $opt->{start_epoch} + 86400;
	}
	$opt->{start_epoch} <= $opt->{end_epoch} or croak <<'EOD';
Error - End epoch must not be before start epoch.
EOD
	unless ($ctl->{perldate}) {
	    foreach my $key (qw{start_epoch end_epoch}) {
		$opt->{$key} = [gmtime ($opt->{$key})];
	    }
	}
    }

    return $opt;
}

#	_parse_search_args parses the search_*() options off its
#	arguments, prefixes a reference to the resultant options
#	hash to the remaining arguments, and returns the resultant
#	list. If the first argument is a hash reference, it simply
#	returns its argument list, under the assumption that it
#	has already been called.

my @legal_search_args = (
    'rcs!' => '(append --rcs radar_cross_section to name)',
    'tle!' => '(return TLE data from search (defaults true))',
    'status=s' => q{('onorbit', 'decayed', or 'all')},
    'exclude=s@' => q{('debris', 'rocket', or 'debris,rocket')},
);
my %legal_search_exclude = map {$_ => 1} qw{debris rocket};
my %legal_search_status = map {$_ => 1} qw{onorbit decayed all};

sub _parse_search_args {
    my @args = @_;
    unless (ref ($args[0]) eq 'HASH') {
	ref $args[0] eq 'ARRAY' and my @extra = @{shift @args};
	@args = _parse_retrieve_args(
	    [ @legal_search_args, @extra ], @args );

	my $opt = $args[0];
	$opt->{status} ||= 'all';
	$legal_search_status{$opt->{status}} or croak <<"EOD";
Error - Illegal status '$opt->{status}'. You must specify one of
        @{[join ', ', map {"'$_'"} sort keys %legal_search_status]}
EOD
	$opt->{exclude} ||= [];
	$opt->{exclude} = [map {split ',', $_} @{$opt->{exclude}}];
	foreach (@{$opt->{exclude}}) {
	    $legal_search_exclude{$_} or croak <<"EOD";
Error - Illegal exclusion '$_'. You must specify one or more of
        @{[join ', ', map {"'$_'"} sort keys %legal_search_exclude]}
EOD
	}
    }

    return @args;
}

#	_post is just like _get, except for the method used. DO NOT use
#	this method in the login () method, or you get a bottomless
#	recursion.

sub _post {
    my ($self, $path, @args) = @_;
    {	# Single-iteration loop
	$self->{debug_url} or $self->{cookie_expires} > time () or do {
	    my $resp = $self->login ();
	    return $resp unless $resp->is_success;
	};
	my $url = "http://$self->{domain_space_track}/$path";
	my $resp = $self->_dump_request( $url, @args) ||
	    $self->{agent}->post ($self->{debug_url} || $url, [@args]);
	$self->_dump_headers( $resp );
##	return $resp unless $resp->is_success && !$self->{debug_url};
	$resp->is_success()
	    and not $self->{debug_url}
	    or return $resp;
	local $_ = $resp->content;
	m/ login [.] pl /smxi and do {
	    $self->{cookie_expires} = 0;
	    redo;
	};
	return $resp;
    }	# end of single-iteration loop
    return;	# Should never arrive here.
}

#	_search wraps the specific search functions. It is called
#	O-O style, with the first argument (after $self) being a
#	reference to the code that actually requests the data from
#	the server. This code takes two arguments ($self and $name,
#	the latter being the thing to search for), and returns the
#	HTTP::Response object from the request.
#
#	The referenced code is given three arguments: $self, the name
#	of the object to search for, and the option hash. If the
#	referenced code needs the name parsed further, it must do so
#	itself, returning undef if the parse fails.

sub _search_generic {
    my ($self, $poster, @args) = @_;
    delete $self->{_pragmata};

    @args = _parse_retrieve_args( @args );
    my $opt = shift @args;

    @args or return HTTP::Response->new (RC_PRECONDITION_FAILED, NO_OBJ_NAME);

    my %id;
    my $resp;
    $resp = $self->_search_generic_tabulate( \%id, $poster, $opt, @args )
	and return $resp;

    exists $opt->{tle} or $opt->{tle} = 1;
    if ( $opt->{tle} ) {
	my $with_name = $self->getv( 'with_name' );
	$resp = $self->retrieve ($opt, sort {$a <=> $b} keys %id);
	if ( $opt->{rcs} ) {
	    my $content = $resp->content();
	    my $replace = $with_name ? sub {
		my ( $newline, $oid ) = @_;
		return ( $id{$oid} && $id{$oid}[-1] ) ?
		    sprintf( " --rcs %s\n1%6d", $id{$oid}[-1], $oid ) :
		    sprintf( "\n1%6d", $oid );
	    } : sub {
		my ( $newline, $oid ) = @_;
		return ( $id{$oid} && $id{$oid}[-1] ) ?
		    sprintf( "%s--rcs %s\n1%6d", $newline,
			$id{$oid}[-1], $oid ) :
		    sprintf( "%s1%6d", $newline, $oid );
	    };
	    $content =~ s{ ( \A | \n ) 1 \s* ( \d+ ) }
		{ $replace->( $1 || '', $2 ) }smxge;
	    $resp->content( $content );
	}
    } else {
	my $content;
	foreach my $oid ( sort { $a <=> $b } keys %id ) {
	    $content .= join( "\t", @{ $id{$oid} } ) . "\n";
	}
	$resp = HTTP::Response->new (RC_OK, undef, undef, $content);
	$self->_add_pragmata($resp,
	    'spacetrack-type' => 'search',
	    'spacetrack-source' => 'spacetrack',
	);
    }
    wantarray or return $resp;
    my @table;
    foreach my $oid ( sort { $a <=> $b } keys %id ) {
	push @table, [
	    map { ( defined $_ && $_ ne '' ) ? $_ : undef }
	    @{ $id{$oid} } ];
    }
    return ($resp, \@table);
}

sub _search_generic_tabulate {
    my ( $self, $id, $poster, $opt, @args ) = @_;

    my $splice = -2;
    if ( ref $poster eq 'HASH' ) {
	exists $poster->{splice} and $splice = $poster->{splice};
	exists $poster->{poster}
	    or confess 'Programming error - no {poster} key in options hash';
	$poster = $poster->{poster};
    }
    my $p = Astro::SpaceTrack::Parser->new ();

    foreach my $name ( @args ) {
	defined (my $resp = $poster->($self, $name, $opt)) or next;
##	return $resp unless $resp->is_success && !$self->{debug_url};
	$resp->is_success()
	    and not $self->{debug_url}
	    or return $resp;
	my $content = $resp->content;
	next if $content =~ m/ No \s results \s found /smxi;
	$content =~ s/ &nbsp; / /smxg;
	my @this_page = @{$p->parse_string (table => $content)};
	ref $this_page[0] eq 'ARRAY'
	    or return HTTP::Response->new (RC_INTERNAL_SERVER_ERROR,
	    BAD_SPACETRACK_RESPONSE, undef, $content);
	my @data = @{$this_page[0]};
	if ( $splice ) {
	    foreach my $row (@data) {
		splice @{ $row }, $splice;
	    }
	}
	if ( $id->{0} ) {
	    shift @data;
	} else {
	    foreach ( @{ $data[0] } ) {
		s/ \s* [(] key [)] \s* \z //smxi;
	    }
	    $id->{0} = shift @data;
	}
	foreach my $row (@data) {
	    my $oid = $row->[0] or next;
	    $id->{$oid} and next;
	    $id->{$oid} = $row;
	}
    }

    return;
}


#	_source takes a filename, and returns the contents of the file
#	as a list. It dies if anything goes wrong.

sub _source {
    my $self = shift;
    wantarray or die <<'EOD';
Error - _source () called in scalar or no context. This is a bug.
EOD
    my $fn = shift or die <<'EOD';
Error - No source file name specified.
EOD
    my $fh = IO::File->new ($fn, '<') or die <<"EOD";
Error - Failed to open source file '$fn'.
        $!
EOD
    return <$fh>;
}

#	_trim replaces undefined arguments with '', trims all arguments
#	front and back, and returns the modified arguments.

sub _trim {
    my @args = @_;
    foreach ( @args ) {
	defined $_ or $_ = '';
	s/ \A \s+ //smx;
	s/ \s+ \z //smx;
    }
    return @args;
}

1;

__END__

=back

=head2 Attributes

The following attributes may be modified by the user to affect the
operation of the Astro::SpaceTrack object. The data type of each is
given in parentheses after the attribute name.

Boolean attributes are typically set to 1 for true, and 0 for false.

=over

=item addendum (text)

This attribute specifies text to add to the output of the banner()
method.

The default is an empty string.

=item banner (boolean)

This attribute specifies whether or not the shell() method should emit
the banner text on invocation.

The default is true (i.e. 1).

=item cookie_expires (number)

This attribute specifies the expiration time of the cookie. You should
only set this attribute with a previously-retrieved value, which
matches the cookie.

=item direct (boolean)

This attribute specifies that orbital elements should be fetched
directly from the redistributer if possible. At the moment the only
methods affected by this are celestrak() and spaceflight().

The default is false (i.e. 0).

=item domain_space_track (string)

This attribute specifies the domain name of the Space Track web site.
The user will not normally need to modify this, but if the web site
changes names for some reason, this attribute may provide a way to get
queries going again.

The default is 'www.space-track.org'.

=item fallback (boolean)

This attribute specifies that orbital elements should be fetched from
the redistributer if the original source is offline. At the moment the
only method affected by this is celestrak().

The default is false (i.e. 0).

=item filter (boolean)

If true, this attribute specifies that the shell is being run in filter
mode, and prevents any output to STDOUT except orbital elements -- that
is, if I found all the places that needed modification.

The default is false (i.e. 0).

=item iridium_status_format (string)

This attribute specifies the format of the data returned by the
L<iridium_status()|/iridium_status> method. Valid values are 'kelso' and
'mccants'.  See that method for more information.

The default is 'mccants' for historical reasons, but 'kelso' is probably
preferred.

=item max_range (number)

This attribute specifies the maximum size of a range of NORAD IDs to be
retrieved. Its purpose is to impose a sanity check on the use of the
range functionality.

The default is 500.

=item password (text)

This attribute specifies the Space-Track password.

The default is an empty string.

=item session_cookie (text)

This attribute specifies the session cookie. You should only set it
with a previously-retrieved value.

The default is an empty string.

=item url_iridium_status_kelso (text)

This attribute specifies the location of the celestrak.com Iridium
information. You should normally not change this, but it is provided
so you will not be dead in the water if Dr. Kelso needs to re-arrange
his web site.

The default is 'http://celestrak.com/SpaceTrack/query/iridium.txt'

=item url_iridium_status_mccants (text)

This attribute specifies the location of Mike McCants' Iridium status
page. You should normally not change this, but it is provided so you
will not be dead in the water if Mr. McCants needs to change his
ISP or re-arrange his web site.

The default is 'http://www.io.com/~mmccants/tles/iridium.html'

=item url_iridium_status_sladen (text)

This attribute specifies the location of Rod Sladen's Iridium
Constellation Status page. You should normally not need to change this,
but it is provided so you will not be dead in the water if Mr. Sladen
needs to change his ISP or re-arrange his web site.

The default is 'http://www.rod.sladen.org.uk/iridium.htm'.

=item username (text)

This attribute specifies the Space-Track username.

The default is an empty string.

=item verbose (boolean)

This attribute specifies verbose error messages.

The default is false (i.e. 0).

=item webcmd (string)

This attribute specifies a system command that can be used to launch
a URL into a browser. If specified, the 'help' command will append
a space and the search.cpan.org URL for the documentation for this
version of Astro::SpaceTrack, and spawn that command to the operating
system. You can use 'open' under Mac OS X, and 'start' under Windows.
Anyone else will probably need to name an actual browser.

=item with_name (boolean)

This attribute specifies whether the returned element sets should
include the common name of the body (three-line format) or not
(two-line format). It is ignored if the 'direct' attribute is true;
in this case you get whatever the redistributer provides.

The default is false (i.e. 0).

=back

=head1 ENVIRONMENT

The following environment variables are recognized by Astro::SpaceTrack.

=head2 SPACETRACK_OPT

If environment variable SPACETRACK_OPT is defined at the time an
Astro::SpaceTrack object is instantiated, it is broken on spaces,
and the result passed to the set command.

If you specify username or password in SPACETRACK_OPT and you also
specify SPACETRACK_USER, the latter takes precedence, and arguments
passed explicitly to the new () method take precedence over both.

=head2 SPACETRACK_USER

If environment variable SPACETRACK_USER is defined at the time an
Astro::SpaceTrack object is instantiated, the username and password
will be initialized from it. The value of the environment variable
should be the username followed by a slash ("/") and the password.

An explicit username and/or password passed to the new () method
overrides the environment variable, as does any subsequently-set
username or password.

=head1 EXECUTABLES

A couple specimen executables are included in this distribution:

=head2 SpaceTrack

This is just a wrapper for the shell () method.

=head2 SpaceTrackTk

This provides a Perl/Tk interface to Astro::SpaceTrack.

=head1 BUGS

This software is essentially a web page scraper, and relies on the
stability of the user interface to Space Track. The Celestrak
portion of the functionality relies on the presence of .txt files
named after the desired data set residing in the expected location.
The Human Space Flight portion of the functionality relies on the
stability of the layout of the relevant web pages.

This software has not been tested under a HUGE number of operating
systems, Perl versions, and Perl module versions. It is rather likely,
for example, that the module will die horribly if run with an
insufficiently-up-to-date version of LWP or HTML::Parser.

=head1 MODIFICATIONS

See the F<Changes> file.

=head1 ACKNOWLEDGMENTS

The author wishes to thank Dr. T. S. Kelso of
L<http://celestrak.com/> and the staff of L<http://www.space-track.org/>
(whose names are unfortunately unknown to me) for their co-operation,
assistance and encouragement.

=head1 AUTHOR

Thomas R. Wyant, III (F<wyant at cpan dot org>)

=head1 COPYRIGHT AND LICENSE

Copyright 2005-2011 by Thomas R. Wyant, III (F<wyant at cpan dot org>).

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

The data obtained by this module may be subject to the Space Track user
agreement (L<http://www.space-track.org/perl/user_agreement.pl>).

=cut

# ex: set textwidth=72 :
