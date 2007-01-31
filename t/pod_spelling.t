#!/usr/local/bin/perl

use strict;
use warnings;

my $skip;
BEGIN {
    eval "use Test::Spelling";
    $@ and do {
	eval "use Test";
	plan (tests => 1);
	$skip = 'Test::Spelling not available';;
    };
}

our $VERSION = '0.003_02';

if ($skip) {
    skip ($skip, 1);
} else {
    add_stopwords (<DATA>);

    all_pod_files_spelling_ok ();
}
__DATA__
Celestrak
com
exportable
IDs
ISP
Kelso
kelso
McCants
mccants
NORAD
OIDs
Optionmenu
SATCAT
STDERR
STDOUT
SpaceTrack
SpaceTrackTk
Wyant
ZZ
attrib
celestrak
checkbox
co
cpan
onorbit
org
redistributer
redistributers
spaceflight
spacetrack
stdout
txt
unzip
username
webcmd
www
