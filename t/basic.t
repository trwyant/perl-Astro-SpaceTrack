package main;

use strict;
use warnings;

no warnings qw{uninitialized};

use FileHandle;
use Test;

local $| = 1;	# Turn on autoflush to try to keep I/O in sync.

my $test_num = 1;
my $skip_spacetrack = '';

################### We start with some black magic to print on failure.

my $loaded;

# We're only using @_ for printing. CAVEAT: do not modify its contents.
# Modifying @_ itself is OK.
sub prompt {
    my @args = @_;
    print STDERR @args;
    # We're a test, and we're trying to be lightweight.
    return unless defined (my $input = <STDIN>);	## no critic ProhibitExplicitStdin
    chomp $input;
    return $input;
}

BEGIN {
plan (tests => 67);
print "# Test 1 - Loading the library.\n"
}

END {print "not ok 1\n" unless $loaded;}

use Astro::SpaceTrack;

$loaded = 1;
ok ($loaded);

######################### End of black magic.

require LWP::UserAgent;
my $agt = LWP::UserAgent->new ();

use constant NOACCESS => 'Site not accessible.';

my ($skip_celestrak, $skip_mccants, $skip_sladen, $skip_spaceflight,
    $skip_amsat);
$agt->get ('http://celestrak.com/')->is_success
    or $skip_celestrak = NOACCESS;
$agt->get ('http://www.io.com/~mmccants/tles/iridium.html')->is_success
    or $skip_mccants = NOACCESS;
$agt->get ('http://www.rod.sladen.org.uk/iridium.htm')->is_success
    or $skip_sladen = NOACCESS;
$agt->get ('http://spaceflight.nasa.gov/')->is_success
    or $skip_spaceflight = NOACCESS;
$agt->get ('http://www.amsat.org/')->is_success
    or $skip_amsat = NOACCESS;

if (!$agt->get ('http://www.space-track.org/')->is_success) {
    $skip_spacetrack = NOACCESS;
    }
  elsif ($ENV{SPACETRACK_USER}) {
    # Do nothing if we have the environment variable.
    }
  elsif ($ENV{AUTOMATED_TESTING}) {

    $skip_spacetrack = "Automated testing and no SPACETRACK_USER environment variable provided.";

    }
  elsif ($^O eq 'VMS') {

    warn <<eod;

Several tests will be skipped because you have not provided logical
name SPACETRACK_USER. This should be set to your Space Track username
and password, separated by a slash ("/") character.

eod

    $skip_spacetrack = "No SPACETRACK_USER environment variable provided.";

    }
  else {
    
    warn <<eod;

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

eod

    my ($user, $pass);
    $user = prompt ("Space-Track username: ");
    $user and $pass = prompt ("Space-Track password: ");

    if ($user && $pass) {
	$ENV{SPACETRACK_USER} = "$user/$pass";
	}
      else {
	$skip_spacetrack = "No Space Track account provided.";
	}
    }

$test_num++;
print "# Test $test_num - Instantiate the object.\n";
my $st;
ok ($st = Astro::SpaceTrack->new ());
$st or $skip_spacetrack = 'Unable to instantiate Astro::SpaceTrack';

{
    $test_num++;
    print "# Test $test_num - Fetch attribute names.\n";
    $skip_spacetrack or my @names = $st->attribute_names();
    skip($skip_spacetrack, @names > 0);
    my %present = map {$_ => 1} @names;

    $test_num++;
    print "# Test $test_num - We have a username attribute.\n";
    skip($skip_spacetrack, $present{username});

    $test_num++;
    print "# Test $test_num - Banner.\n";
    $skip_spacetrack or my $rslt = $st->banner();
    skip($skip_spacetrack, $rslt && $rslt->is_success());
}

$test_num++;
print "# Test $test_num - Log in to Space Track.\n";
my $rslt;
my $status;
skip ($skip_spacetrack,
    $skip_spacetrack || ($status = ($rslt = $st->login ())->is_success));
$status or ($skip_spacetrack ||= "Login failed");

$test_num++;
print "# Test $test_num - Check the content type; should be undef.\n";
skip ($skip_spacetrack,
    $skip_spacetrack || !defined ($st->content_type));

$test_num++;
print "# Test $test_num - Check the content source; should be undef.\n";
skip ($skip_spacetrack,
    $skip_spacetrack || !defined ($st->content_source));

