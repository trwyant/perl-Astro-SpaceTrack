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

In practice, it is probably not useful to retrieve data from any source
more often than once every four hours, and in fact daily usually
suffices.

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
agreement before using this software to retrieve content from the Space
Track web site.

=head1 DEPRECATION NOTICE: SPACE TRACK VERSION 1 API

The Space Track version 1 API was taken out of service July 16 2013 at
18:00 UT. Therefore, as of version 0.077, an attempt to set the
C<space_track_version> attribute to C<1> will result in a fatal error.
Subsequent releases of this package will remove the code related to the
version 1 API.

=head1 NOTICE: HASH REFERENCE ARGUMENTS NOW VALIDATED

Some of the methods of this class take options as either a leading hash
reference, or as command-line-style options, named with a leading dash.
Before version 0.081_01, options passed as a hash reference
were not validated, and extra hash keys were simply ignored. I have
decided that this behavior is undesirable because it leaves a calling
program with no way to know whether options passed in this way were
honored.

Beginning with version 0.081_01, extra hash keys will
produce warnings. My intent is that these will become fatal after a
phase-in cycle.

Temporarily, environment variable
L<SPACETRACK_SKIP_OPTION_HASH_VALIDATION|/SPACETRACK_SKIP_OPTION_HASH_VALIDATION>
has been provided to help manage the warnings while changes are being
made.

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

our $VERSION = '0.081_01';
our @EXPORT_OK = qw{shell BODY_STATUS_IS_OPERATIONAL BODY_STATUS_IS_SPARE
    BODY_STATUS_IS_TUMBLING};
our %EXPORT_TAGS = (
    status => [qw{BODY_STATUS_IS_OPERATIONAL BODY_STATUS_IS_SPARE
	BODY_STATUS_IS_TUMBLING}],
);

use Carp;
use Getopt::Long 2.33;
use HTTP::Response;
use HTTP::Status qw{
    HTTP_PAYMENT_REQUIRED
    HTTP_NOT_FOUND
    HTTP_I_AM_A_TEAPOT
    HTTP_INTERNAL_SERVER_ERROR
    HTTP_OK
    HTTP_PRECONDITION_FAILED
    HTTP_UNAUTHORIZED
};
use IO::File;
use JSON qw{};
use List::Util qw{ max };
use LWP::UserAgent;	# Not in the base.
use POSIX qw{strftime};
use Scalar::Util 1.07 qw{ blessed openhandle };
use Text::ParseWords;
use Time::Local;
use URI qw{};
# use URI::Escape qw{};

# Number of OIDs to retrieve at once. This is a global variable so I can
# play with it, but it is neither documented nor supported, and I
# reserve the right to change it or delete it without notice.
our $RETRIEVAL_SIZE = 200;

use constant COPACETIC => 'OK';
use constant BAD_SPACETRACK_RESPONSE =>
	'Unable to parse SpaceTrack response';
use constant INVALID_CATALOG =>
	'Catalog name %s invalid. Legal names are %s.';
use constant LAPSED_FUNDING => 'Funding lapsed.';
use constant LOGIN_FAILED => 'Login failed';
use constant NO_CREDENTIALS => 'Username or password not specified.';
use constant NO_CAT_ID => 'No catalog IDs specified.';
use constant NO_OBJ_NAME => 'No object name specified.';
use constant NO_RECORDS => 'No records found.';

use constant SESSION_PATH => '/';

use constant DEFAULT_SPACE_TRACK_REST_SEARCH_CLASS => 'satcat';
use constant DEFAULT_SPACE_TRACK_VERSION => 2;

use constant DUMP_NONE => 0;		# No dump
use constant DUMP_TRACE => 0x01;	# Logic trace
use constant DUMP_REQUEST => 0x02;	# Request content
use constant DUMP_NO_EXECUTE => 0x04;	# Do not execute request
use constant DUMP_COOKIE => 0x08;	# Dump cookies.
use constant DUMP_HEADERS => 0x10;	# Dump headers.
use constant DUMP_CONTENT => 0x20;	# Dump content

# These are the Space Track version 1 retrieve Getopt::Long option
# specifications, and the descriptions of each option. These need to
# survive the returement of Version 1 as a separate entity because I
# emulated them in the celestrak() and spaceflight() methods. I'm _NOT_
# emulating the options added in version 2 because they require parsing
# the TLE.
use constant CLASSIC_RETRIEVE_OPTIONS => [
    descending => '(direction of sort)',
    'end_epoch=s' => 'date',
    last5 => '(ignored if -start_epoch or -end_epoch specified)',
    'sort=s' =>
	"type ('catnum' or 'epoch', with 'catnum' the default)",
    'start_epoch=s' => 'date',
];

