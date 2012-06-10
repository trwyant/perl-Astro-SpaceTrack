package main;

use strict;
use warnings;

use Test::More 0.88;

use Astro::SpaceTrack;

sub is_not_success (@);
sub is_success (@);
sub not_defined ($$);
sub site_check ($);
sub skip_site (@);

use constant VERIFY_HOSTNAME => 0;

plan tests => 104;

my $st;
{
    site_check 'www.space-track.org';	# To make sure we have account
    local $ENV{SPACETRACK_USER} = spacetrack_account();
    $st = Astro::SpaceTrack->new( verify_hostname => VERIFY_HOSTNAME );
}

SKIP: {

    skip_site 'www.space-track.org', 69;

    ok $st->banner()->is_success(), 'Banner.';

    my $rslt = $st->login();
    ok $rslt->is_success(), 'Log in to Space-Track'
	or set_skip( 'www.space-track.org',
	'Space-Track login failed: ' . $rslt->status_line() );

    SKIP: {

	skip_site 'www.space-track.org', 67;

	not_defined $st->content_type(), 'Content type should be undef'
	    or diag( 'content_type is ', $st->content_type() );

	not_defined $st->content_source(), 'Content source should be undef'
	    or diag( 'content_source is ', $st->content_source() );

	not_defined $st->content_type( $rslt ), 'Result type should be undef'
	    or diag( 'content_type is ', $st->content_type() );

	not_defined $st->content_source( $rslt ),
		'Result source should be undef'
	    or diag( 'content_source is ', $st->content_source() );

	is_success $st, spacetrack => 'special', 'Fetch a catalog entry';

	is $st->content_type(), 'orbit', "Content type is 'orbit'";

	is $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'";

	is_success $st, retrieve => 25544, 'Retrieve ISS orbital elements';

	is $st->content_type(), 'orbit', "Content type is 'orbit'";

	is $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'";

	is_success $st, file => 't/file.dat',
	    'Retrieve orbital elements specified by file';

	is $st->content_type(), 'orbit', "Content type is 'orbit'";

	is $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'";

	is_success $st, retrieve => '25544-25546',
	    'Retrieve a range of orbital elements';

	is $st->content_type(), 'orbit', "Content type is 'orbit'";

	is $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'";

	is_success $st, search_name => 'zarya', "Search for name 'zarya'";

	is $st->content_type(), 'orbit', "Content type is 'orbit'";

	is $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'";

	is_success $st, search_name => -rcs => 'zarya',
	    "Search for name 'zarya', returning radar cross section";

	is $st->content_type(), 'orbit', "Content type is 'orbit'";

	is $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'";

	is_success $st, search_name => -notle => 'zarya',
	    "Search for name 'zarya', but only retrieve search results";

	is $st->content_type(), 'search', "Content type is 'search'";

	is $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'";

	is_success $st, search_id => '98067A', "Search for ID '98067A'";

	is $st->content_type(), 'orbit', "Content type is 'orbit'";

	is $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'";

	is_success $st, search_id => -rcs => '98067A',
	    "Search for ID '98067A', returning radar cross-section";

	is $st->content_type(), 'orbit', "Content type is 'orbit'";

	is $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'";

	is_success $st, search_id => -notle => '98067A',
	    "Search for ID '98067A', but only retrieve search results";

	is $st->content_type(), 'search', "Content type is 'search'";

	is $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'";

	is_success $st, search_oid => 25544, "Search for OID 25544";

	is $st->content_type(), 'orbit', "Content type is 'orbit'";

	is $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'";

	is_success $st, search_oid => -rcs => 25544,
	    "Search for OID 25544, returning radar cross-section";

	is $st->content_type(), 'orbit', "Content type is 'orbit'";

	is $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'";

	is_success $st, search_oid => -notle => 25544,
	    "Search for OID 25544, but only retrieve search results";

	is $st->content_type(), 'search', "Content type is 'search'";

	is $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'";

	is_success $st, search_decay => '2010-1-10',
	    'Search for bodies decayed January 10 2010';

	is $st->content_type(), 'orbit', "Content type is 'orbit'";

	is $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'";

	is_success $st, search_decay => -rcs => '2010-1-10',
	    'Search for bodies decayed Jan 10 2010, retrieving radar cross-section';

	is $st->content_type(), 'orbit', "Content type is 'orbit'";

	is $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'";

	is_success $st, search_decay => -notle => '2010-1-10',
	    'Search for bodies decayed Jan 10 2010, but only retrieve search results';

	is $st->content_type(), 'search', "Content type is 'search'";

	is $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'";

	is_success $st, search_date => '2006-07-04',
	    "Search for date '2006-07-04'";

	is $st->content_type(), 'orbit', "Content type is 'orbit'";

	is $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'";

	is_success $st, search_date => -rcs => '2006-07-04',
	    "Search for date '2006-07-04', retrieving radar cross-section";

	is $st->content_type(), 'orbit', "Content type is 'orbit'";

	is $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'";

	is_success $st, search_date => -notle => '2006-07-04',
	    "Search for date '2006-07-04', but only retrieve search results";

	is $st->content_type(), 'search', "Content type is 'search'";

	is $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'";

	is_success $st, retrieve => -start_epoch => '2006/04/01', 25544,
	    'Retrieve historical ISS orbital elements';

	is $st->content_type(), 'orbit', "Content type is 'orbit'";

	is $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'";

	is_success $st, 'box_score', 'Retrieve satellite box score';

	is $st->content_type(), 'box_score',
	    "Content type is 'box_score'";

	is $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'";

    }

}