$test_num++;
print "# Test $test_num - Check the content type of result; should be undef.\n";
skip ($skip_spacetrack,
    $skip_spacetrack || !defined ($st->content_type($rslt)));

$test_num++;
print "# Test $test_num - Check the content source of result; should be undef.\n";
skip ($skip_spacetrack,
    $skip_spacetrack || !defined ($st->content_source($rslt)));

$test_num++;
print "# Test $test_num - Fetch a catalog entry.\n";
skip ($skip_spacetrack,
##    $skip_spacetrack || $st->spacetrack ('special')->is_success);
    $skip_spacetrack || _expect_success(spacetrack => 'special'));

$test_num++;
print "# Test $test_num - Check the content type.\n";
skip ($skip_spacetrack,
    $skip_spacetrack || ($st->content_type || '') eq 'orbit');

$test_num++;
print "# Test $test_num - Check the content source.\n";
skip ($skip_spacetrack,
    $skip_spacetrack || ($st->content_source || '') eq 'spacetrack');

$test_num++;
print "# Test $test_num - Retrieve some orbital elements.\n";
skip ($skip_spacetrack,
##    $skip_spacetrack || $st->retrieve (25544)->is_success);
    $skip_spacetrack || _expect_success(retrieve => 25544));

$test_num++;
print "# Test $test_num - Check the content type.\n";
skip ($skip_spacetrack,
    $skip_spacetrack || ($st->content_type || '') eq 'orbit');

$test_num++;
print "# Test $test_num - Check the content source.\n";
skip ($skip_spacetrack,
    $skip_spacetrack || ($st->content_source || '') eq 'spacetrack');

$test_num++;
print "# Test $test_num - Retrieve orbital elements listed in a file.\n";
skip ($skip_spacetrack,
##    $skip_spacetrack || $st->file ('t/file.dat')->is_success);
    $skip_spacetrack || _expect_success(file => 't/file.dat'));

$test_num++;
print "# Test $test_num - Check the content type.\n";
skip ($skip_spacetrack,
    $skip_spacetrack || ($st->content_type || '') eq 'orbit');

$test_num++;
print "# Test $test_num - Check the content source.\n";
skip ($skip_spacetrack,
    $skip_spacetrack || ($st->content_source || '') eq 'spacetrack');

$test_num++;
print "# Test $test_num - Retrieve a range of orbital elements.\n";
skip ($skip_spacetrack,
##    $skip_spacetrack || $st->retrieve ('25544-25546')->is_success);
    $skip_spacetrack || _expect_success(retrieve => '25544-25546'));

$test_num++;
print "# Test $test_num - Check the content type.\n";
skip ($skip_spacetrack, $skip_spacetrack || ($st->content_type || '') eq 'orbit');

$test_num++;
print "# Test $test_num - Check the content source.\n";
skip ($skip_spacetrack, $skip_spacetrack || ($st->content_source || '') eq 'spacetrack');

$test_num++;
print "# Test $test_num - Search for something by name.\n";
skip ($skip_spacetrack,
##    $skip_spacetrack || $st->search_name ('zarya')->is_success);
    $skip_spacetrack || _expect_success(search_name => 'zarya'));

$test_num++;
print "# Test $test_num - Check the content type.\n";
skip ($skip_spacetrack, $skip_spacetrack || ($st->content_type || '') eq 'orbit');

$test_num++;
print "# Test $test_num - Check the content source.\n";
skip ($skip_spacetrack, $skip_spacetrack || ($st->content_source || '') eq 'spacetrack');

$test_num++;
print "# Test $test_num - Search by international designator.\n";
skip ($skip_spacetrack,
##    $skip_spacetrack || $st->search_id ('98067A')->is_success);
    $skip_spacetrack || _expect_success(search_id => '98067A'));

$test_num++;
print "# Test $test_num - Check the content type.\n";
skip ($skip_spacetrack, $skip_spacetrack || ($st->content_type || '') eq 'orbit');

$test_num++;
print "# Test $test_num - Check the content source.\n";
skip ($skip_spacetrack, $skip_spacetrack || ($st->content_source || '') eq 'spacetrack');

$test_num++;
print "# Test $test_num - Search by launch date.\n";
skip ($skip_spacetrack,
##    $skip_spacetrack || $st->search_date ('06-07-04')->is_success);
    $skip_spacetrack || _expect_success(search_date => '06-07-04'));

