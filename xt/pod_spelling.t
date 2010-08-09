package main;

use strict;
use warnings;

BEGIN {
    eval {
	require Test::Spelling;
	Test::Spelling->import();
	1;
    } or do {
	print "1..0 # skip Test::Spelling not available.\n";
	exit;
    };
}

our $VERSION = '0.010';

add_stopwords (<DATA>);

all_pod_files_spelling_ok ();

1;
__DATA__
amsat
antisatellite
Celestrak
China's
com
exportable
fallback
Fengyun
IDs
ISP
ISS
Kelso
Kelso's
kelso
McCants
mccants
NORAD
OID
OIDs
Optionmenu
SATCAT
Sladen
sladen
Sladen's
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
sts
tle
txt
unzip
unzipped
usa
username
webcmd
www
xxx
