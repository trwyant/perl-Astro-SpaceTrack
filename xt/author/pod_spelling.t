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

add_stopwords (<DATA>);

all_pod_files_spelling_ok ();

1;
__DATA__
amsat
antisatellite
API
Celestrak
China's
com
dataset
executables
exportable
fallback
filename
Fengyun
IDs
ISP
ISS
Kelso
Kelso's
kelso
login
McCants
mccants
merchantability
multimonth
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
ZZZ
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
tles
txt
unzip
unzipped
usa
username
webcmd
www
xxx