$test_num++;
print "# Test $test_num - Check the content type.\n";
skip ($skip_spacetrack, $skip_spacetrack || ($st->content_type || '') eq 'orbit');

$test_num++;
print "# Test $test_num - Check the content source.\n";
skip ($skip_spacetrack, $skip_spacetrack || ($st->content_source || '') eq 'spacetrack');

$test_num++;
print "# Test $test_num - Retrieve historical elements.\n";
skip ($skip_spacetrack,
##    $skip_spacetrack || $st->retrieve (
##	-start_epoch => '2006/04/01', 25544)->is_success);
    $skip_spacetrack || _expect_success(retrieve =>
	-start_epoch => '2006/04/01', 25544));

$test_num++;
print "# Test $test_num - Check the content type.\n";
skip ($skip_spacetrack, $skip_spacetrack || ($st->content_type || '') eq 'orbit');

$test_num++;
print "# Test $test_num - Check the content source.\n";
skip ($skip_spacetrack, $skip_spacetrack || ($st->content_source || '') eq 'spacetrack');

{
    my $skip = $skip_spacetrack || $skip_celestrak;

    $test_num++;
    print "# Test $test_num - Fetch a Celestrak data set.\n";
    skip ($skip,
##	$skip || $st->celestrak ('stations')->is_success);
	$skip || _expect_success(celestrak => 'stations'));

    $test_num++;
    print "# Test $test_num - Check content type of Celestrak data set.\n";
    skip ($skip, $skip || $st->content_type () eq 'orbit');

    $test_num++;
    print "# Test $test_num - Check the content source of Celestrak data set.\n";
    skip ($skip, $skip || ($st->content_source || '') eq 'spacetrack');

}

$test_num++;
print "# Test $test_num - Fetch a Celestrak data set, with fallback.\n";
$st->set (fallback => 1);
skip ($skip_spacetrack || $skip_celestrak,
##    $skip_spacetrack || $skip_celestrak || $st->celestrak (
##	'stations')->is_success);
    $skip_spacetrack || $skip_celestrak || _expect_success(
	celestrak => 'stations'));

$test_num++;
print "# Test $test_num - With fallback, succeed without user/password.\n";
$st->set (username => undef, password => undef);
skip ($skip_spacetrack || $skip_celestrak,
##    $skip_spacetrack || $skip_celestrak || $st->celestrak (
##	'stations')->is_success);
    $skip_spacetrack || $skip_celestrak || _expect_success(
	celestrak => 'stations'));

$test_num++;
print "# Test $test_num - Without fallback, fail without user/password.\n";
$st->set (fallback => 0);
skip ($skip_spacetrack || $skip_celestrak, $skip_spacetrack || $skip_celestrak || !$st->celestrak ('stations')->is_success);

$test_num++;
print "# Test $test_num - Direct-fetch Celestrak stations.\n";
$st->set (direct => 1);
$skip_celestrak or $rslt = $st->celestrak('stations');
skip ($skip_celestrak,
##    $skip_celestrak || $rslt->is_success);
    $skip_celestrak || _expect_success(celestrak => 'stations'));

$test_num++;
print "# Test $test_num - Check content type of Celestrak data set.\n";
skip ($skip_celestrak, $skip_celestrak || $st->content_type () eq 'orbit');

$test_num++;
print "# Test $test_num - Check the content source of Celestrak data set.\n";
skip ($skip_celestrak,
    $skip_celestrak || ($st->content_source || '') eq 'celestrak');

$test_num++;
print "# Test $test_num - Check content type of Celestrak data set in header.\n";
skip ($skip_celestrak, $skip_celestrak || $st->content_type ($rslt) eq 'orbit');

$test_num++;
print "# Test $test_num - Check the content source of Celestrak data set in header.\n";
skip ($skip_celestrak,
    $skip_celestrak || ($st->content_source($rslt) || '') eq 'celestrak');

$test_num++;
print "# Test $test_num - Direct-fetch Celestrak iridium.\n";
skip ($skip_celestrak,
##    $skip_celestrak || $st->celestrak ('iridium')->is_success);
    $skip_celestrak || _expect_success(celestrak => 'iridium'));

$test_num++;
print "# Test $test_num - Check content type of Celestrak data set.\n";
skip ($skip_celestrak, $skip_celestrak || $st->content_type () eq 'orbit');

$test_num++;
print "# Test $test_num - Check the content source of Celestrak data set.\n";
skip ($skip_celestrak,
    $skip_celestrak || ($st->content_source || '') eq 'celestrak');
