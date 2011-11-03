package main;

use strict;
use warnings;

use Test::More 0.88;

no warnings qw{ once };

$Astro::SpaceTrack::Test::SKIP_SITES =
    'Disable all sites to check skip counts';

do 't/query.t';


1;

# ex: set textwidth=72 :
