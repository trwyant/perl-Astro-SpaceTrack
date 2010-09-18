package main;

use strict;
use warnings;

BEGIN {
    eval {
	require Test::More;
	Test::More->VERSION( 0.40 );
	Test::More->import();
	1;
    } or do {
	print "1..0 # skip Test::More 0.40 required\\n";
	exit;
    }
}


no warnings qw{ once };

$Astro::SpaceTrack::Test::SKIP_SITES =
    'Disable all sites to check skip counts';

do 't/query.t';


1;

# ex: set textwidth=72 :