$test_num++;
print "# Test $test_num - Try to retrieve data from Human Space Flight.\n";
skip ($skip_spaceflight,
##    $skip_spaceflight || $st->spaceflight()->is_success);
    $skip_spaceflight || _expect_success('spaceflight'));

$test_num++;
print "# Test $test_num - Check content type of Human Space Flight data set.\n";
skip ($skip_spaceflight, $skip_spaceflight || $st->content_type () eq 'orbit');

$test_num++;
print "# Test $test_num - Check the content source of Human Space Flight data set.\n";
skip ($skip_spaceflight, $skip_spaceflight || ($st->content_source || '') eq 'spaceflight');

$test_num++;
print "# Test $test_num - Try to retrieve data from the Radio Amateur Satellite Corporation.\n";
skip ($skip_amsat,
##    $skip_amsat || $st->amsat()->is_success);
    $skip_amsat || _expect_success('amsat'));

$test_num++;
print "# Test $test_num - Check content type of Amsat data set.\n";
skip ($skip_amsat, $skip_amsat || $st->content_type () eq 'orbit');

$test_num++;
print "# Test $test_num - Check the content source of Amsat data set.\n";
skip ($skip_amsat, $skip_amsat || ($st->content_source || '') eq 'amsat');

$test_num++;
print "# Test $test_num - Get Iridium status (McCants).\n";
skip ($skip_celestrak || $skip_mccants,
##    $skip_celestrak || $skip_mccants || $st->iridium_status()->is_success);
    $skip_celestrak || $skip_mccants || _expect_success('iridium_status'));

$test_num++;
print "# Test $test_num - Check content type of McCants Iridium status.\n";
skip ($skip_celestrak || $skip_mccants, $skip_celestrak || $skip_mccants || $st->content_type () eq 'iridium-status');

$test_num++;
print "# Test $test_num - Check the content source of McCants Iridium status.\n";
skip ($skip_celestrak || $skip_mccants, $skip_celestrak || $skip_mccants || ($st->content_source || '') eq 'mccants');

$test_num++;
print "# Test $test_num - Get Iridium status (Kelso only).\n";
$st->set (iridium_status_format => 'kelso');
skip ($skip_celestrak,
##    $skip_celestrak || $st->iridium_status()->is_success);
    $skip_celestrak || _expect_success('iridium_status'));

$test_num++;
print "# Test $test_num - Check content type of Kelso Iridium status.\n";
skip ($skip_celestrak, $skip_celestrak  || $st->content_type () eq 'iridium-status');

$test_num++;
print "# Test $test_num - Check the content source of Kelso Iridium status.\n";
skip ($skip_celestrak, $skip_celestrak  || ($st->content_source || '') eq 'kelso');

$test_num++;
print "# Test $test_num - Get Iridium status (Sladen).\n";
$st->set (iridium_status_format => 'sladen');
skip ($skip_celestrak || $skip_sladen,
##    $skip_celestrak || $skip_sladen || $st->iridium_status()->is_success);
    $skip_celestrak || $skip_sladen || _expect_success('iridium_status'));

$test_num++;
print "# Test $test_num - Check content type of Sladen Iridium status.\n";
skip ($skip_celestrak || $skip_sladen,
    $skip_celestrak || $skip_sladen || $st->content_type () eq 'iridium-status');

$test_num++;
print "# Test $test_num - Check the content source of Sladen Iridium status.\n";
skip ($skip_celestrak || $skip_sladen,
    $skip_celestrak || $skip_sladen || ($st->content_source || '') eq 'sladen');

$test_num++;
print "# Test $test_num - Get internal help.\n";
$st->set (webcmd => undef);
ok($st->help()->is_success());

$test_num++;
print "# Test $test_num - Check content type of help.\n";
ok($st->content_type eq 'help');

$test_num++;
print "# Test $test_num - Check the content source of help.\n";
ok(!defined($st->content_source));

$st->set(banner => undef);
$st->shell('', '# comment', 'set banner 1', 'exit');
$test_num++;
print "# Test $test_num - Reset an attribute using the shell.\n";
ok($st->get('banner'));

sub _expect_success {
    my ($method, @args) = @_;
    my $rslt = $st->$method(@args);
    my $rtn = $rslt->is_success
	or warn $rslt->status_line;
    return $rtn;
}

1;
