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

our $VERSION = '0.001_01';

if ($skip) {
    skip ($skip, 1);
} else {
    add_stopwords (<DATA>);

    all_pod_files_spelling_ok ();
}
__DATA__
Celestrak
com
IDs
Kelso
kelso
McCants
mccants
NORAD
Optionmenu
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