my %catalogs = (	# Catalog names (and other info) for each source.
    celestrak => {
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
	beidou => { name => 'Beidou navigational satellites' },
    },
    celestrak_supplemental => {
	gps		=> { name => 'GPS',		rms => 1 },
	glonass		=> { name => 'Glonass',		rms => 1 },
	meteosat	=> { name => 'Meteosat',	rms => 1 },
	intelsat	=> { name => 'Intelsat',	rms => 1 },
	orbcomm		=> { name => 'Orbcomm (no rms data)' },
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
    },
    spacetrack => [	# Numbered by space_track_version
	undef,	# No interface version 0
	{	# Interface version 1 (Original)
	    md5 => {name => 'MD5 checksums', number => 0, special => 1},
	    full => {name => 'Full catalog', number => 1},
	    geosynchronous => {
		name => 'Geosynchronous satellites',
		number => 3
	    },
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
	{	# Interface version 2 (REST)
	    full => {
		name	=> 'Full catalog',
		# We have to go through satcat to eliminate bodies that
		# are not on orbit, since tle_latest includes bodies
		# decayed in the last two years or so
#		satcat	=> {},
		tle	=> {
		    EPOCH	=> '>now-30',
		},
#		number	=> 1,
	    },
	    full_fast => {
		deprecate	=> 'full',
		name	=> 'Full catalog, with some objects no longer in orbit',
		tle	=> {
		    EPOCH	=> '>now-30',
		},
	    },
	    payloads	=> {
		name	=> 'All payloads',
		satcat	=> {
		    OBJECT_TYPE	=> 'PAYLOAD',
		},
	    },
	    geosynchronous => {
		name	=> 'Geosynchronous satellites',
#		number	=> 3,
		# We have to go through satcat to eliminate bodies that
		# are not on orbit, since tle_latest includes bodies
		# decayed in the last two years or so
#		satcat	=> {
#		    PERIOD	=> '1425.6--1454.4'
#		},
		# Note that the v2 interface specimen query is
		#   PERIOD 1430--1450.
		# The v1 definition is
		#   MEAN_MOTION 0.99--1.01
		#   ECCENTRICITY <0.01
#		tle	=> {
#		    ECCENTRICITY	=> '<0.01',
##		    MEAN_MOTION		=> '0.99--1.01',
#		},
		tle	=> {
		    ECCENTRICITY	=> '<0.01',
		    EPOCH		=> '>now-30',
		    MEAN_MOTION		=> '0.99--1.01',
		    OBJECT_TYPE		=> 'payload',
		},
	    },
	    geosynchronous_fast => {
		deprecated	=> 'geosynchronous',
		name	=> 'Geosynchronous satellites',
		tle	=> {
		    ECCENTRICITY	=> '<0.01',
		    EPOCH		=> '>now-30',
		    MEAN_MOTION		=> '0.99--1.01',
		    OBJECT_TYPE		=> 'payload',
		},
	    },
	    navigation => {
		name => 'Navigation satellites',
		favorite	=> 'Navigation',
#		number => 5,
	    },
	    weather => {
		name => 'Weather satellites',
		favorite	=> 'Weather',
#		number => 7,
	    },
	    iridium => {
		name	=> 'Iridium satellites',
		tle => {
		    EPOCH	=> '>now-30',
		    OBJECT_NAME	=> 'iridium~~',
		    OBJECT_TYPE	=> 'payload',
		},
#		number	=> 9,
	    },
	    orbcomm	=> {
		name	=> 'OrbComm satellites',
		tle	=> {
		    EPOCH	=> '>now-30',
		    OBJECT_NAME	=> 'ORBCOMM~~,VESSELSAT~~',
		    OBJECT_TYPE	=> 'payload',
		},
#		number	=> 11,
	    },
	    globalstar => {
		name	=> 'Globalstar satellites',
		tle	=> {
		    EPOCH	=> '>now-30',
		    OBJECT_NAME	=> 'globalstar~~',
		    OBJECT_TYPE	=> 'payload',
		},
#		number	=> 13,
	    },
	    intelsat => {
		name	=> 'Intelsat satellites',
		tle	=> {
		    EPOCH	=> '>now-30',
		    OBJECT_NAME	=> 'intelsat~~',
		    OBJECT_TYPE	=> 'payload',
		},
#		number	=> 15,
	    },
	    inmarsat => {
		name	=> 'Inmarsat satellites',
		tle	=> {
		    EPOCH	=> '>now-30',
		    OBJECT_NAME	=> 'inmarsat~~',
		    OBJECT_TYPE	=> 'payload',
		},
#		number	=> 17,
	    },
	    amateur => {
		favorite	=> 'Amateur',
		name => 'Amateur Radio satellites',
#		number => 19,
	    },
	    visible => {
		favorite	=> 'Visible',
		name => 'Visible satellites',
#		number => 21,
	    },
	    special => {
		favorite	=> 'Special_interest',
		name => 'Special interest satellites',
#		number => 23,
	    },
	},
    ],
);

my %mutator = (	# Mutators for the various attributes.
    addendum => \&_mutate_attrib,		# Addendum to banner text.
    banner => \&_mutate_attrib,
    cookie_expires => \&_mutate_spacetrack_interface,
    cookie_name => \&_mutate_spacetrack_interface,
    direct => \&_mutate_attrib,
    domain_space_track => \&_mutate_spacetrack_interface,
    dump_headers => \&_mutate_attrib,	# Dump all HTTP headers. Undocumented and unsupported.
    fallback => \&_mutate_attrib,
    filter => \&_mutate_attrib,
    iridium_status_format => \&_mutate_iridium_status_format,
    max_range => \&_mutate_number,
    password => \&_mutate_authen,
    pretty => \&_mutate_attrib,
    scheme_space_track => \&_mutate_attrib,
    session_cookie => \&_mutate_spacetrack_interface,
    space_track_version => \&_mutate_space_track_version,
    url_iridium_status_kelso => \&_mutate_attrib,
    url_iridium_status_mccants => \&_mutate_attrib,
    url_iridium_status_sladen => \&_mutate_attrib,
    username => \&_mutate_authen,
    verbose => \&_mutate_attrib,
    verify_hostname => \&_mutate_verify_hostname,
    webcmd => \&_mutate_attrib,
    with_name => \&_mutate_attrib,
);

my %accessor = (
    cookie_expires	=> \&_access_spacetrack_interface,
    cookie_name		=> \&_access_spacetrack_interface,
    domain_space_track	=> \&_access_spacetrack_interface,
    session_cookie	=> \&_access_spacetrack_interface,
);
foreach my $key ( keys %mutator ) {
    exists $accessor{$key}
	or $accessor{$key} = sub { return $_[0]->{$_[1]} };
}

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
	banner => 1,	# shell () displays banner if true.
	direct => 0,	# Do not direct-fetch from redistributors
	dump_headers => DUMP_NONE,	# No dumping.
	fallback => 0,	# Do not fall back if primary source offline
	filter => 0,	# Filter mode.
	iridium_status_format => 'mccants',	# For historical reasons.
	max_range => 500,	# Sanity limit on range size.
	password => undef,	# Login password.
	pretty => 0,		# Pretty-format content
	scheme_space_track => 'https',
	_space_track_interface	=> [
	    undef,
	    {	# Interface version 1
		cookie_expires		=> 0,
		cookie_name		=> 'spacetrack_session',
		domain_space_track	=> 'www.space-track.org',
		session_cookie		=> undef,
	    },
	    {	# Interface version 2
		# This interface does not seem to put an expiration time
		# on the cookie. But the docs say it's only good for a
		# couple hours, so we need this so we can fudge
		# something in when the time comes.
		cookie_expires		=> 0,
		cookie_name		=> 'chocolatechip',
		domain_space_track	=> 'www.space-track.org',
		session_cookie		=> undef,
	    },
	],
	space_track_version	=> DEFAULT_SPACE_TRACK_VERSION,
	url_iridium_status_kelso =>
	    'http://celestrak.com/SpaceTrack/query/iridium.txt',
	url_iridium_status_mccants =>
	    'http://www.prismnet.com/~mmccants/tles/iridium.html',
	url_iridium_status_sladen =>
	    'http://www.rod.sladen.org.uk/iridium.htm',
	username => undef,	# Login username.
	verbose => undef,	# Verbose error messages for catalogs.
	verify_hostname => 1,	# Verify host names by default.
	webcmd => undef,	# Command to get web help.
	with_name => undef,	# True to retrieve three-line element sets.
    };
    bless $self, $class;

    $ENV{SPACETRACK_OPT} and
	$self->set (grep {defined $_} split '\s+', $ENV{SPACETRACK_OPT});

    $ENV{SPACETRACK_USER} and do {
	my ($user, $pass) = split qr{ [:/] }smx, $ENV{SPACETRACK_USER}, 2;
	$self->set (username => $user, password => $pass);
    };

    @args and $self->set (@args);

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
    my $agent = $self->_get_agent();
    foreach my $url (
	'http://www.amsat.org/amsat/ftp/keps/current/nasabare.txt',
    ) {
	my $resp = $agent->get( $url );
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
	return HTTP::Response->new (HTTP_PRECONDITION_FAILED, NO_CAT_ID);

    my $resp = HTTP::Response->new (HTTP_OK, undef, undef, $content);
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
    my ( $self ) = @_;
    ref $self
	or return wantarray ? sort keys %mutator : [sort keys %mutator];
    my $space_track_version = $self->getv( 'space_track_version' );
    my @names = grep {
	$mutator{$_} == \&_mutate_spacetrack_interface ?
	exists $self->{_space_track_interface}[$space_track_version]{$_}
	: 1
    } sort keys %mutator;
    return wantarray ? @names : \@names;
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
	my $url = $self->_make_space_track_base_url();
	return HTTP::Response->new (HTTP_OK, undef, undef, <<"EOD");

@{[__PACKAGE__]} version $VERSION
Perl $perl_version under $^O

This package acquires satellite orbital elements and other data from a
variety of web sites. It is your responsibility to abide by the terms of
use of the individual web sites. In particular, to acquire data from
Space Track ($url/) you must register and
get a username and password, and you may not make the data available to
a third party without prior permission from Space Track.

Copyright 2005-2012 by T. R. Wyant (wyant at cpan dot org).

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

This method takes option C<-json>, specified either command-style (i.e.
C<< $st->box_score( '-json' ) >>) or as a hash reference (i.e. 
C<< $st->box_score( { json => 1 } ) >>). This causes the body of the
response to be the JSON data as returned from Space Track.

This method requires a Space Track username and password. It implicitly
calls the C<login()> method if the session cookie is missing or expired.
If C<login()> fails, you will get the HTTP::Response from C<login()>.

If this method succeeds, the response will contain headers

 Pragma: spacetrack-type = box_score
 Pragma: spacetrack-source = spacetrack

There are no arguments.

=cut

{

    my @fields = qw{ SPADOC_CD
	ORBITAL_PAYLOAD_COUNT ORBITAL_ROCKET_BODY_COUNT
	    ORBITAL_DEBRIS_COUNT ORBITAL_TOTAL_COUNT
	DECAYED_PAYLOAD_COUNT DECAYED_ROCKET_BODY_COUNT
	    DECAYED_DEBRIS_COUNT DECAYED_TOTAL_COUNT
	COUNTRY_TOTAL
	};

    my @head = (
	[ '', 'Objects in Orbit', 'Decayed Objects' ],
	[ 'Country/Organization',
	    'Payload', 'Rocket Body', 'Debris', 'Total',
	    'Payload', 'Rocket Body', 'Debris', 'Total',
	    'Grand Total',
	],
    );

    sub box_score {
	my ( $self, @args ) = @_;

	( my $opt, @args ) = _parse_args(
	    [
		'json!'	=> 'Return data in JSON format',
	    ], @args );

	my $resp = $self->spacetrack_query_v2( qw{
	    basicspacedata query class boxscore
	    format json predicates all
	} );
	$resp->is_success()
	    or return $resp;

	my $data;

	if ( ! $opt->{json} ) {

	    $data = $self->_get_json_object()->decode( $resp->content() );

	    my $content;
	    foreach my $row ( @head ) {
		$content .= join( "\t", @{ $row } ) . "\n";
	    }
	    foreach my $datum ( @{ $data } ) {
		$datum->{SPADOC_CD} eq 'ALL'
		    and $datum->{SPADOC_CD} = 'Total';
		$content .= join( "\t", map { $datum->{$_} } @fields ) . "\n";
	    }

	    $resp = HTTP::Response->new (HTTP_OK, undef, undef, $content);
	}

	$self->_add_pragmata($resp,
	    'spacetrack-type' => 'box_score',
	    'spacetrack-source' => 'spacetrack',
	    'spacetrack-interface' => 2,
	);

	wantarray
	    or return $resp;

	my @table;
	foreach my $row ( @head ) {
	    push @table, [ @{ $row } ];
	}
	$data ||= $self->_get_json_object()->decode( $resp->content() );
	foreach my $datum ( @{ $data } ) {
	    push @table, [ map { $datum->{$_} } @fields ];
	}
	return ( $resp, \@table );
    }
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
this method implicitly calls the C<login()> method if the session cookie
is missing or expired, and returns the SpaceTrack data for the OIDs
fetched from Celestrak. If C<login()> fails, you will get the
HTTP::Response from C<login()>.

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

=item 2012-044

This is the debris of a Breeze-M upper stage (OID 38746, International
Designator 2012-044C), which exploded October 16 2012. As of October 25
there were 81 pieces of debris in the data set.

=back

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

    ( my $opt, @args ) = $self->{direct} ?
	_parse_args( CLASSIC_RETRIEVE_OPTIONS, @args ) :
	_parse_retrieve_args( @args );

    my $name = shift @args;
    $self->_deprecation_notice( celestrak => $name );

    $self->{direct}
	and return $self->_celestrak_direct( $opt, $name );
    my $resp = $self->_get_agent()->get (
	"http://celestrak.com/SpaceTrack/query/$name.txt");
    if ( my $check = $self->_response_check( $resp, celestrak => $name ) ) {
	return $check;
    }
    $self->_convert_content ($resp);
    $self->_dump_headers( $resp );
    $resp = $self->_handle_observing_list( $opt, $resp->content() );
    return ( $resp->is_success || !$self->{fallback} ) ? $resp :
	$self->_celestrak_direct( $opt, $name );
}

=for html <a name="celestrak_supplemental"></a>

=item $resp = $st->celestrak_supplemental ($name);

This method takes the name of a Celestrak supplemental data set and
returns an HTTP::Response object whose content is the relevant element
sets.

These TLE data are B<not> redistributed from Space Track, but are
derived from publicly available ephemeris data for the satellites in
question.

The C<-rms> option can be specified to return the RMS data, if it is
available.

A list of valid names and brief descriptions can be obtained by calling
C<< $st->names( 'celestrak_supplemental' ) >>. If you have set the
C<verbose> attribute true (e.g. C<< $st->set (verbose => 1) >>), the
content of the error response will include this list. Note, however,
that this list does not determine what can be retrieved; if Dr. Kelso
adds a data set, it can be retrieved even if it is not on the list, and
if he removes one, being on the list won't help.

For more information, see
L<http://celestrak.com/NORAD/elements/supplemental/>.

=cut

sub celestrak_supplemental {
    my ($self, @args) = @_;
    delete $self->{_pragmata};

    ( my $opt, @args ) = _parse_args(
	[
	    'rms!' => '(Return RMS data)',
	], @args );

    my $name = shift @args;

    not $opt->{rms}
	or $catalogs{celestrak_supplemental}{$name}{rms}
	or return HTTP::Response->new(
	    HTTP_PRECONDITION_FAILED,
	    "$name does not take the -rms option" );

    $self->_deprecation_notice( celestrak_supplemental => $name );

    my $sfx = $opt->{rms} ? 'rms.txt' : 'txt';
    my $resp = $self->_get_agent()->get (
	"http://celestrak.com/NORAD/elements/supplemental/$name.$sfx" );

    my $check;
    $check = $self->_response_check(
	$resp, celestrak_supplemental => $name, 'direct')
	and return $check;

    $self->_convert_content( $resp );

    $self->_add_pragmata($resp,
	'spacetrack-type'	=> ( $opt->{rms} ? 'rms' : 'orbit' ),
	'spacetrack-source'	=> 'celestrak',
    );

    $self->_dump_headers( $resp );
    return $resp;
}

sub _celestrak_direct {
    my ( $self, $opt, $name ) = @_;
    delete $self->{_pragmata};

    my $resp = $self->_get_agent()->get (
	"http://celestrak.com/NORAD/elements/$name.txt");
    if (my $check = $self->_response_check($resp, celestrak => $name, 'direct')) {
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

    sub _response_check {
	my ($self, $resp, $source, $name, @args) = @_;
	unless ($resp->is_success) {
	    $resp->code == HTTP_NOT_FOUND
		and return $self->_no_such_catalog(
		$source => $name, @args);
	    return $resp;
	}
	if (my $loc = $resp->header('Content-Location')) {
	    if ($loc =~ m/ redirect [.] htm [?] ( \d{3} ) ; /smx) {
		my $msg = "redirected $1";
		@args and $msg = "@args; $msg";
		$1 == HTTP_NOT_FOUND
		    and return $self->_no_such_catalog(
		    $source => $name, $msg);
		return HTTP::Response->new (+$1, "$msg\n")
	    }
	}
	my $type = lc $resp->header('Content-Type')
	    or do {
	    my $msg = 'No Content-Type header found';
	    @args and $msg = "@args; $msg";
	    return $self->_no_such_catalog(
		$source => $name, $msg);
	};
	foreach ( _trim( split ',', $type ) ) {
	    s/ ; .* //smx;
	    $valid_type{$_} and return;
	}
	my $msg = "Content-Type: $type";
	@args and $msg = "@args; $msg";
	return $self->_no_such_catalog(
	    $source => $name, $msg);
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
 'iridium_status': The content is Iridium status.
 'modeldef': The content is a REST model definition.
 'orbit': The content is NORAD data sets.
 'search': The content is Space Track search results.
 'set': The content is the result of a 'set' operation.
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

=item $type = $st->content_interface( $resp );

This method takes the given HTTP::Response object and returns the Space
Track interface version specified by the
C<'Pragma: spacetrack-interface ='> header. The following values are
supported:

 1: The content was obtained using the version 1 interface.
 2: The content was obtained using the version 2 interface.
 undef: The content did not come from Space Track.

If the response object is not provided, it returns the data type
from the last method call that returned an HTTP::Response object.

If the response object B<is> provided, you can call this as a static
method (i.e. as Astro::SpaceTrack->content_type($response)).

=cut

sub content_interface {
    my ($self, $resp) = @_;
    defined $resp or return $self->{_pragmata}{'spacetrack-interface'};
    foreach ($resp->header ('Pragma')) {
	m/ spacetrack-interface \s+ = \s+ (.+) /smxi and return $1;
    }
    return;
}

=for html <a name="country_names"></a>

=item $resp = $st->country_names()

This method returns the list of country abbreviations and names from
the Space Track web site. If it succeeds, the content will be the
abbreviations and names, including headings, with the fields
tab-delimited.

This method takes option C<-json>, specified either command-style
(i.e. C<< $st->country_names( '-json' ) >>) or as a hash reference
(i.e. C<< $st->country_names( { json => 1 } ) >>). This causes the
body of the response to be the JSON representation of a hash whose
keys are the country abbreviations, and whose values are the
corresponding country names.

This method requires a Space Track username and password. It
implicitly calls the C<login()> method if the session cookie is
missing or expired.  If C<login()> fails, you will get the
HTTP::Response from C<login()>.

If this method succeeds, the response will contain headers

 Pragma: spacetrack-type = box_score
 Pragma: spacetrack-source = spacetrack

There are no arguments.

=cut

sub country_names {

    my ( $self, @args ) = @_;

    ( my $opt, @args ) = _parse_args(
	[
	    'json!'	=> 'Return data in JSON format',
	], @args );

    my $resp = $self->spacetrack_query_v2(
	basicspacedata	=> 'query',
	class		=> 'boxscore',
	format		=> 'json',
	predicates	=> 'COUNTRY,SPADOC_CD',
    );
    $resp->is_success()
	or return $resp;

    my $json = $self->_get_json_object();

    my $data = $json->decode( $resp->content() );

    my %dict;
    foreach my $datum ( @{ $data } ) {
	$dict{$datum->{SPADOC_CD}} = $datum->{COUNTRY};
    }

    if ( $opt->{json} ) {

	$resp->content( $json->encode( \%dict ) );

    } else {

	$resp->content(
	    join '',
		join( "\t", 'Abbreviation', 'Country/Organization' )
		    . "\n",
		map { "$_\t$dict{$_}\n" } sort keys %dict
	);

    }

    $self->_add_pragmata( $resp,
	'spacetrack-type'	=> 'country_names',
	'spacetrack-source'	=> 'spacetrack',
	'spacetrack-interface'	=> 2,
    );

    return $resp;
}


=for html <a name="favorite"></a>

=item $resp = $st->favorite( $name )

This method takes the name of a C<favorite> set up by the user on the
Space Track web site, and returns the bodies specified. The 'global'
favorites (e.g.  C<'Navigation'>, C<'Weather'>, and so on) may also be
fetched.  Additionally, the C<-json> option may be specified, either in
command-line format or as a leading hash reference. For example,

 $resp = $st->favorite( '-json', 'Weather' );
 $resp = $st->favorite( { json => 1 }, 'Weather' );

both work.

=cut

sub favorite {
    my ($self, @args) = @_;
    delete $self->{_pragmata};

    ( my $opt, @args ) = _parse_args(
	[
	    'json!'	=> 'Return data in JSON format',
	], @args );

    @args
	and defined $args[0]
	or croak 'Must specify a favorite';
    @args > 1
	and croak 'Can not specify more than one favorite';
    # https://beta.space-track.org/basicspacedata/query/class/tle_latest/favorites/Visible/ORDINAL/1/EPOCH/%3Enow-30/format/3le

    my $rest = $self->_convert_retrieve_options_to_rest( $opt );
    $rest->{favorites}	= $args[0];
    $rest->{EPOCH}	= '>now-30';
    delete $rest->{orderby};

    my $resp = $self->spacetrack_query_v2(
	basicspacedata	=> 'query',
	_sort_rest_arguments( $rest )
    );

    $resp->is_success()
	or return $resp;

    _spacetrack_v2_response_is_empty( $resp )
	and return HTTP::Response->new(
	    HTTP_NOT_FOUND,
	    "Favorite '$args[0]' not found"
	);

    return $resp;
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
calls the C<login()> method if the session cookie is missing or expired.
If C<login()> fails, you will get the HTTP::Response from C<login()>.

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

    my ( $opt, $file ) = _parse_retrieve_args( @args );

    delete $self->{_pragmata};

    if ( ! openhandle( $file ) ) {
	-e $file or return HTTP::Response->new (
	    HTTP_NOT_FOUND, "Can't find file $file");
	my $fh = IO::File->new($file, '<') or
	    return HTTP::Response->new (
		HTTP_INTERNAL_SERVER_ERROR, "Can't open $file: $!");
	$file = $fh;
    }

    local $/ = undef;
    return $self->_handle_observing_list( $opt, <$file> )
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
    my $resp = HTTP::Response->new( HTTP_OK, COPACETIC, undef, $value );
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
	or croak 'No attribute name specified';
    my $code = $accessor{$name}
	or croak "No such attribute as '$name'";
    return $code->( $self, $name );
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
	return HTTP::Response->new (HTTP_OK, undef, undef, 'OK');
    } else {
	my $resp = HTTP::Response->new (HTTP_OK, undef, undef, <<'EOD');
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
    No login needed, but you only get the ISS.
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
	    'unc'	=> BODY_STATUS_IS_TUMBLING,
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
	my $resp = $self->_get_agent()->get(
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

    # Mung an Iridium status hash to assume all actual Iridium
    # satellites are good. This is used to prevent bleed-through from
    # Kelso to McCants, since the latter only reports by exception.
    sub _iridium_status_assume_good {
	my ( $self, $rslt ) = @_;

	foreach my $val ( values %{ $rslt } ) {
	    $val->[1] =~ m/ \A iridium \b /smxi
		or next;
	    $val->[2] = '';
	    $val->[4] = BODY_STATUS_IS_OPERATIONAL;
	}

	return;
    }

    # Get Iridium status from Mike McCants
    sub _iridium_status_mccants {
	my ( $self, undef, $rslt ) = @_;	# $fmt arg not used
	$self->_iridium_status_assume_good( $rslt );
	my $resp = $self->_get_agent()->get(
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

	$self->_iridium_status_assume_good( $rslt );

	my $resp = $self->_get_agent()->get(
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

=for html <a name="launch_sites"></a>

=item $resp = $st->launch_sites()

This method returns the list of launch site abbreviations and names
from the Space Track web site. If it succeeds, the content will be the
abbreviations and names, including headings, with the fields
tab-delimited.

This method takes option C<-json>, specified either command-style
(i.e.  C<< $st->launch_sites( '-json' ) >>) or as a hash reference
(i.e.  C<< $st->launch_sites( { json => 1 } ) >>). This causes the
body of the response to be the JSON representation of a hash whose
keys are the launch site abbreviations, and whose values are the
corresponding launch site names.

If this method succeeds, the response will contain headers

 Pragma: spacetrack-type = launch_sites
 Pragma: spacetrack-source = spacetrack

There are no arguments.

=cut

{
    my @headings = ( 'Abbreviation', 'Launch Site' );

    sub launch_sites {
	my ( $self, @args ) = @_;

	( my $opt, @args ) = _parse_args(
	    [
		'json!'	=> 'Return data in JSON format',
	    ], @args );

	my $resp = $self->spacetrack_query_v2( qw{
	    basicspacedata query class launch_site
	    format json },
		orderby	=> 'SITE_CODE asc',
	    qw{ predicates all
	} );
	$resp->is_success()
	    or return $resp;

	my $json = $self->_get_json_object();

	my $data = $json->decode( $resp->content() );

	my %dict;
	foreach my $datum ( @{ $data } ) {
	    $dict{$datum->{SITE_CODE}} = $datum->{LAUNCH_SITE};
	}

	if ( $opt->{json} ) {

	    $resp->content( $json->encode( \%dict ) );

	} else {

	    $resp->content(
		join '',
		join( "\t", @headings ) . "\n",
		map { "$_\t$dict{$_}\n" } sort keys %dict
	    );

	}

	$self->_add_pragmata($resp,
	    'spacetrack-type' => 'launch_sites',
	    'spacetrack-source' => 'spacetrack',
	    'spacetrack-interface' => 2,
	);

	wantarray
	    or return $resp;

	my @table;
	push @table, [ @headings ];
	foreach my $key ( sort keys %dict ) {
	    push @table, [ $key, $dict{$key} ];
	}
	return ( $resp, \@table );
    }
}


=for html <a name="login"></a>

=item $resp = $st->login ( ... )

If any arguments are given, this method passes them to the set ()
method. Then it executes a login to the Space Track web site. The return
is normally the HTTP::Response object from the login. But if no session
cookie was obtained, the return is an HTTP::Response with an appropriate
message and the code set to HTTP_UNAUTHORIZED from HTTP::Status (a.k.a.
401). If a login is attempted without the username and password being
set, the return is an HTTP::Response with an appropriate message and the
code set to HTTP_PRECONDITION_FAILED from HTTP::Status (a.k.a. 412).

A Space Track username and password are required to use this method.

=cut

sub login {
    my ( $self, @args ) = @_;
    delete $self->{_pragmata};
    @args and $self->set( @args );
    ( $self->{username} && $self->{password} ) or
	return HTTP::Response->new (
	    HTTP_PRECONDITION_FAILED, NO_CREDENTIALS);
    $self->{dump_headers} & DUMP_TRACE and warn <<"EOD";
Logging in as $self->{username}.
EOD

    # Do not use the spacetrack_query_v2 method to retrieve the session
    # cookie, unless you like bottomless recursions.
    my $url = $self->_make_space_track_base_url( 2 );
    my $resp = $self->_get_agent()->post(
	"$url/ajaxauth/login", [
	    identity => $self->{username},
	    password => $self->{password},
	] );

    $resp->is_success
	or return _mung_login_status( $resp );
    $self->_dump_headers( $resp );

    $self->_record_cookie_generic( 2 )
	or return HTTP::Response->new( HTTP_UNAUTHORIZED, LOGIN_FAILED );

    $self->{dump_headers} & DUMP_TRACE and warn <<'EOD';
Login successful.
EOD
    return HTTP::Response->new (HTTP_OK, undef, undef, "Login successful.\n");
}

=for html <a name="logout"></a>

=item $st->logout()

This method deletes all session cookies. It returns an HTTP::Response
object that indicates success.

=cut

sub logout {
    my ( $self ) = @_;
    foreach my $spacetrack_interface_info (
	@{ $self->{_space_track_interface} } ) {
	$spacetrack_interface_info
	    or next;
	exists $spacetrack_interface_info->{session_cookie}
	    and $spacetrack_interface_info->{session_cookie} = undef;
	exists $spacetrack_interface_info->{cookie_expires}
	    and $spacetrack_interface_info->{cookie_expires} = 0;
    }
    return HTTP::Response->new(
	HTTP_OK, undef, undef, "Logout successful.\n" );
}

=for html <a name="names"></a>

=item $resp = $st->names (source)

This method retrieves the names of the catalogs for the given source,
either C<'celestrak'>, C<'iridium_status'>, C<'spaceflight'>, or
C<'spacetrack'>, in the content of the given HTTP::Response object. In
list context, you also get a reference to a list of two-element lists;
each inner list contains the description and the catalog name, in that
order (suitable for inserting into a Tk Optionmenu).

No Space Track username and password are required to use this method,
since all it is doing is returning data kept by this module.

=cut

sub names {
    my ( $self, $name ) = @_;
    $name = lc $name;
    delete $self->{_pragmata};

    $catalogs{$name} or return HTTP::Response (
	    HTTP_NOT_FOUND, "Data source '$name' not found.");
    my $src = $catalogs{$name};
    $name eq 'spacetrack'
	and $src = $src->[ $self->getv( 'space_track_version' ) ];
    my @list;
    foreach my $cat (sort keys %$src) {
	push @list, defined ($src->{$cat}{number}) ?
	    "$cat ($src->{$cat}{number}): $src->{$cat}{name}\n" :
	    "$cat: $src->{$cat}{name}\n";
    }
    my $resp = HTTP::Response->new (HTTP_OK, undef, undef, join ('', @list));
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

You can specify options for the retrieval as either command-type options
(e.g. C<< retrieve ('-last5', ...) >>) or as a leading hash reference
(e.g. C<< retrieve ({last5 => 1}, ...) >>). If you specify the hash
reference, option names must be specified in full, without the leading
'-', and the argument list will not be parsed for command-type options.
If you specify command-type options, they may be abbreviated, as long as
the abbreviation is unique. Errors in either sort result in an exception
being thrown.

The legal options are:

 -descending
   specifies the data be returned in descending order.
 -end_epoch date
   specifies the end epoch for the desired data.
 -json
   specifies the TLE be returned in JSON format
 -last5
   specifies the last 5 element sets be retrieved.
   Ignored if start_epoch or end_epoch specified.
 -start_epoch date
   specifies the start epoch for the desired data.
 -since_file number
   specifies that only data since the given Space Track
   file number be retrieved.
 -sort type
   specifies how to sort the data. Legal types are
   'catnum' and 'epoch', with 'catnum' the default.

If you specify either start_epoch or end_epoch, you get data with epochs
at least equal to the start epoch, but less than the end epoch (i.e. the
interval is closed at the beginning but open at the end). If you specify
only one of these, you get a one-day interval. Dates are specified
either numerically (as a Perl date) or as numeric year-month-day (and
optional hour, hour:minute, or hour:minute:second, but these are ignored
under the Space Track version 1 interface), punctuated by any
non-numeric string. It is an error to specify an end_epoch before the
start_epoch.

If you are passing the options as a hash reference, you must specify
a value for the boolean options 'descending' and 'last5'. This value is
interpreted in the Perl sense - that is, undef, 0, and '' are false,
and anything else is true.

In order not to load the Space Track web site too heavily, data are
retrieved in batches of 50. Ranges will be subdivided and handled in
more than one retrieval if necessary. To limit the damage done by a
pernicious range, ranges greater than the max_range setting (which
defaults to 500) will be ignored with a warning to STDERR.

If you specify C<-json> and more than one retrieval is needed, data from
retrievals after the first B<may> have field C<_file_of_record> added.
This is because of the theoretical possibility that the database may be
updated between the first and last queries, and therefore taking the
maximum C<FILE> from queries after the first may cause updates to be
skipped. The C<_file_of_record> key will appear only in data having a
C<FILE> value greater than the largest C<FILE> in the first retrieval.

This method implicitly calls the C<login()> method if the session cookie
is missing or expired. If C<login()> fails, you will get the
HTTP::Response from C<login()>.

If this method succeeds, a 'Pragma: spacetrack-type = orbit' header is
added to the HTTP::Response object returned.

=cut

sub retrieve {
    my ( $self, @args ) = @_;
    delete $self->{_pragmata};

    @args = _parse_retrieve_args( @args );
    my $opt = _parse_retrieve_dates( shift @args );

    my $rest = $self->_convert_retrieve_options_to_rest( $opt );

    @args = $self->_expand_oid_list( @args )
	or return HTTP::Response->new( HTTP_PRECONDITION_FAILED, NO_CAT_ID );

    my $no_execute = $self->getv( 'dump_headers' ) & DUMP_NO_EXECUTE;

##  $rest->{orderby} = 'EPOCH desc';

    my $context = {};
    my $accumulator = (
	$rest->{format} eq 'json' || $no_execute
    ) ? \&_accumulate_data_json : \&_accumulate_data_tle;

    while ( @args ) {

	my @batch = splice @args, 0, $RETRIEVAL_SIZE;
	$rest->{OBJECT_NUMBER} = _stringify_oid_list( {
		separator	=> ',',
		range_operator	=> _rest_range_operator(),
	    }, @batch );

	my $resp = $self->spacetrack_query_v2(
	    basicspacedata	=> 'query',
	    _sort_rest_arguments( $rest )
	);

	$resp->is_success()
	    or $resp->code() == HTTP_I_AM_A_TEAPOT
	    or return $resp;

	$accumulator->( $self, $context, $resp );

    }

    $context->{data}
	or return HTTP::Response->new ( HTTP_NOT_FOUND, NO_RECORDS );

    ref $context->{data}
	and $context->{data} = $self->_get_json_object()->encode(
	$context->{data} );

    $no_execute
	and return HTTP::Response->new(
	    HTTP_I_AM_A_TEAPOT, undef, undef, $context->{data} );

    my $resp = HTTP::Response->new( HTTP_OK, COPACETIC, undef,
	$context->{data} );

    $self->_convert_content( $resp );
    $self->_add_pragmata( $resp,
	'spacetrack-type' => 'orbit',
	'spacetrack-source' => 'spacetrack',
	'spacetrack-interface' => 2,
    );
    return $resp;
}

{

    my %rest_sort_map = (
	catnum	=> 'OBJECT_NUMBER',
	epoch	=> 'EPOCH',
    );

    sub _convert_retrieve_options_to_rest {
	my ( $self, $opt ) = @_;

	my %rest = ( class	=> 'tle_latest' );

	if ( $opt->{start_epoch} || $opt->{end_epoch} ) {
	    $rest{EPOCH} = join '--', map { _rest_date( $opt->{$_} ) }
	    qw{ _start_epoch _end_epoch };
	    $rest{class} = 'tle';
	} else {
	    $rest{sublimit} = $opt->{last5} ? 5 : 1;
	}

	$rest{orderby} = ( $rest_sort_map{$opt->{sort} || 'catnum'} ||
	    'OBJECT_NUMBER' )
	.  ( $opt->{descending} ? ' desc' : ' asc' );

	$opt->{json}
	    and $rest{format} = 'json';

	if ( $opt->{since_file} ) {
	    $rest{FILE} = ">$opt->{since_file}";
	    $rest{class} = 'tle';
	}

	if ( $opt->{status} && $opt->{status} ne 'onorbit' ) {
	    $rest{class} = 'tle';
	}

	foreach my $name (
	    qw{ class format },
	    qw{ ECCENTRICITY FILE MEAN_MOTION OBJECT_NAME },
	) {
	    defined $opt->{$name}
		and $rest{$name} = $opt->{$name};
	}

	defined $rest{format}
	    or $rest{format} = 'tle';

	$rest{format} eq 'tle'
	    and $self->{with_name}
	    and $rest{format} = '3le';

	$rest{format} eq '3le'
	    and not defined $rest{predicates}
	    and $rest{predicates} = 'OBJECT_NAME,TLE_LINE1,TLE_LINE2';

	if ( $rest{class} eq 'tle_latest' ) {
	    if ( defined $rest{sublimit} && $rest{sublimit} <= 5 ) {
		my $limit = delete $rest{sublimit};
		$rest{ORDINAL} = $limit > 1 ? "1--$limit" : $limit;
	    }
	}

	return \%rest;
    }

}

{

    my %status_query = (
	onorbit	=> 'null-val',
	decayed	=> '<>null-val',
	all	=> '',
    );

    my %exclude_map = (
	rocket	=> 1 << 0,
	debris	=> 1 << 1,
    );

    my @exclude_query = (
	undef,
	'PAYLOAD,DEBRIS,UNKNOWN,TBA,OTHER',
	'PAYLOAD,ROCKET BODY,UNKNOWN,TBA,OTHER',
	'PAYLOAD,UNKNOWN,TBA,OTHER',
    );

    sub _convert_search_options_to_rest {
	my ( $self, $opt ) = @_;
	my %rest;

	if ( defined $opt->{status} ) {
	    defined ( my $query = $status_query{$opt->{status}} )
		or croak "Unknown status '$opt->{status}'";
	    $query
		and $rest{DECAY} = $query;
	}

	{
	    my $inx = 0;
	    foreach my $excl ( @{ $opt->{exclude} || [] } ) {
		defined $exclude_map{$excl}
		    or croak "Unknown excludion '$excl'";
		$inx |= $exclude_map{$excl};
	    }
	    defined $exclude_query[$inx]
		and $rest{OBJECT_TYPE} = $exclude_query[$inx];
	}

	return \%rest;
    }
}

{

    my %headings = (
	OBJECT_NUMBER	=> 'Catalog Number',
	OBJECT_NAME	=> 'Common Name',
	OBJECT_ID	=> 'International Designator',
	COUNTRY		=> 'Country',
	LAUNCH		=> 'Launch Date',
	SITE		=> 'Launch Site',
	DECAY		=> 'Decay Date',
	PERIOD		=> 'Period',
	APOGEE		=> 'Apogee',
	PERIGEE		=> 'Perigee',
	RCSVALUE	=> 'RCS',
    );
    my @heading_order = qw{
	OBJECT_NUMBER OBJECT_NAME OBJECT_ID COUNTRY LAUNCH SITE DECAY
	PERIOD APOGEE PERIGEE RCSVALUE
    };

    sub _search_rest {
	my ( $self, $pred, $xfrm, @args ) = @_;
	delete $self->{_pragmata};

	@args = _parse_search_args( @args );
	my $opt = shift @args;

	if ( $pred eq 'OBJECT_NUMBER' ) {

	    @args = $self->_expand_oid_list( @args )
		or return HTTP::Response->new(
		    HTTP_PRECONDITION_FAILED, NO_CAT_ID );

	    @args = (
		_stringify_oid_list( {
			separator	=> ',',
			range_operator	=> _rest_range_operator(),
		    },
		    @args
		)
	    );

	}

	my $want_tle = exists $opt->{tle} ? $opt->{tle} : 1;

	my $rest_args = $self->_convert_search_options_to_rest( $opt );

	my $class = defined $rest_args->{class} ?
	    $rest_args->{class} :
	    DEFAULT_SPACE_TRACK_REST_SEARCH_CLASS;

	my @found;

	foreach my $search_for ( map { $xfrm->( $_, $class ) } @args ) {

	    my $rslt;
	    {
		local $self->{pretty} = 0;
		$rslt = $self->__search_rest_raw( %{ $rest_args },
		    $pred, $search_for );
	    }

	    $rslt->is_success()
		or return $rslt;

	    my $data = $self->_get_json_object()->decode( $rslt->content() );

	    push @found , @{ $data };

	}

	my $rslt;

	if ( $want_tle ) {

	    my $with_name = $self->{with_name};

	    my $ropt = _remove_search_options( $opt );

##	    $ropt->{format} = 'json';
	    $ropt->{json} = 1;

	    {
		local $self->{pretty} = 0;
		$rslt = $self->retrieve( $ropt,
		    map { $_->{OBJECT_NUMBER} } @found );
	    }
	    $rslt->is_success()
		or return $rslt;
	    my %search_info = map { $_->{OBJECT_NUMBER} => $_ } @found;
	    my $bodies = $self->_get_json_object()->decode( $rslt->content() );
	    my $content;
	    foreach my $body ( @{ $bodies } ) {
		my $info = $search_info{$body->{OBJECT_NUMBER}};
		if ( $opt->{json} ) {
		    if ( $opt->{rcs} ) {
			$body->{RCSVALUE} = $info->{RCSVALUE};
		    }
		} else {
		    my @line_0;
		    $with_name
			and push @line_0, defined $info->{OBJECT_NAME} ?
			    $info->{OBJECT_NAME} :
			    $body->{TLE_LINE0};
		    $opt->{rcs}
			and defined $info->{RCSVALUE}
			and push @line_0, "--rcs $info->{RCSVALUE}";
		    @line_0
			and $content .= join( ' ', @line_0 ) . "\n";
		    $content .= <<"EOD";
$body->{TLE_LINE1}
$body->{TLE_LINE2}
EOD
		}
	    }

	    $opt->{json}
		and $content = $self->_get_json_object()->encode( $bodies );

	    $rslt = HTTP::Response->new( HTTP_OK, undef, undef, $content );
	    $self->_add_pragmata( $rslt,
		'spacetrack-type' => 'orbit',
		'spacetrack-source' => 'spacetrack',
		'spacetrack-interface' => 2,
	    );

	} else {

	    my $content;
	    if ( $opt->{json} ) {
		$content = $self->_get_json_object()->encode( \@found );
	    } else {
		foreach my $datum (
		    \%headings,
		    @found
		) {
		    $content .= join( "\t",
			map { defined $datum->{$_} ? $datum->{$_} : '' }
			@heading_order
		    ) . "\n";
		}
	    }
	    $rslt = HTTP::Response->new( HTTP_OK, undef, undef, $content );
	    $self->_add_pragmata( $rslt,
		'spacetrack-type' => 'search',
		'spacetrack-source' => 'spacetrack',
		'spacetrack-interface' => 2,
	    );

	}

	wantarray
	    or return $rslt;

	my @table;
	foreach my $datum (
	    \%headings,
	    @found
	) {
	    push @table, [ map { $datum->{$_} } @heading_order ];
	}

	return ( $rslt, \@table );

	# Note - if we're doing the tab output, the names and order are:
	# Catalog Number: OBJECT_NUMBER
	# Common Name: OBJECT_NAME
	# International Designator: OBJECT_ID
	# Country: COUNTRY
	# Launch Date: LAUNCH (yyyy-mm-dd)
	# Launch Site: SITE
	# Decay Date: DECAY
	# Period: PERIOD
	# Incl.: INCLINATION
	# Apogee: APOGEE
	# Perigee: PERIGEE
	# RCS: RCSVALUE

    }

}

sub __search_rest_raw {
    my ( $self, %args ) = @_;
    delete $self->{_pragmata};
    # https://beta.space-track.org/basicspacedata/query/class/satcat/CURRENT/Y/OBJECT_NUMBER/25544/predicates/all/limit/10,0/metadata/true

    %args
	or return HTTP::Response->new( HTTP_PRECONDITION_FAILED, NO_CAT_ID );

    exists $args{class}
	or $args{class} = DEFAULT_SPACE_TRACK_REST_SEARCH_CLASS;
    $args{class} ne 'satcat'
	or exists $args{CURRENT}
	or $args{CURRENT} = 'Y';
    exists $args{format}
	or $args{format} = 'json';
    exists $args{predicates}
	or $args{predicates} = 'all';
    exists $args{orderby}
	or $args{orderby} = 'OBJECT_NUMBER asc';
#   exists $args{limit}
#	or $args{limit} = 1000;

    my $resp = $self->spacetrack_query_v2(
	basicspacedata	=> 'query',
	_sort_rest_arguments( \%args ),
    );
#   $resp->content( $content );
#   $self->_convert_content( $resp );
    $self->_add_pragmata( $resp,
	'spacetrack-type' => 'orbit',
	'spacetrack-source' => 'spacetrack',
	'spacetrack-interface' => 2,
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

 -exclude
   specifies the types of bodies to exclude. The
   value is one or more of 'debris' or 'rocket'.
   If you specify both as command-style options,
   you may either specify the option more than once,
   or specify the values comma-separated.
 -rcs
   specifies that the radar cross-section returned by
   the search is to be appended to the name, in the form
   --rcs radar_cross_section. If the with_name attribute
   is false, the radar cross-section will be inserted as
   the name. Historical rcs data appear NOT to be
   available.
 -status
   specifies the desired status of the returned body
   (or bodies). Must be 'onorbit', 'decayed', or 'all'.
   The default is 'all' under version 1 of the Space
   Track interface, and 'onorbit' under version 2. Note
   that this option represents status at the time the
   search was done; you can not combine it with the
   retrieve() date options to find bodies onorbit as of
   a given date in the past.
 -tle
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

The C<-exclude> option is implemented in terms of the C<OBJECT_TYPE>
predicate, which is one of the values C<'PAYLOAD'>, C<'ROCKET BODY'>,
C<'DEBRIS'>, C<'UNKNOWN'>, C<'TBA'>, or C<'OTHER'>. It works by
selecting all values other than the ones specifically excluded. The
C<'TBA'> status was introduced October 1 2013, supposedly replacing
C<'UNKNOWN'>, but I have retained both.

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

sub search_date {	## no critic (RequireArgUnpacking)
    splice @_, 1, 0, LAUNCH => \&_format_launch_date_rest;
    goto &_search_rest;
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

sub search_decay {	## no critic (RequireArgUnpacking)
    splice @_, 1, 0, DECAY => \&_format_launch_date_rest;
    goto &_search_rest;
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

This method implicitly calls the C<login()> method if the session cookie
is missing or expired. If C<login()> fails, you will get the
HTTP::Response from C<login()>.

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

sub search_id {	## no critic (RequireArgUnpacking)
    splice @_, 1, 0, OBJECT_ID => \&_format_international_id_rest;
    goto &_search_rest;
}


=for html <a name="search_name"></a>

=item $resp = $st->search_name (name ...)

This method searches the Space Track database for the named objects.
Matches are case-insensitive and all matches are returned.

The options are the same as for L</search_date>. The C<-status> option
is known to work, but I am not sure about the efficacy the C<-exclude>
option.

A Space Track username and password are required to use this method.

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

sub search_name {	## no critic (RequireArgUnpacking)
    splice @_, 1, 0, OBJECT_NAME => sub { return "~~$_[0]" };
    goto &_search_rest;
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

sub search_oid {	## no critic (RequireArgUnpacking)
    my ( $self, @args ) = @_;
    splice @_, 1, 0, OBJECT_NUMBER => sub { return $_[0] };
    goto &_search_rest;
}

sub _check_range {
    my ( $self, $lo, $hi ) = @_;
    ($lo, $hi) = ($hi, $lo) if $lo > $hi;
    $lo or $lo = 1;	# 0 is illegal
    $hi - $lo >= $self->{max_range} and do {
	carp <<"EOD";
Warning - Range $lo-$hi ignored because it is greater than the
	  currently-set maximum of $self->{max_range}.
EOD
	return;
    };
    return ( $lo, $hi );
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
    my $resp = HTTP::Response->new( HTTP_OK, COPACETIC, undef, COPACETIC );
    $self->_add_pragmata( $resp,
	'spacetrack-type' => 'set',
    );
    $self->_dump_headers( $resp );
    return $resp;
}


=for html <a name="shell"></a>

=item $st->shell ()

This method implements a simple shell. Any public method name except
'new' or 'shell' is a command, and its arguments if any are parameters.
We use L<Text::ParseWords|Text::ParseWords> to parse the line, and blank
lines or lines beginning with a hash mark ('#') are ignored. Input is
via Term::ReadLine if that is available. If not, we do the best we can.

We also recognize 'bye' and 'exit' as commands, which terminate the
method. In addition, 'show' is recognized as a synonym for 'get', and
'get' (or 'show') without arguments is special-cased to list all
attribute names and their values. Attributes listed without a value have
the undefined value.

There are also a couple meta-commands, that in effect wrap other
commands. These are specified before the command, and can (depending on
the meta-command) have effect either right before the command is
executed, right after it is executed, or both. If more than one
meta-command is specified, the before-actions take place in the order
specified, and the after-actions in the reverse of the order specified.

The 'time' meta-command times the command, and writes the timing to
standard error before any output from the command is written.

The 'olist' meta-command turns TLE data into an observing list. This
only affects results with C<spacetrack-type> of C<'orbit'>. If the
content is affected, the C<spacetrack-type> will be changed to
C<'observing-list'>. This meta-command is experimental, and may change
function or be retracted.  It is unsupported when applied to commands
that do not return TLE data.

For commands that produce output, we allow a sort of pseudo-redirection
of the output to a file, using the syntax ">filename" or ">>filename".
If the ">" is by itself the next argument is the filename. In addition,
we do pseudo-tilde expansion by replacing a leading tilde with the
contents of environment variable HOME. Redirection can occur anywhere
on the line. For example,

 SpaceTrack> catalog special >special.txt

sends the "Special Interest Satellites" to file special.txt. Line
terminations in the file should be appropriate to your OS.

Redirections will not be recognized as such if quoted or escaped. That
is, both C<< >foo >> and C<< >'foo' >> (without the double quotes) are
redirections to file F<foo>, but both "C<< '>foo' >>" and C<< \>foo >>
are arguments whose value is C<< >foo >>.

This method can also be called as a subroutine - i.e. as

 Astro::SpaceTrack::shell (...)

Whether called as a method or as a subroutine, each argument passed
(if any) is parsed as though it were a valid command. After all such
have been executed, control passes to the user. Unless, of course,
one of the arguments was 'exit'.

Unlike most of the other methods, this one returns nothing.

=cut

my $rdln;
my %known_meta = (
    olist	=> {
	after	=> sub {
	    my ( $self, $context, $rslt ) = @_;

	    'ARRAY' eq ref $rslt
		and return;
	    $rslt->is_success()
		and 'orbit' eq ( $self->content_type( $rslt ) || '' )
		or return;

	    my $content = $rslt->content();
	    my @lines;

	    if ( $content =~ m/ \A [[]? [{] /smx ) {
		my $data = $self->_get_json_object()->decode( $content );
		foreach my $datum ( @{ $data } ) {
		    push @lines, [
			sprintf '%05d', $datum->{OBJECT_NUMBER},
			defined $datum->{OBJECT_NAME} ? $datum->{OBJECT_NAME} :
			(),
		    ];
		}
	    } else {

		my @name;

		foreach ( split qr{ \n }smx, $content ) {
		    if ( m/ \A 1 \s+ ( \d+ ) /smx ) {
			splice @name, 1;
			push @lines, [ sprintf( '%05d', $1 ), @name ];
			@name = ();
		    } elsif ( m/ \A 2 \s+ \d+ /smx || m/ \A \s* [#] /smx ) {
		    } else {
			push @name, $_;
		    }
		}
	    }

	    foreach ( $rslt->header( pragma => undef ) ) {
		my ( $name, $value ) = split qr{ \s* = \s* }smx, $_, 2;
		'spacetrack-type' eq $name
		    and $value = 'observing_list';
		$self->_add_pragmata( $rslt, $name, $value );
	    }

	    $rslt->content( join '', map { "$_\n" } @lines );

	    {
		local $" = '';	# Make "@a" equivalent to join '', @a.
		$rslt->content( join '',
		    map { "@$_\n" }
		    sort { $a->[0] <=> $b->[0] }
		    @lines
		);
	    }
	    $self->_dump_headers( $rslt );
	    return;
	},
    },
    time	=> {
	before	=> sub {
	    my ( $self, $context ) = @_;
	    eval {
		require Time::HiRes;
		$context->{start_time} = Time::HiRes::time();
		1;
	    } or warn 'No timings available. Can not load Time::HiRes';
	    return;
	},
	after	=> sub {
	    my ( $self, $context, $rslt ) = @_;
	    $context->{start_time}
		and warn sprintf "Elapsed time: %.2f seconds\n",
		    Time::HiRes::time() - $context->{start_time};
	    return;
	}
    },
);

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

	# Break the buffer up into tokens, but leave quotes and escapes
	# in place, so that (e.g.) '\>foo' is seen as an argument, not a
	# redirection.

	my @cmdarg = parse_line( '\s+', 1, $buffer );

	# Pull off any redirections.

	my $redir = '';
	@cmdarg = map {
	    m/ \A > /smx ? do {$redir = $_; ()} :
	    $redir =~ m/ \A >+ \z /smx ? do {$redir .= $_; ()} :
	    $_
	} @cmdarg;

	# Rerun everything through parse_line again, but with the $keep
	# argument false. This should not create any more tokens, it
	# should just un-quote and un-escape the data.

	@cmdarg = map { parse_line( qr{ \s+ }, 0, $_ ) } @cmdarg;
	$redir ne ''
	    and ( $redir ) = parse_line ( qr{ \s+ }, 0, $redir );

	$redir =~ s/ \A (>+) ~ /$1$ENV{HOME}/smx;
	my $verb = lc shift @cmdarg;

	my %meta_command = (
	    before	=> [],
	    after	=> [],
	);

	while ( my $def = $known_meta{$verb} ) {
	    my %context;
	    foreach my $key ( qw{ before after } ) {
		$def->{$key}
		    or next;
		push @{ $meta_command{$key} }, sub {
		    return $def->{$key}->( $self, \%context, @_ );
		};
	    }
	    $verb = shift @cmdarg;
	}

	last if $verb eq 'exit' || $verb eq 'bye';
	$verb eq 'show' and $verb = 'get';
	$verb eq 'source' and do {
	    eval {
		splice @args, 0, 0, $self->_source (shift @cmdarg);
		1;
	    } or warn ( $@ || 'An unknown error occurred' );	## no critic (RequireCarping)
	    next;
	};

	$verb ne 'new'
	    and $verb ne 'shell'
	    and $verb !~ m/ \A _ [^_] /smx
	    or do {
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

	foreach my $pseudo ( @{ $meta_command{before} } ) {
	    $pseudo->();
	}

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

	foreach my $pseudo ( reverse @{ $meta_command{after} } ) {
	    $pseudo->( $rslt );
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
	    $rslt->code() == HTTP_I_AM_A_TEAPOT
		and print { $out } $rslt->content(), "\n";
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
spaceflight site, L<http://spaceflight.nasa.gov/>. As of July 21 2011
you only get the International Space Station.

You can specify the argument 'ISS' (case-insensitive) to explicitly
retrieve the data for the International Space Station, but as of July 21
2011 this is equivalent to specifying no argument and getting
everything.

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

{
    my %dig_deeper = (
	'http://notice.usa.gov'	=> sub {
	    my ( $resp ) = @_;
	    my $content = $resp->content();
	    $content =~ m/ \b funding \b /smx
		and $content =~ m/ \b not \s+ available \b /smx
		or return;
	    $resp->code( HTTP_PAYMENT_REQUIRED );
	    $resp->message( LAPSED_FUNDING );
	    return;
	},
    );

    sub __tweak_response {
	my ( $resp ) = @_;
	$resp->is_success()
	    or return;
	my $url = $resp->request()->url();
	ref $url
	    and $url = $url->as_string();
	$url =~ s{ / \z }{}smx;
	my $code = $dig_deeper{$url}
	    or return;
	$code->( $resp );
	return;
    }
}

sub spaceflight {
    my ($self, @args) = @_;
    delete $self->{_pragmata};

    @args = _parse_args(
	[
	    'all!' => 'retrieve all data',
	    'effective!' => 'include effective date',
	    # The below are the version 1 retrieval options, which are
	    # emulated for this method. See the definition of
	    # CLASSIC_RETRIEVE_OPTIONS for more information.
	    @{ CLASSIC_RETRIEVE_OPTIONS() },
	],
	@args );
    my $opt = _parse_retrieve_dates( shift @args );

    $opt->{all} = 0 if $opt->{last5} || $opt->{start_epoch};
    $opt->{sort} ||= _validate_sort( $opt->{sort} );

    my @list;
    if (@args) {
	foreach (@args) {
	    $self->_deprecation_notice( spaceflight => $_ );
	    my $info = $catalogs{spaceflight}{lc $_} or
		return $self->_no_such_catalog (spaceflight => $_);
	    exists $info->{url}
		and push @list, $info->{url};
	}
    } else {
	my $hash = $catalogs{spaceflight};
	@list = map { $hash->{$_}{url} }
	    grep { exists $hash->{$_}{url} }
	    sort keys %$hash;
    }

    my $content = '';
    my $html = '';
    my $now = time ();
    my %tle;
    foreach my $url (@list) {
	my $resp = $self->_get_agent()->get ($url);
	__tweak_response( $resp );
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
	or return HTTP::Response->new( HTTP_PRECONDITION_FAILED,
	    NO_RECORDS, undef, $html );

    my $resp = HTTP::Response->new (HTTP_OK, undef, undef, $content);
    $self->_add_pragmata($resp,
	'spacetrack-type' => 'orbit',
	'spacetrack-source' => 'spaceflight',
    );
    $self->_dump_headers( $resp );
    return $resp;
}

=for html <a name="spacetrack"></a>

=item $resp = $st->spacetrack ($name);

This method returns predefined sets of data from the Space Track web
site, using either canned queries or global favorites.

The following catalogs are available:

    Name            Description
    full            Full catalog
    full_fast       Full catalog, faster but less
                        accurate query (DEPRECATED)
    payloads        All payloads
    navigation      Navigation satellites
    weather         Weather satellites
    geosynchronous  Geosynchronous bodies
    geosynchronous_fast Geosynchronous bodies, faster
                        but less accurate query (DEPRECATED)
    iridium         Iridium satellites
    orbcomm         OrbComm satellites
    globalstar      Globalstar satellites
    intelsat        Intelsat satellites
    inmarsat        Inmarsat satellites
    amateur         Amateur Radio satellites
    visible         Visible satellites
    special         Special satellites

The C<*_fast> queries are, as of version 0.069_02, the same
as their un-fast versions. The queries are those implemented on the
Space Track web site, and B<may> included recently-decayed satellites.

The C<*_fast> queries are also deprecated as of version
0.069_02. Because these were always considered unsupported,
the deprecation cycle will be accelerated. They will C<carp()> on every
use, and six months after release 0.070 will produce fatal errors. Six
months after they become fatal, they will be removed completely.

The following option is supported:

 -json
   specifies the TLE be returned in JSON format

Options may be specified either in command-line style
(that is, as C<< spacetrack( '-json', ... ) >>) or as a hash reference
(that is, as C<< spacetrack( { json => 1 }, ... ) >>).

This method returns an L<HTTP::Response|HTTP::Response> object. If the
operation succeeded, the content of the response will be the requested
data, unzipped if you used the version 1 interface.

If you requested a non-existent catalog, the response code will be
C<HTTP_NOT_FOUND> (a.k.a.  404); otherwise the response code will be
whatever the underlying HTTPS request returned.

A Space Track username and password are required to use this method.

If this method succeeds, the response will contain headers

 Pragma: spacetrack-type = orbit
 Pragma: spacetrack-source = spacetrack

These can be accessed by C<< $st->content_type( $resp ) >> and
C<< $st->content_source( $resp ) >> respectively.

A list of valid names and brief descriptions can be obtained by calling
C<< $st->names ('spacetrack') >>.

If you have set the C<verbose> attribute true (e.g.  C<< $st->set
(verbose => 1) >>), the content of the error response will include the
list of valid names. Note, however, that under version 1 of the
interface this list does not determine what can be retrieved.

This method implicitly calls the C<login()> method if the session cookie
is missing or expired. If C<login()> fails, you will get the
HTTP::Response from C<login()>.

=cut

{

    my %unpack_query = (
	HASH	=> sub { return $_[0] },
	ARRAY	=> sub { return @{ $_[0] } },
    );

    # Unpack a Space Track REST query. References are unpacked per the
    # above table, if found there. Undefined values return an empty hash
    # reference. Anything else croaks with a stack trace.

    sub _unpack_query {
	my ( $arg ) = @_;
	my $code = $unpack_query{ref $arg}
	    or confess "Programming error - unexpected query $arg";
	return $code->( $arg );
    }

}

sub spacetrack {
    my ( $self, @args ) = @_;

    my ( $opt, $catalog ) = _parse_args(
	[
	    'json!'	=> 'Return data in JSON format',
	], @args );

    defined $catalog
	and my $info = $catalogs{spacetrack}[2]{$catalog}
	or return $self->_no_such_catalog( spacetrack => 2, $catalog );

    defined $info->{deprecate}
	and croak "Catalog '$catalog' is deprecated in favor of '$info->{deprecate}'";

    defined $info->{favorite}
	and return $self->favorite( $opt, $info->{favorite} );

    my %retrieve_opt = %{
	$self->_convert_retrieve_options_to_rest( $opt )
    };

    $info->{tle}
	and @retrieve_opt{ keys %{ $info->{tle} } } =
	    values %{ $info->{tle} };

    my $rslt;

    if ( $info->{satcat} ) {

	my %oid;

	foreach my $query ( _unpack_query( $info->{satcat} ) ) {

	    $rslt = $self->spacetrack_query_v2(
		basicspacedata	=> 'query',
		class		=> 'satcat',
		format		=> 'json',
		predicates	=> 'OBJECT_NUMBER',
		CURRENT		=> 'Y',
		DECAY		=> 'null-val',
		_sort_rest_arguments( $query ),
	    );

	    $rslt->is_success()
		or return $rslt;

	    foreach my $body ( @{
		$self->_get_json_object()->decode( $rslt->content() )
	    } ) {
		$oid{ $body->{OBJECT_NUMBER} + 0 } = 1;
	    }

	}

	$rslt = $self->retrieve( \%retrieve_opt,
	    sort { $a <=> $b } keys %oid );

	$rslt->is_success()
	    or return $rslt;

    } else {

	$rslt = $self->spacetrack_query_v2(
	    basicspacedata	=> 'query',
	    _sort_rest_arguments( \%retrieve_opt ),
	);

	$rslt->is_success()
	    or return $rslt;

	$self->_convert_content( $rslt );

	$self->_add_pragmata( $rslt,
	    'spacetrack-type' => 'orbit',
	    'spacetrack-source' => 'spacetrack',
	    'spacetrack-interface' => 2,
	);

    }

    return $rslt;

}

=for html <a name="spacetrack_query_v2"></a>

=item $resp = $st->spacetrack_query_v2( @path );

This method exposes the Space Track version 2 interface (a.k.a the REST
interface). It has nothing to do with the (probably badly-named)
C<spacetrack()> method.

The arguments are the arguments to the REST interface. These will be
URI-escaped, and a login will be performed if necessary. This method
returns an C<HTTP::Response> object containing the results of the
operation.

Except for the URI escaping of the arguments and the implicit login,
this method interfaces directly to Space Track. It is provided for those
who want a way to experiment with the REST interface, or who wish to do
something not covered by the higher-level methods.

For example, if you want the JSON version of the satellite box score
(rather than the tab-delimited version provided by the C<box_score()>
method) you will find the JSON in the response object of the following
call:

 my $resp = $st->spacetrack_query_v2( qw{
     basicspacedata query class boxscore
     format json predicates all
     } );
 );

If this method is called directly from outside the C<Astro::SpaceTrack>
name space, pragmata will be added to the results based on the
arguments, as follows:

For C<< basicspacedata => 'modeldef' >>

 Pragma: spacetrack-type = modeldef
 Pragma: spacetrack-source = spacetrack
 Pragma: spacetrack-interface = 2

For C<< basicspacedata => 'query' >> and C<< class => 'tle' >> or
C<'tle_latest'>,

 Pragma: spacetrack-type = orbit
 Pragma: spacetrack-source = spacetrack
 Pragma: spacetrack-interface = 2

=cut

{

    my %tle_class = map { $_ => 1 } qw{ tle tle_latest };

    sub spacetrack_query_v2 {
	my ( $self, @args ) = @_;

	delete $self->{_pragmata};

#	# Note that we need to add the comma to URI::Escape's RFC3986 list,
#	# since Space Track does not decode it.
#	my $url = join '/',
#	    $self->_make_space_track_base_url( 2 ),
#	    map {
#		URI::Escape::uri_escape( $_, '^A-Za-z0-9.,_~:-' )
#	    } @args;

	my $uri = URI->new( $self->_make_space_track_base_url( 2 ) );
	$uri->path_segments( @args );
#	$url eq $uri->as_string()
#	    or warn "'$url' ne '@{[ $uri->as_string() ]}'";
#	$url = $uri->as_string();

	if ( my $resp = $self->_dump_request(
		args	=> \@args,
		method	=> 'GET',
#		url	=> $url,
		url	=> $uri->as_string(),
		version	=> 2,
	    ) ) {
	    return $resp;
	}

	$self->_check_cookie_generic( 2 )
	    or do {
	    my $resp = $self->login();
	    $resp->is_success()
		or return $resp;
	};
##	warn "Debug - $url/$cgi";
#	my $resp = $self->_get_agent()->get( $url );
	my $resp = $self->_get_agent()->get( $uri );

	if ( $resp->is_success() ) {

	    if ( $self->{pretty} &&
		_find_rest_arg_value( \@args, format => 'json' ) eq 'json'
	    ) {
		my $json = $self->_get_json_object();
		$resp->content( $json->encode( $json->decode(
			    $resp->content() ) ) );
	    }

	    if ( __PACKAGE__ ne caller ) {

		my $kind = _find_rest_arg_value( \@args,
		    basicspacedata => '' );
		my $class = _find_rest_arg_value( \@args,
		    class => '' );

		if ( 'modeldef' eq $kind ) {

		    $self->_add_pragmata( $resp,
			'spacetrack-type' => 'modeldef',
			'spacetrack-source' => 'spacetrack',
			'spacetrack-interface' => 2,
		    );

		} elsif ( 'query' eq $kind && $tle_class{$class} ) {

		    $self->_add_pragmata( $resp,
			'spacetrack-type' => 'orbit',
			'spacetrack-source' => 'spacetrack',
			'spacetrack-interface' => 2,
		    );

		}
	    }
	}

	$self->_dump_headers( $resp );
	return $resp;
    }
}

sub _find_rest_arg_value {
    my ( $args, $name, $default ) = @_;
    for ( my $inx = $#$args - 1; $inx >= 0; $inx -= 2 ) {
	$args->[$inx] eq $name
	    and return $args->[$inx + 1];
    }
    return $default;
}

=for html <a name="update"></a>

=item $resp = $st->update( $file_name );

This method updates the named TLE file, which must be in JSON format. On
a successful update, the content of the returned HTTP::Response object
is the updated TLE data, in whatever format is desired. If any updates
were in fact found, the file is rewritten. The rewritten JSON will be
pretty if the C<pretty> attribute is true.

The file to be updated can be generated by using the C<-json> option on
any of the methods that accesses Space Track data. For example,

 # Assuming $ENV{SPACETRACK_USER} contains
 # username/password
 my $st = Astro::SpaceTrack->new(
     pretty              => 1,
 );
 my $rslt = $st->spacetrack( { json => 1 }, 'iridium' );
 $rslt->is_success()
     or die $rslt->status_line();
 open my $fh, '>', 'iridium.json'
     or die "Failed to open file: $!";
 print { $fh } $rslt->content();
 close $fh;

The following is the equivalent example using the F<SpaceTrack> script:

 SpaceTrack> set pretty 1
 SpaceTrack> spacetrack -json iridium >iridium.json

This method reads the file to be updated, determines the highest C<FILE>
value, and then requests the given OIDs, restricting the return to
C<FILE> values greater than the highest found. If anything is returned,
the file is rewritten.

The following options may be specified:

 -json
   specifies the TLE be returned in JSON format

Options may be specified either in command-line style (that is, as
C<< spacetrack( '-json', ... ) >>) or as a hash reference (that is, as
C<< spacetrack( { json => 1 }, ... ) >>).

B<Note> that there is no way to specify the C<-rcs> or C<-effective>
options. If the file being updated contains these values, they will be
lost as the individual OIDs are updated.

=cut

{

    my %encode = (
	'3le'	=> sub {
	    my ( $json, $data ) = @_;
	    return join '', map {
		"$_->{OBJECT_NAME}\n$_->{TLE_LINE1}\n$_->{TLE_LINE2}\n"
	    } @{ $data };
	},
	json	=> sub {
	    my ( $json, $data ) = @_;
	    return $json->encode( $data );
	},
	tle	=> sub {
	    my ( $json, $data ) = @_;
	    return join '', map {
		"$_->{TLE_LINE1}\n$_->{TLE_LINE2}\n"
	    } @{ $data };
	},
    );

    sub update {
	my ( $self, @args ) = @_;

	my ( $opt, $fn ) = _parse_retrieve_args( @args );

	$opt = { %{ $opt } };	# Since we modify it.

	delete $opt->{start_epoch}
	    and croak '-start_epoch not allowed';
	delete $opt->{end_epoch}
	    and croak '-end_epoch not allowed';

	my $json = $self->_get_json_object();
	my $data;
	{
	    local $/ = undef;
	    open my $fh, '<', $fn
		or croak "Unable to open $fn: $!";
	    $data = $json->decode( <$fh> );
	    close $fh;
	}

	my $file = -1;
	my @oids;
	foreach my $datum ( @{ $data } ) {
	    push @oids, $datum->{OBJECT_NUMBER};
	    my $ff = defined $datum->{_file_of_record} ?
		delete $datum->{_file_of_record} :
		$datum->{FILE};
	    $ff > $file
		and $file = $ff;
	}

	defined $opt->{since_file}
	    or $opt->{since_file} = $file;

	my $format = delete $opt->{json} ? 'json' :
	    $self->getv( 'with_name' ) ? '3le' : 'tle';
	$opt->{format} = 'json';

	my $resp = $self->retrieve( $opt, sort { $a <=> $b } @oids );

	if ( $resp->code() == HTTP_NOT_FOUND ) {

	    $resp->code( HTTP_OK );
	    $self->_add_pragmata( $resp,
		'spacetrack-type' => 'orbit',
		'spacetrack-source' => 'spacetrack',
		'spacetrack-interface' => 2,
	    );

	} else {

	    $resp->is_success()
		or return $resp;

	    my %merge = map { $_->{OBJECT_NUMBER} => $_ } @{ $data };

	    foreach my $datum ( @{ $json->decode( $resp->content() ) } ) {
		%{ $merge{$datum->{OBJECT_NUMBER}} } = %{ $datum };
	    }

	    {
		open my $fh, '>', $fn
		    or croak "Failed to open $fn: $!";
		print { $fh } $json->encode( $data );
		close $fh;
	    }

	}

	$resp->content( $encode{$format}->( $json, $data ) );

	return $resp;
    }

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
	my ( $name, $value ) = splice @args, 0, 2;
	$self->{_pragmata}{$name} = $value;
	$resp->push_header(pragma => "$name = $value");
    }
    return;
}

sub _accumulate_data_json {
    my ( $self, $context, $resp ) = @_;

    my $json = $context->{json} ||= $self->_get_json_object();

    my $data = $json->decode( $resp->content() );

    'ARRAY' eq ref $data
	or $data = [ $data ];

    @{ $data }
	or return;

    if ( $context->{data} ) {
	foreach my $datum ( @{ $data } ) {
	    defined $datum->{FILE}
		and $datum->{FILE} > $context->{file}
		and $datum->{_file_of_record} = $context->{file};
	}
	push @{ $context->{data} }, @{ $data };
    } else {
	$context->{file} = max( -1, map { $_->{FILE} } grep { defined
	    $_->{FILE} } @{ $data } );
	$context->{data} = $data;
    }

    return;
}

sub _accumulate_data_tle {
    my ( $self, $context, $resp ) = @_;
    my $content = $resp->content();
    defined $content
	and $content ne ''
	and $context->{data} .= $content;
    return;
}

# _check_cookie_generic looks for our session cookie. If it is found, it
# returns true if it thinks the cookie is valid, and false otherwise. If
# it is not found, it returns false.

sub _record_cookie_generic {
    my ( $self, $version ) = @_;
    defined $version
	or $version = $self->{space_track_version};
    my $interface_info = $self->{_space_track_interface}[$version];
    my $cookie_name = $interface_info->{cookie_name};
    my $domain = $interface_info->{domain_space_track};

    my ( $cookie, $expires );
    $self->_get_agent()->cookie_jar->scan( sub {
	    $self->{dump_headers} & DUMP_COOKIE
		and _dump_cookie( "_record_cookie_generic:\n", @_ );
	    $_[4] eq $domain
		or return;
	    $_[3] eq SESSION_PATH
		or return;
	    $_[1] eq $cookie_name
		or return;
	    ( $cookie, $expires ) = @_[2, 8];
	    return;
	} );

    # I don't get an expiration time back from the version 2 interface.
    # But the docs say the cookie is only good for about two hours, so
    # to be on the safe side I fudge in an hour.
    $version == 2
	and not defined $expires
	and $expires = time + 3600;

    if ( defined $cookie ) {
	$interface_info->{session_cookie} = $cookie;
	$self->{dump_headers} & DUMP_TRACE
	    and warn "Session cookie: $cookie\n";	## no critic (RequireCarping)
	if ( exists $interface_info->{cookie_expires} ) {
	    $interface_info->{cookie_expires} = $expires;
	    $self->{dump_headers} & DUMP_TRACE
		and warn 'Cookie expiration: ',
		    strftime( '%d-%b-%Y %H:%M:%S', localtime $expires ),
		    " ($expires)\n";	## no critic (RequireCarping)
	    return $expires > time;
	}
	return $interface_info->{session_cookie} ? 1 : 0;
    } else {
	$self->{dump_headers} & DUMP_TRACE
	    and warn "Session cookie not found\n";	## no critic (RequireCarping)
	return;
    }
}

sub _check_cookie_generic {
    my ( $self, $version ) = @_;
    defined $version
	or $version = $self->{space_track_version};
    my $interface_info = $self->{_space_track_interface}[$version];

    if ( exists $interface_info->{cookie_expires} ) {
	return defined $interface_info->{cookie_expires}
	    && $interface_info->{cookie_expires} > time;
    } else {
	return defined $interface_info->{session_cookie};
    }
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

#	$self->_deprecation_notice( $method, $argument );
#
#	This method centralizes deprecation.  Deprecation is driven of
#	the %deprecate hash. Values are:
#	    false - no warning
#	    1 - warn on first use
#	    2 - warn on each use
#	    3 - die on each use.

{

    my %deprecate = (
#	celestrak => {
#	    sts	=> 3,
#	},
#	spaceflight => {
#	    shuttle	=> 3,
#	},
    );

    sub _deprecation_notice {
	my ( $self, $method, $argument ) = @_;
	$deprecate{$method} or return;
	$deprecate{$method}{$argument} or return;
	$deprecate{$method}{$argument} >= 3
	    and croak "$method $argument is retracted";
	warnings::enabled( 'deprecated' )
	    and carp "$method $argument is deprecated";
	$deprecate{$method}{$argument} == 1
	    and $deprecate{$method}{$argument} = 0;
	return;
    }

}

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

    my $dump_headers = $self->{dump_headers};

    if ( $dump_headers & DUMP_HEADERS ) {
	local $Data::Dumper::Terse = 1;
	my $rqst = $resp->request;
	$rqst = ref $rqst ? $rqst->as_string : "undef\n";
	chomp $rqst;
	warn "\nRequest:\n$rqst\nHeaders:\n",
	    $resp->headers->as_string, "\nCookies:\n";
	$self->_get_agent()->cookie_jar->scan (sub {
	    _dump_cookie ("\n", @_);
	    });
	warn "\n";
    }

    if ( $dump_headers & DUMP_CONTENT ) {
	my $content = $resp->content();
	$content =~ s/ (?<! \n ) \z /\n/smx;
	warn "Content:\n$content";
    }

    return;
}

#	_dump_request dumps the request if desired.
#
#	If the dump_request attribute has the DUMP_REQUEST bit set, this
#	routine dumps the request. If the DUMP_NO_EXECUTE bit is set,
#	the dump is returned in the content of an HTTP::Response object,
#	with the response code set to HTTP_I_AM_A_TEAPOT. Otherwise the
#	request is dumped to STDERR.
#
#	If any of the conditions fails, this module simply returns.

sub _dump_request {
    my ( $self, %args ) = @_;
    $self->{dump_headers} & DUMP_REQUEST
	or return;

    my $json = $self->_get_json_object( pretty => 1 )
	or return;

    $self->{dump_headers} & DUMP_NO_EXECUTE
	and return HTTP::Response->new(
	HTTP_I_AM_A_TEAPOT, undef, undef, $json->encode( \%args )
    );

    warn $json->encode( \%args );

    return;
}

sub _get_json_object {
    my ( $self, %arg ) = @_;
    defined $arg{pretty}
	or $arg{pretty} = $self->{pretty};
    my $json = JSON->new()->utf8();
    $arg{pretty}
	and $json->pretty()->canonical();
    return $json;
}

# my @oids = $self->_expand_oid_list( @args );
#
# This subroutine expands the input into a list of OIDs. Commas are
# recognized as separating an argument into multiple specifications.
# Dashes are recognized as range operators, which are expanded. The
# result is returned.

sub _expand_oid_list {
    my ( $self, @args ) = @_;

    my @rslt;
    foreach my $arg ( map { split qr{ , | \s+ }smx, $_ } @args ) {
	if ( my ( $lo, $hi ) = $arg =~
	    m/ \A \s* ( \d+ ) \s* - \s* ( \d+ ) \s* \z /smx
	) {
	    ( $lo, $hi ) = $self->_check_range( $lo, $hi )
		and push @rslt, $lo .. $hi;
	} elsif ( $arg =~ m/ \A \s* ( \d+ ) \s* \z /smx ) {
	    push @rslt, $1;
	} else {
	    # TODO -- ignore? die? what?
	}
    }
    return @rslt;
}

# Take as input a reference to one of the legal options arrays, and
# extract the equivalent keys. The return is suitable for assigning to a
# hash used to test the keys; that is, it is ( key0 => 1, key1 => 1, ...
# ).

{
    my $strip = qr{ [=:|!+] .* }smx;

    sub _extract_keys {
	my ( $lgl_opts ) = @_;
	if ( 'ARRAY' eq ref $lgl_opts ) {
	    my $len = @{ $lgl_opts };
	    my @rslt;
	    for ( my $inx = 0; $inx < $len; $inx += 2 ) {
		( my $key = $lgl_opts->[$inx] ) =~ s/ $strip //smxo;
		push @rslt, $key, 1;
	    }
	    return @rslt;
	} else {
	    $lgl_opts =~ s/ $strip //smxo;
	    return $lgl_opts;
	}
    }
}

# The following are data transform routines for _search_rest().
# The arguments are the datum and the class for which it is being
# formatted.

# Parse an international launch id, and format it for a Space-Track REST
# query. The parsing is done by _parse_international_id(). The
# formatting prefixes the 'contains' wildcard '~~' unless year, sequence
# and part are all present.

sub _format_international_id_rest {
    my ( $intl_id, $class ) = @_;
    my @parts = _parse_international_id( $intl_id );
    @parts >= 3
	and return sprintf '%04d-%03d%s', @parts;
    @parts >= 2
	and return sprintf '~~%04d-%03d', @parts;
    return sprintf '~~%04d-', $parts[0];
}

# Parse a launch date, and format it for a Space-Track REST query. The
# parsing is done by _parse_launch_date(). The formatting prefixes the
# 'contains' wildcard '~~' unless year, month, and day are all present.

sub _format_launch_date_rest {
    my ( $date, $class ) = @_;
    my @parts = _parse_launch_date( $date )
	or return;
    @parts >= 3
	and return sprintf '%04d-%02d-%02d', @parts;
    @parts >= 2
	and return sprintf '~~%04d-%02d', @parts;
    return sprintf '~~%04d', $parts[0];
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

sub _get_agent {
    my ( $self ) = @_;
    $self->{agent}
	and return $self->{agent};
    my $agent = $self->{agent} = LWP::UserAgent->new(
	ssl_opts	=> {
	    verify_hostname	=> $self->getv( 'verify_hostname' ),
	},
    );

    $agent->env_proxy();

    $agent->cookie_jar()
	or $agent->cookie_jar( {} );

    return $agent;
}

# _get_space_track_domain() returns the domain name portion of the Space
# Track URL from the appropriate attribute. The argument is the
# interface version number, which defaults to the value of the
# space_track_version attribute.

sub _get_space_track_domain {
    my ( $self, $version ) = @_;
    defined $version
	or $version = $self->{space_track_version};
    return $self->{_space_track_interface}[$version]{domain_space_track};
}

# __get_loader() retrieves a loader. A code reference to it is returned.
#
# NOTE WELL: This subroutine is for the benefit of
# t/spacetrack_request.t, and is called by that code. The leading double
# underscore is to flag it to Perl::Critic as package private rather
# than module private.

sub __get_loader {
    my ( $invocant, %arg ) = @_;
    my $json = JSON->new()->utf8( 1 );
    return sub {
	return $json->decode( $_[0] );
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
    my ( $self, $opt, @args ) = @_;
    my (@catnum, @data);

    # Do not _parse_retrieve_args() here; we expect our caller to handle
    # this.

    foreach (map {split qr{ \n }smx, $_} @args) {
	s/ \s+ \z //smx;
	my ( $id ) = m/ \A ( [\s\d]{5} ) /smx or next;
	$id =~ m/ \A \s* \d+ \z /smx or next;
	my $name = substr $_, 5;
	$name =~ s/ \A \s+ //smx;
	push @catnum, $id;
	push @data, [ $id, $name ];
    }
    my $resp = $self->retrieve( $opt, sort {$a <=> $b} @catnum );
    if ( $resp->is_success ) {

	unless ( $self->{_pragmata} ) {
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


# _make_space_track_base_url() makes the a base Space Track URL. You can
# pass the interface version number (1 or 2) as an argument -- it
# defaults to the value of the space_track_version attribute.

sub _make_space_track_base_url {
    my ( $self, $version ) = @_;
    return $self->{scheme_space_track} . '://' .
	$self->_get_space_track_domain( $version );
}

# _mung_login_status() takes as its argument an HTTP::Response object.
# If the code is 500 and the message suggests a certificate problem, add
# the suggestion that the user set verify_hostname false.

sub _mung_login_status {
    my ( $resp ) = @_;
    # 500 Can't connect to www.space-track.org:443 (certificate verify failed)
    $resp->code() == HTTP_INTERNAL_SERVER_ERROR
	or return $resp;
    ( my $msg = $resp->message() ) =~
	    s{ ( [(] \Qcertificate verify failed\E ) [)]}
	    {$1; try setting the verify_hostname attribute false)}smx
	or return $resp;
    $resp->message( $msg );
    return $resp;
}

#	_mutate_attrib takes the name of an attribute and the new value
#	for the attribute, and does what its name says.

# We supress Perl::Critic because we're a one-liner. CAVEAT: we MUST
# not modify the contents of @_. Modifying @_ itself is fine.
sub _mutate_attrib {
    return ($_[0]{$_[1]} = $_[2]);
}

{
    my %need_logout = map { $_ => 1 } qw{ domain_space_track };

    sub _mutate_spacetrack_interface {
	my ( $self, $name, $value ) = @_;
	my $version = $self->{space_track_version};

	my $spacetrack_interface_info =
	    $self->{_space_track_interface}[$version];

	exists $spacetrack_interface_info->{$name}
	    or croak "Can not set $name for interface version $version";

	$need_logout{$name}
	    and $self->logout();

	return ( $spacetrack_interface_info->{$name} = $value );
    }
}

sub _access_spacetrack_interface {
    my ( $self, $name ) = @_;
    my $version = $self->{space_track_version};
    my $spacetrack_interface_info =
	$self->{_space_track_interface}[$version];
    exists $spacetrack_interface_info->{$name}
	or croak "Can not get $name for interface version $version";
    return $spacetrack_interface_info->{$name};
}

#	_mutate_authen clears the session cookie and then sets the
#	desired attribute

# This clears the session cookie and cookie expiration, then co-routines
# off to _mutate attrib.
sub _mutate_authen {
    $_[0]->logout();
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

# _mutate_space_track_version() mutates the version of the interface
# used to retrieve data from Space Track. Valid values are 1 and 2, with
# any false value causing the default to be set.

sub _mutate_space_track_version {
    my ( $self, $name, $value ) = @_;
    $value
	or $value = DEFAULT_SPACE_TRACK_VERSION;
    $value =~ m/ \A \d+ \z /smx
	and $self->{_space_track_interface}[$value]
	or croak "Invalid Space Track version $value";
##  $self->_deprecation_notice( $name => $value );
    $value == 1
	and croak 'The version 1 SpaceTrack interface stopped working July 16 2013 at 18:00 UT';
    return ( $self->{$name} = $value );
}

#	_mutate_verify_hostname mutates the verify_hostname attribute.
#	Since the value of this gets fed to LWP::UserAgent->new() to
#	instantiate the {agent} attribute, we delete that attribute
#	before changing the value, relying on $self->_get_agent() to
#	instantiate it appropriately if needed -- and on any code that
#	uses the agent to go through this private method to get it.

sub _mutate_verify_hostname {
    delete $_[0]->{agent};
    goto &_mutate_attrib;
}

#	_no_such_catalog takes as arguments a source and catalog name,
#	and returns the appropriate HTTP::Response object based on the
#	current verbosity setting.

{

    my %no_such_name = (
	celestrak => 'CelesTrak',
	spaceflight => 'Manned Spaceflight',
	spacetrack => 'Space Track',
    );

    my %no_such_trail = (
	spacetrack => [ undef, <<'EOD' ],
The Space Track data sets are actually numbered. The given number
corresponds to the data set without names; if you are requesting data
sets by number and want names, add 1 to the given number. When
requesting Space Track data sets by number the 'with_name' attribute is
ignored.
EOD
    );

    sub _no_such_catalog {
	my ( $self, $source, @args ) = @_;

	my $info = $catalogs{$source}
	    or confess "Programming error - No such source as '$source'";

	my $trailer = $no_such_trail{$source} || '';

	if ( 'ARRAY' eq ref $info ) {
	    my $inx = shift @args;
	    $info = $info->[$inx]
		or confess "Programming error - Illegal index $inx ",
		    "for '$source'";
	    'ARRAY' eq ref $trailer
		and $trailer = $trailer->[$inx];
	}

	my ( $catalog, $note ) = @args;

	my $name = $no_such_name{$source} || $source;

	my $lead = $info->{$catalog} ?
	    "Missing $name catalog '$catalog'" :
	    "No such $name catalog as '$catalog'";
	$lead .= defined $note ? " ($note)." : '.';

	return HTTP::Response->new (HTTP_NOT_FOUND, "$lead\n")
	    unless $self->{verbose};

	my $resp = $self->names ($source);
	return HTTP::Response->new (HTTP_NOT_FOUND,
	    join '', "$lead Try one of:\n", $resp->content, $trailer,
	);
    }

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

{
    my $go = Getopt::Long::Parser->new();

    sub _parse_args {
	my ( $lgl_opts, @args ) = @_;
	if ( 'HASH' eq ref $args[0] ) {
	    my $opt = { %{ shift @args } };	# Poor man's clone.
	    # Validation is new, so I insert a hack to turn it off if need
	    # be.
	    unless ( $ENV{SPACETRACK_SKIP_OPTION_HASH_VALIDATION} ) {
		my %lgl = _extract_keys( $lgl_opts );
		my @bad;
		foreach my $key ( keys %{ $opt } ) {
		    $lgl{$key}
			or push @bad, $key;
		}
		@bad
		    and _parse_args_failure(
			carp	=> 1,
			name	=> \@bad,
			legal	=> { @{ $lgl_opts } },
			suffix	=> <<'EOD',

You cam suppress this warning by setting environment variable
SPACETRACK_SKIP_OPTION_HASH_VALIDATION to a value Perl understands as
true (say, like 1), but this should be considered a stopgap while you
fix the calling code, or have it fixed, since my plan is to make this
fatal.
EOD
		    );
	    }
	    return ( $opt, @args );
	} else {
	    my $opt = {};
	    my %lgl = @{ $lgl_opts };
	    $go->getoptionsfromarray(
		\@args,
		$opt,
		keys %lgl,
	    )
		or _parse_args_failure( legal => \%lgl );
	    return ( $opt, @args );
	}
    }
}

sub _parse_args_failure {
    my %arg = @_;
    my $msg = $arg{carp} ? 'Warning - ' : 'Error - ';
    if ( defined $arg{name} ) {
	my @names = ( 'ARRAY' eq ref $arg{name} ) ?
	    @{ $arg{name} } :
	    $arg{name};
	@names
	    or return;
	my $opt = @names > 1 ? 'Options' : 'Option';
	my $txt = join ', ', map { "-$_" } sort @names;
	$msg .= "$opt $txt illegal.\n";
    }
    if ( defined $arg{legal} ) {
	$msg .= "Legal options are\n";
	foreach my $opt ( sort keys %{ $arg{legal} } ) {
	    my $desc = $arg{legal}{$opt};
	    $opt = _extract_keys( $opt );
	    $msg .= "  -$opt - $desc\n";
	}
	$msg .= <<"EOD";
with dates being either Perl times, or numeric year-month-day, with any
non-numeric character valid as punctuation.
EOD
    }
    defined $arg{suffix}
	and $msg .= $arg{suffix};
    $arg{carp}
	or croak $msg;
    carp $msg;
    return;
}

# Parse an international launch ID in the form yyyy-sssp or yysssp.
# In the yyyy-sssp form, the year can be two digits (in which case 57-99
# are 1957-1999 and 00-56 are 2000-2056) and the dash can be any
# non-alpha, non-digit, non-space character. In either case, trailing
# fields are optional. If provided, the part ('p') can be multiple
# alphabetic characters. Only fields actually specified will be
# returned.

sub _parse_international_id {
    my ( $intl_id ) = @_;
    my ( $year, $launch, $part );

    if ( $intl_id =~
	m< \A ( \d+ ) [^[:alpha:][:digit:]\s]
	    (?: ( \d{1,3} ) ( [[:alpha:]]* ) )? \z >smx
    ) {
	( $year, $launch, $part ) = ( $1, $2, $3 );
    } elsif ( $intl_id =~
	m< \A ( \d\d ) (?: ( \d{3} ) ( [[:alpha:]]* ) )?  >smx
    ) {
	( $year, $launch, $part ) = ( $1, $2, $3 );
    } else {
	return;
    }

    $year += $year < 57 ? 2000 : $year < 100 ? 1900 : 0;
    my @parts = ( $year );
    $launch
	or return @parts;
    push @parts, $launch;
    $part
	and push @parts, uc $part;
    return @parts;
}

# Parse a date in the form yyyy-mm-dd, with either two- or four-digit
# year, and month and day optional. The year is normalized to four
# digits using the NORAD pivot date of 57 -- that is, 57-99 represent
# 1957-1999, and 00-56 represent 2000-2056. The month and day are
# optional. Only fields actually specified will be returned.

sub _parse_launch_date {
    my ( $date ) = @_;
    my ( $year, $month, $day ) =
	$date =~ m/ \A (\d+) (?:\D+ (\d+) (?: \D+ (\d+) )? )? /smx
	    or return;
    $year += $year < 57 ? 2000 : $year < 100 ? 1900 : 0;
    my @parts = ( $year );
    defined $month
	or return @parts;
    push @parts, $month;
    defined $day and push @parts, $day;
    return @parts;
}

#	_parse_retrieve_args parses the retrieve() options off its
#	arguments, prefixes a reference to the resultant options hash to
#	the remaining arguments, and returns the resultant list. If the
#	first argument is a list reference, it is taken as extra
#	options, and removed from the argument list. If the next
#	argument after the list reference (if any) is a hash reference,
#	it simply returns its argument list, under the assumption that
#	it has already been called.

{

    my @legal_retrieve_options = (
	@{ CLASSIC_RETRIEVE_OPTIONS() },
	# Space Track Version 2 interface options
	'since_file=i'
	    => '(Return only results added after the given file number)',
	'json!'	=> '(Return TLEs in JSON format)',
    );

    sub _parse_retrieve_args {
	my @args = @_;
	my $extra_options = ref $args[0] eq 'ARRAY' ?
	    shift @args :
	    undef;

	( my $opt, @args ) = _parse_args(
	    ( $extra_options ?
		[ @legal_retrieve_options, @{ $extra_options } ] :
		\@legal_retrieve_options ),
	    @args );

	$opt->{sort} ||= _validate_sort( $opt->{sort} );

	return ( $opt, @args );
    }
}

# my $sort = _validate_sort( $sort );
#
# Validate and canonicalize the value of the -sort option.
{
    my %valid = map { $_ => 1 } qw{ catnum epoch };
    sub _validate_sort {
	my ( $sort ) = @_;
	defined $sort
	    or return 'catnum';
	$sort = lc $sort;
	$valid{$sort}
	    or croak "Illegal sort '$sort'";
	return $sort;
    }
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
    my ( $opt ) = @_;

    my $found;
    foreach my $key ( qw{ end_epoch start_epoch } ) {

	next unless $opt->{$key};

	if ( $opt->{$key} =~ m/ \D /smx ) {
	    my $str = $opt->{$key};
	    $str =~ m< \A
		( \d+ ) \D+ ( \d+ ) \D+ ( \d+ )
		(?: \D+ ( \d+ ) (?: \D+ ( \d+ ) (?: \D+ ( \d+ ) )? )? )?
	    \z >smx
		or croak "Error - Illegal date '$str'";
	    my @time = ( $6, $5, $4, $3, $2, $1 );
	    foreach ( @time ) {
		defined $_
		    or $_ = 0;
	    }
	    if ( $time[5] > 1900 ) {
		$time[5] -= 1900;
	    } elsif ( $time[5] < 57 ) {
		$time[5] += 100;
	    }
	    $time[4] -= 1;
	    eval {
		$opt->{$key} = timegm( @time );
		1;
	    } or croak "Error - Illegal date '$str'";
	}

	$found++;
    }

    if ( $found ) {

	if ( $found == 1 ) {
	    $opt->{start_epoch} ||= $opt->{end_epoch} - 86400;
	    $opt->{end_epoch} ||= $opt->{start_epoch} + 86400;
	}

	$opt->{start_epoch} <= $opt->{end_epoch} or croak <<'EOD';
Error - End epoch must not be before start epoch.
EOD

	foreach my $key ( qw{ start_epoch end_epoch } ) {

	    my @time = reverse( ( gmtime $opt->{$key} )[ 0 .. 5 ] );
	    $time[0] += 1900;
	    $time[1] += 1;
	    $opt->{"_$key"} = \@time;

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

{

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
	    my @extra;
	    ref $args[0] eq 'ARRAY'
		and @extra = @{shift @args};
	    @args = _parse_retrieve_args(
		[ @legal_search_args, @extra ], @args );
	}

	my $opt = $args[0];
	_parse_retrieve_dates( $opt );

	$opt->{status} ||= 'onorbit';

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

	return @args;
    }

    my %search_opts = _extract_keys( \@legal_search_args );

    # _remove_search_options
    #
    # Shallow clone the argument hasn, remove any search arguments from
    # it, and return a reference to the clone. Used for sanitizing the
    # options for a search before passing them to retrieve() to actually
    # get the TLEs.
    sub _remove_search_options {
	my ( $opt ) = @_;
	my %rslt = %{ $opt };
	delete @rslt{ keys %search_opts };
	return \%rslt;
    }
}

#	@keys = _sort_rest_arguments( \%rest_args );
#
#	This subroutine sorts the argument names in the desired order.
#	A better way to do this may be to use Unicode::Collate, which
#	has been core since 5.7.3.

{

    my %special = map { $_ => 1 } qw{ basicspacedata extendedspacedata };

    sub _sort_rest_arguments {
	my ( $rest_args ) = @_;

	'HASH' eq ref $rest_args
	    or return;

	my @rslt;

	foreach my $key ( keys %special ) {
	    @rslt
		and croak "You may not specify both '$rslt[0]' and '$key'";
	    defined $rest_args->{$key}
		and push @rslt, $key, $rest_args->{$key};
	}


	push @rslt, map { ( $_->[0], $rest_args->{$_->[0]} ) }
	    sort { $a->[1] cmp $b->[1] }
	    # Oh, for 5.14 and tr///r
	    map { [ $_, _swap_upper_and_lower( $_ ) ] }
	    grep { ! $special{$_} }
	    keys %{ $rest_args };

	return @rslt;
    }
}

sub _spacetrack_v2_response_is_empty {
    my ( $resp ) = @_;
    return $resp->content() =~ m/ \A \s* (?: [[] \s* []] )? \s* \z /smx;
}

# TODO The following UNDOCUMENTED hack will disappear when the REST
# interface's behavior when you have ranges in a list of OIDs
# stabilizes.
sub _rest_range_operator {
    return _get_env( SPACETRACK_REST_RANGE_OPERATOR => 1 ) ?
	'--' :
	undef;
}

# TODO The following UNDOCUMENTED hack will disappear when the REST
# interface's behavior with fractional days stabilizes.

sub _rest_date {
    my ( $time ) = @_;
    my $fmt = _get_env( SPACETRACK_REST_FRACTIONAL_DATE => 1 ) ?
    '%04d-%02d-%02d %02d:%02d:%02d' : '%04d-%02d-%02d';
    return sprintf $fmt, @{ $time };
}

sub _get_env {
    my ( $name, $default ) = @_;
    defined $ENV{$name}
	and return $ENV{$name};
    return $default;
}

#	$swapped = _swap_upper_and_lower( $original );
#
#	This subroutine swapps upper and lower case in its argument,
#	using the transliteration operator. It should be used only by
#	_sort_rest_arguments(). This can go away in favor of tr///r when
#	(if!) the minimum version becomes 5.14.

sub _swap_upper_and_lower {
    my ( $arg ) = @_;
    $arg =~ tr/A-Za-z/a-zA-Z/;
    return $arg;
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

# my $string = _stringify_oid_list( $opt, @oids );
#
# This subroutine sorts the @oids array, and stringifies it by
# eliminating duplicates, combining any consecutive runs of OIDs into
# ranges, and joining the result with commas. The string is returned.
#
# The $opt is a reference to a hash that specifies punctuation in the
# stringified result. The keys used are
#   separator -- The string used to separate OID specifications. The
#       default is ','.
#   range_operator -- The string used to specify a range. If omitted,
#       ranges will not be constructed.
#
# Note that ranges containing only two OIDs (e.g. 5-6) will be expanded
# as "5,6", not "5-6" (presuming $range_operator is '-').

sub _stringify_oid_list {
    my ( $opt, @args ) = @_;

    my @rslt = ( -99 );	# Prime the pump

    @args
	or return @args;

    my $separator = defined $opt->{separator} ? $opt->{separator} : ',';
    my $range_operator = $opt->{range_operator};

    if ( defined $range_operator ) {
	foreach my $arg ( sort { $a <=> $b } @args ) {
	    if ( 'ARRAY' eq ref $rslt[-1] ) {
		if ( $arg == $rslt[-1][1] + 1 ) {
		    $rslt[-1][1] = $arg;
		} else {
		    $arg > $rslt[-1][1]
			and push @rslt, $arg;
		}
	    } else {
		if ( $arg == $rslt[-1] + 1 ) {
		    $rslt[-1] = [ $rslt[-1], $arg ];
		} else {
		    $arg > $rslt[-1]
			and push @rslt, $arg;
		}
	    }
	}
	shift @rslt;	# Drop the pump priming.

	return join( $separator,
	    map { ref $_ ?
		$_->[1] > $_->[0] + 1 ?
		    "$_->[0]$range_operator$_->[1]" :
		    @{ $_ } :
		$_
	    } @rslt
	);

    } else {
	return join $separator, sort { $a <=> $b } @args;
    }

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

=item cookie_name (string)

This attribute specifies the name of the session cookie. You should not
need to change this in normal circumstances, but if Space Track changes
the name of the session cookie you can use this to get you going again.

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

The default is C<'www.space-track.org'>. This will change if necessary
to remain appropriate to the Space Track web site.

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

=item pretty (boolean)

This attribute specifies whether the content of the returned
L<HTTP::Response|HTTP::Response> is to be pretty-formatted. Currently
this only applies to Space Track data returned in C<JSON> format.
Pretty-formatting the C<JSON> is extra overhead, so unless you intend to
read the C<JSON> yourself this should probably be false.

The default is C<0> (i.e. false).

=item scheme_space_track (string)

This attribute specifies the URL scheme used to access the Space Track
web site. The user will not normally need to modify this, but if the web
site changes schemes for some reason, this attribute may provide a way
to get queries going again.

The default is C<'https'>.

=item session_cookie (text)

This attribute specifies the session cookie. You should only set it
with a previously-retrieved value.

The default is an empty string.

=item space_track_version (integer)

This attribute specifies the version of the Space Track interface to use
to retrieve data. The only valid value is C<2>.  If you set it to a
false value (i.e. C<undef>, C<0>, or C<''>) it will be set to the
default.

The default is C<2>.

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

The default is 'http://www.prismnet.com/~mmccants/tles/iridium.html'.

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

=item verify_hostname (boolean)

This attribute specifies whether C<https:> certificates are verified.
If you set this false, you can not verify that hosts using C<https:> are
who they say they are, but it also lets you work around invalid
certificates. Currently only the Space Track web site uses C<https:>.

B<Note> that the default has changed. In version 0.060_08 and earlier,
the default was true, to mimic earlier behavior. In version 0.060_09
this was changed to false, in the belief that the code should work out
of the box (which it did not when verify_hostname was true, at least as
of mid-July 2012). But on September 30 2012 Space Track announced that
they had their SSL certificates set up, so in 0.064_01 the default
became false again.

The default is true (i.e. 1).

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
Astro::SpaceTrack object is instantiated, the username and password will
be initialized from it. The value of the environment variable should be
the username and password, separated by either a slash (C<'/'>) or a
colon (C<':'>). That is, either C<'yehudi/menuhin'> or
C<'yehudi:menuhin'> are accepted.

An explicit username and/or password passed to the new () method
overrides the environment variable, as does any subsequently-set
username or password.

=head2 SPACETRACK_REST_RANGE_OPERATOR

This environment variable controls whether the Space Track version 2
interface (a.k.a. the REST interface) uses OID ranges in its queries.
A value Perl sees as false (i.e. C<0> or C<''>) causes ranges not to be
used. A value Perl sees as true (i.e. anything else) causes ranges to be
used. The default is to use ranges.

Support for this environment variable will be removed the first release
after January 1 2014, since I think range support in the REST interface
is stable.

=head2 SPACETRACK_REST_FRACTIONAL_DATE

This environment variable controls whether the Space Track version 2
interface (a.k.a. the REST interface) will query epoch ranges (i.e. the
C<-start_epoch> and C<-end_epoch> C<retrieve()> options) to
fractional-day resolution.  A value Perl sees as false (i.e. C<0> or
C<''>) causes epoch queries to be truncated to even days. A value Perl
sees as true (i.e. anything else) causes epoch queries to be to the
nearest second.  The default is to query to the nearest second.

Support for this environment variable will be removed the first release
after January 1 2014, since I think fractional-day query support in the
REST interface is stable.

=head2 SPACETRACK_SKIP_OPTION_HASH_VALIDATION

As of version 0.081_01, method options passed as a hash
reference will be validate. Before this, only command-line-style options
were validated. If the validation causes problem, set this environment
variable to a value Perl sees as true (i.e. anything but C<0> or C<''>)
to revert to the old behavior.

Support for this environment variable will be put through a deprecation
cycle and removed once the validation code is deemed solid.

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
insufficiently-up-to-date version of LWP.

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

Copyright 2005-2013 by Thomas R. Wyant, III (F<wyant at cpan dot org>).

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
