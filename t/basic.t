#!/usr/bin/perl

use strict;
use warnings;

use FileHandle;
use Test;

$| = 1;	# Turn on autoflush to try to keep I/O in sync.

my $test_num = 1;
my $skip_spacetrack = '';

################### We start with some black magic to print on failure.

my $loaded;

sub prompt {
print STDERR @_;
return unless defined (my $input = <STDIN>);
chomp $input;
return $input;
}

BEGIN {
plan (tests => 17);
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

my $skip_celestrak = NOACCESS
    unless $agt->get ('http://celestrak.com/')->is_success;
my $skip_mccants = NOACCESS
    unless $agt->get ('http://users2.ev1.net/~mmccants/tles/iridium.html')->is_success;
my $skip_spaceflight = NOACCESS
    unless $agt->get ('http://spaceflight.nasa.gov/')->is_success;
my $skip_amsat = NOACCESS
    unless $agt->get ('http://www.amsat.org/')->is_success;

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

    my $user = prompt ("Space-Track username: ");
    my $pass = prompt ("Space-Track password: ") if $user;

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

$test_num++;
print "# Test $test_num - Log in to Space Track.\n";
skip ($skip_spacetrack, $skip_spacetrack || $st->login ()->is_success);

$test_num++;
print "# Test $test_num - Fetch a catalog entry.\n";
skip ($skip_spacetrack, $skip_spacetrack || $st->spacetrack ('special')->is_success);

$test_num++;
print "# Test $test_num - Retrieve some orbital elements.\n";
skip ($skip_spacetrack, $skip_spacetrack || $st->retrieve (25544)->is_success);

$test_num++;
print "# Test $test_num - Retrieve a range of orbital elements.\n";
skip ($skip_spacetrack, $skip_spacetrack || $st->retrieve ('25544-25546')->is_success);

$test_num++;
print "# Test $test_num - Check the content type.\n";
skip ($skip_spacetrack, $skip_spacetrack || $st->content_type eq 'orbit');

$test_num++;
print "# Test $test_num - Search for something by name.\n";
skip ($skip_spacetrack, $skip_spacetrack || $st->search_name ('zarya')->is_success);

$test_num++;
print "# Test $test_num - Search by international designator.\n";
skip ($skip_spacetrack, $skip_spacetrack || $st->search_id ('98067A')->is_success);

$test_num++;
print "# Test $test_num - Search by launch date.\n";
skip ($skip_spacetrack, $skip_spacetrack || $st->search_date ('06-07-04')->is_success);

$test_num++;
print "# Test $test_num - Fetch a Celestrak data set.\n";
skip ($skip_spacetrack || $skip_celestrak, $skip_spacetrack || $skip_celestrak || $st->celestrak ('stations')->is_success);

$test_num++;
print "# Test $test_num - Direct-fetch a Celestrak data set.\n";
$st->set (username => undef, password => undef, direct => 1);
skip ($skip_celestrak, $skip_celestrak || $st->celestrak ('stations')->is_success);

$test_num++;
print "# Test $test_num - Check content type of Celestrak data set.\n";
skip ($skip_celestrak, $skip_celestrak || $st->content_type () eq 'orbit');

$test_num++;
print "# Test $test_num - Try to retrieve data from Human Space Flight.\n";
skip ($skip_spaceflight, $skip_spaceflight || $st->spaceflight()->is_success);

$test_num++;
print "# Test $test_num - Get Iridium status.\n";
skip ($skip_celestrak || $skip_mccants,
    $skip_celestrak || $skip_mccants || $st->iridium_status()->is_success);

$test_num++;
print "# Test $test_num - Retrieve historical elements.\n";
skip ($skip_spacetrack, $skip_spacetrack || $st->retrieve (-start_epoch => '2006/04/01', 25544)->is_success);

$test_num++;
print "# Test $test_num - Try to retrieve data from the Radio Amateur Satellite Corporation.\n";
skip ($skip_amsat, $skip_amsat || $st->amsat()->is_success);