SKIP: {

    skip_site 'www.space-track.org', 'celestrak.com', 6;

    is_success $st, celestrak => 'stations', 'Fetch Celestrak stations';

    is $st->content_type(), 'orbit', "Content type is 'orbit'";

    is $st->content_source(), 'spacetrack', "Content source is 'spacetrack'";

    $st->set( fallback => 1 );

    is_success $st, celestrak => 'stations',
	'Fetch Celestrak stations with fallback';

    $st->set( username => undef, password => undef );

    is_success $st, celestrak => 'stations',
	'Fetch Celestrak stations with fallback, without account';

    $st->set( fallback => 0 );

    is_not_success $st, celestrak => 'stations',
	'Fetch Celestrak stations without fallback or account fails';

}

$st->set( direct => 1 );

SKIP: {

    skip_site 'celestrak.com', 9;

    my $rslt = eval { $st->celestrak( 'stations' ) }
	or diag "\$st->celestrak( 'stations' ) failed: $@";

    ok $rslt->is_success(), 'Direct fetch Celestrak stations'
	or diag $rslt->status_line();

    is $st->content_type(), 'orbit', "Content type is 'orbit'";

    is $st->content_source(), 'celestrak', "Content source is 'celestrak'";

    is $st->content_type( $rslt ), 'orbit', "Result type is 'orbit'";

    is $st->content_source( $rslt ), 'celestrak',
	"Result source is 'celestrak'";

    is_success $st, celestrak => 'iridium',
	'Direct-fetch Celestrak iridium';

    is $st->content_type(), 'orbit', "Content type is 'orbit'";

    is $st->content_source(), 'celestrak', "Content source is 'celestrak'";

    is_not_success $st, celestrak => 'fubar',
	'Direct-fetch non-existent Celestrak catalog';

}

SKIP: {

    skip_site 'spaceflight.nasa.gov', 3;

    is_success $st, spaceflight => '-all', 'iss', 'Human Space Flight data'
	or do {
#	my $rslt = most_recent_http_response();
#	if ( $rslt->code() == 412 ) {
#	    diag( $rslt->content() );
#	}
	skip 'Query failed', 2;
    };

    is $st->content_type(), 'orbit', "Content type is 'orbit'";

    is $st->content_source(), 'spaceflight',
	"Content source is 'spaceflight'";

}

SKIP: {

    skip_site 'www.amsat.org', 3;

    is_success $st, 'amsat', 'Radio Amateur Satellite Corporation';

    is $st->content_type(), 'orbit', "Content type is 'orbit'";

    is $st->content_source(), 'amsat', "Content source is 'amsat'";

}

SKIP: {

    skip_site 'celestrak.com', 'mike.mccants', 3;

    is_success $st, 'iridium_status', 'Get Iridium status (McCants)';

    is $st->content_type(), 'iridium-status',
	"Content type is 'iridium-status'";

    is $st->content_source(), 'mccants', "Content source is 'mccants'";

}

$st->set( iridium_status_format => 'kelso' );

SKIP: {

    skip_site 'celestrak.com', 3;

    is_success $st, 'iridium_status', 'Get Iridium status (Kelso)';

    is $st->content_type(), 'iridium-status',
	"Content type is 'iridium-status'";

    is $st->content_source(), 'kelso', "Content source is 'kelso'";

}

$st->set( iridium_status_format => 'sladen' );

SKIP: {

    skip_site 'celestrak.com', 'rod.sladen', 3;

    is_success $st, 'iridium_status', 'Get Iridium status (Sladen)';

    is $st->content_type(), 'iridium-status',
	"Content type is 'iridium-status'";

    is $st->content_source(), 'sladen', "Content source is 'sladen'";

}

$st->set( webcmd => undef );

is_success $st, 'help', 'Get internal help';

is $st->content_type(), 'help', "Content type is 'help'";

not_defined $st->content_source(), "Content source is undef";

is_success $st, 'names', 'celestrak', 'Retrieve Celestrak catalog names';

$st->set( banner => undef, filter => 1 );
$st->shell( '', '# comment', 'set banner 1', 'exit' );
ok $st->get('banner'), 'Reset an attribute using the shell';

my $rslt;

sub most_recent_http_response {
    return $rslt;
}

sub is_not_success (@) {	## no critic (RequireArgUnpacking)
    my ( $obj, $method, @args ) = @_;
    my $name = pop @args;
    $rslt = eval { $obj->$method( @args ) };
    $rslt or do {
	@_ = ( "$name threw exception: $@" );
	goto \&fail;
    };
    @_ = ( ! $rslt->is_success(), $name );
    goto &ok;
}

