package main;

use strict;
use warnings;

use Test::More 0.40;

use Astro::SpaceTrack;

BEGIN {

    eval {
	require LWP::UserAgent;
	1;
    } or do {
	print "1..0 # skip Prerequisite LWP::UserAgent not found.\n";
	exit;
    };
}

plan( tests => 66 );

my $st;
{
    site_check( 'www.space-track.org' );	# To make sure we have account
    local $ENV{SPACETRACK_USER} = spacetrack_account();
    $st = eval { Astro::SpaceTrack->new() };
    isa_ok( $st, 'Astro::SpaceTrack' )
	or BAIL_OUT(
	"Can't instantiate Astro::SpaceTrack. Unable to test further." );
}

SKIP: {

    skip_site( 'www.space-track.org', 32 );

    my @names = $st->attribute_names();
    my %present = map {$_ => 1} @names;

    ok( @names > 0, 'Fetch attribute names.' );

    ok( $present{username}, 'We have a username attribute.' );

    ok( $st->banner()->is_success(), 'Banner.' );

    my $rslt = $st->login();
    ok( $rslt->is_success(), 'Log in to Space-Track' )
	or set_skip( 'www.space-track.org', 'Space-Track login failed' );

    SKIP: {

	skip_site( 'www.space-track.org', 28 );

	ok( ! defined $st->content_type(), 'Content type should be undef' )
	    or diag( 'content_type is ', $st->content_type() );

	ok( ! defined $st->content_source(), 'Content source should be undef' )
	    or diag( 'content_source is ', $st->content_source() );

	ok( ! defined $st->content_type( $rslt ),
	    'Result type should be undef' )
	    or diag( 'content_type is ', $st->content_type() );

	ok( ! defined $st->content_source( $rslt ),
	    'Result source should be undef' )
	    or diag( 'content_source is ', $st->content_source() );

	is_success( $st, spacetrack => 'special', 'Fetch a catalog entry' );

	is( $st->content_type(), 'orbit', "Content type is 'orbit'" );

	is( $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'" );

	is_success( $st, retrieve => 25544, 'Retrieve ISS orbital elements' );

	is( $st->content_type(), 'orbit', "Content type is 'orbit'" );

	is( $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'" );

	is_success( $st, file => 't/file.dat',
	    'Retrieve orbital elements specified by file' );

	is( $st->content_type(), 'orbit', "Content type is 'orbit'" );

	is( $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'" );

	is_success( $st, retrieve => '25544-25546',
	    'Retrieve a range of orbital elements' );

	is( $st->content_type(), 'orbit', "Content type is 'orbit'" );

	is( $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'" );

	is_success( $st, search_name => 'zarya', "Search for name 'zarya'" );

	is( $st->content_type(), 'orbit', "Content type is 'orbit'" );

	is( $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'" );

	is_success( $st, search_id => '98067A', "Search for ID '98067A'" );

	is( $st->content_type(), 'orbit', "Content type is 'orbit'" );

	is( $st->content_source(), 'spacetrack',
	    "Content source is 'spacetrack'" );

	TODO: {

	    local $TODO = 'Data before 2010/01/01 lost. Being restored.';

	    # The actual date search succeeds, returning 29251. But this
	    # is STS 121, landed 2006-07-17. Until the database is
	    # rebuilt the retrieval of the latest TLE fails, so the
	    # whole thing returns a 404.
	    is_success( $st, search_date => '2006-07-04',
		"Search for date '2006-07-04'" );

	    is( $st->content_type(), 'orbit', "Content type is 'orbit'" );

	    is( $st->content_source(), 'spacetrack',
		"Content source is 'spacetrack'" );

	    local $TODO = 'Data before 2010/01/01 lost. Being restored.';

	    is_success( $st, retrieve => -start_epoch => '2006/04/01', 25544,
		'Retrieve historical ISS orbital elements' );

	    is( $st->content_type(), 'orbit', "Content type is 'orbit'" );

	    is( $st->content_source(), 'spacetrack',
		"Content source is 'spacetrack'" );

	}

    }

}

SKIP: {

    skip_site( 'www.space-track.org', 'celestrak.com', 6 );

    is_success( $st, celestrak => 'stations', 'Fetch Celestrak stations' );

    is( $st->content_type(), 'orbit', "Content type is 'orbit'" );

    is( $st->content_source(), 'spacetrack', "Content source is 'spacetrack'" );

    $st->set( fallback => 1 );

    is_success( $st, celestrak => 'stations',
	'Fetch Celestrak stations with fallback' );

    $st->set( username => undef, password => undef );

    is_success( $st, celestrak => 'stations',
	'Fetch Celestrak stations with fallback, without account' );

    $st->set( fallback => 0 );

    is_not_success( $st, celestrak => 'stations',
	'Fetch Celestrak stations without fallback or account fails' );

}

$st->set( direct => 1 );

SKIP: {

    skip_site( 'celestrak.com', 8 );

    my $rslt = eval { $st->celestrak( 'stations' ) }
	or diag( "\$st->celestrak( 'stations' ) failed: $@" );
    ok( $rslt->is_success(), 'Direct fetch Celestrak stations' )
	or diag( $rslt->status_line() );

    is( $st->content_type(), 'orbit', "Content type is 'orbit'" );

    is( $st->content_source(), 'celestrak', "Content source is 'celestrak'" );

    is( $st->content_type( $rslt ), 'orbit', "Result type is 'orbit'" );

    is( $st->content_source( $rslt ), 'celestrak',
	"Result source is 'celestrak'" );

    is_success( $st, celestrak => 'iridium',
	'Direct-fetch Celestrak iridium' );

    is( $st->content_type(), 'orbit', "Content type is 'orbit'" );

    is( $st->content_source(), 'celestrak', "Content source is 'celestrak'" );

}

SKIP: {

    skip_site( 'spaceflight.nasa.gov', 3 );

    is_success( $st, spaceflight => '-all', 'Human Space Flight data' );

    is( $st->content_type(), 'orbit', "Content type is 'orbit'" );

    is( $st->content_source(), 'spaceflight',
	"Content source is 'spaceflight'" );

}

SKIP: {

    skip_site( 'www.amsat.org', 3 );

    is_success( $st, 'amsat', 'Radio Amateur Satellite Corporation' );

    is( $st->content_type(), 'orbit', "Content type is 'orbit'" );

    is( $st->content_source(), 'amsat', "Content source is 'amsat'" );

}

SKIP: {

    skip_site( 'celestrak.com', 'mike.mccants', 3 );

    is_success( $st, 'iridium_status', 'Get Iridium status (McCants)' );

    is( $st->content_type(), 'iridium-status',
	"Content type is 'iridium-status'" );

    is( $st->content_source(), 'mccants', "Content source is 'mccants'" );

}

$st->set( iridium_status_format => 'kelso' );

SKIP: {

    skip_site( 'celestrak.com', 3 );

    is_success( $st, 'iridium_status', 'Get Iridium status (Kelso)' );

    is( $st->content_type(), 'iridium-status',
	"Content type is 'iridium-status'" );

    is( $st->content_source(), 'kelso', "Content source is 'kelso'" );

}

$st->set( iridium_status_format => 'sladen' );

SKIP: {

    skip_site( 'celestrak.com', 'rod.sladen', 3 );

    is_success( $st, 'iridium_status', 'Get Iridium status (Sladen)' );

    is( $st->content_type(), 'iridium-status',
	"Content type is 'iridium-status'" );

    is( $st->content_source(), 'sladen', "Content source is 'sladen'" );

}

$st->set( webcmd => undef );

is_success( $st, 'help', 'Get internal help' );

is( $st->content_type(), 'help', "Content type is 'help'" );

ok( ! defined $st->content_source(), "Content source is undef" );

$st->set( banner => undef, filter => 1 );
$st->shell( '', '# comment', 'set banner 1', 'exit' );
ok( $st->get('banner'), 'Reset an attribute using the shell' );

sub is_not_success {	## no critic (RequireArgUnpacking)
    my ( $obj, $method, @args ) = @_;
    my $name = pop @args;
    my $rslt = eval { $obj->$method( @args ) };
    $rslt or do {
	@_ = ( "$name threw exception: $@" );
	goto \&fail;
    };
    @_ = ( ! $rslt->is_success(), $name );
    goto &ok;
}

sub is_success {	## no critic (RequireArgUnpacking)
    my ( $obj, $method, @args ) = @_;
    my $name = pop @args;
    my $rslt = eval { $obj->$method( @args ) };
    $rslt or do {
	@_ = ( "$name threw exception: $@" );
	goto \&fail;
    };
    $rslt->is_success() or $name .= ": " . $rslt->status_line();
    @_ = ( $rslt->is_success(), $name );
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
		url	=> 'http://www.space-track.org/',
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

    sub site_check {
	my ( $site, $tests ) = @_;
	exists $skip_site{$site} and return $skip_site{$site};
	my $url = $info{$site}{url}
	    or die "Programming error - No known url for '$site'";
	$ua ||= LWP::UserAgent->new();
	my $rslt = $ua->get( $url );
	$rslt->is_success()
	    or return ( $skip_site{$site} =
		"$site not available: ", $rslt->status_line() );
	if ( $info{$site}{check} and my $check = $info{$site}{check}->() ) {
	    return ( $skip_site{$site} = $check );
	}
	return ( $skip_site{$site} = undef );
    }
}

# Skip the given number of tests if the site is not usable.

sub skip_site {		## no critic (RequireArgUnpacking)
    my @sites = @_;
    my $tests = pop @sites;
    foreach my $where ( @sites ) {
	my $skip = site_check( $where ) or next;
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