sub is_success (@) {	## no critic (RequireArgUnpacking)
    my ( $obj, $method, @args ) = @_;
    my $name = pop @args;
    $rslt = eval { $obj->$method( @args ) }
	or do {
	@_ = ( "$name threw exception: $@" );
	chomp $_[0];
	goto \&fail;
    };
    $rslt->is_success() or $name .= ": " . $rslt->status_line();
    @_ = ( $rslt->is_success(), $name );
    goto &ok;
}

sub not_defined ($$) {
    $_[0] = ! defined $_[0];
    goto &ok;
}

# Prompt the user. DO NOT call this if $ENV{AUTOMATED_TESTING} is set.

sub prompt {
    my @args = @_;
    print STDERR @args;
    # We're a test, and we're trying to be lightweight.
    defined (my $input = <STDIN>)	## no critic (ProhibitExplicitStdin)
	or return;
    chomp $input;
    return $input;
}

# Determine whether a given web site is to be skipped.

{
    my %info;
    my %skip_site;
    BEGIN {
	%info = (
	    'celestrak.com'	=> {
		url	=> 'http://celestrak.com/',
	    },
	    'mike.mccants'	=> {
		url	=> 'http://www.io.com/~mmccants/tles/iridium.html',
	    },
	    'rod.sladen'	=> {
		url	=> 'http://www.rod.sladen.org.uk/iridium.htm',
	    },
	    'spaceflight.nasa.gov'	=> {
		url	=> 'http://spaceflight.nasa.gov',
	    },
	    'www.amsat.org'	=> {
		url	=> 'http://www.amsat.org/',
	    },
	    'www.space-track.org'	=> {
		url	=> 'https://www.space-track.org/',
		check	=> \&spacetrack_skip,
	    }
	);
    }
    my $ua;

    sub set_skip {
	my ( $site, $skip ) = @_;
	exists $info{$site}{url}
	    or die "Programming error. '$site' unknown";
	$skip_site{$site} = $skip;
	return;
    }

    sub site_check ($) {
	my ( $site ) = @_;
	exists $skip_site{$site} and return $skip_site{$site};
	my $url = $info{$site}{url} or do {
	    my $skip = "Programming error - No known url for '$site'";
	    diag( $skip );
	    return ( $skip_site{$site} = $skip );
	};

	{
	    no warnings qw{ once };
	    $Astro::SpaceTrack::Test::SKIP_SITES
		and return ( $skip_site{$site} =
		"$site skipped: $Astro::SpaceTrack::Test::SKIP_SITES"
	    );
	}

	$ua ||= LWP::UserAgent->new(
	    ssl_opts	=> { verify_hostname => VERIFY_HOSTNAME },
	);
	my $rslt = $ua->get( $url );
	$rslt->is_success()
	    or return ( $skip_site{$site} =
		"$site not available: " . $rslt->status_line() );
	if ( $info{$site}{check} and my $check = $info{$site}{check}->() ) {
	    return ( $skip_site{$site} = $check );
	}
	return ( $skip_site{$site} = undef );
    }
}

# Skip the given number of tests if the site is not usable.

sub skip_site (@) {		## no critic (RequireArgUnpacking)
    my @sites = @_;
    my $tests = pop @sites;
    foreach my $where ( @sites ) {
	my $skip = site_check $where or next;
	@_ = ( $skip, $tests );
	goto &skip;
    }
    return;
}

{
    my $spacetrack_auth;

    sub spacetrack_account {
	return $spacetrack_auth;
    }

    sub spacetrack_skip {
	$spacetrack_auth = $ENV{SPACETRACK_USER} and return;
	$ENV{AUTOMATED_TESTING}
	    and return 'Automated testing and SPACETRACK_USER not set.';
	$^O eq 'VMS' and do {
	    warn <<'EOD';

Several tests will be skipped because you have not provided logical
name SPACETRACK_USER. This should be set to your Space Track username
and password, separated by a slash ("/") character.

EOD
	    return;
	};
	warn <<'EOD';

Several tests require the username and password of a registered Space
Track user. Because you have not provided environment variable
SPACETRACK_USER, you will be prompted for this information. If you
leave either username or password blank, the tests will be skipped.

If you set environment variable SPACETRACK_USER to your Space Track
username and password, separated by a slash ("/") character, that
username and password will be used, and you will not be prompted.

You may also supress prompts by setting the AUTOMATED_TESTING
environment variable to any value Perl takes as true. This is
equivalent to not specifying a username, and tests that require a
username will be skipped.

EOD

	my $user = prompt( 'Space-Track username: ' )
	    and my $pass = prompt( 'Space-Track password: ' )
	    or return 'No Space-Track account provided.';
	$spacetrack_auth = "$user/$pass";
	return;
    }
}

1;

__END__

#! ex: set textwidth=72 :
