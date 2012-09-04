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
Celestrak's
China's
com
dataset
executables
exportable
fallback
filename
Fengyun
globalstar
inmarsat
glonass
HTTPS
IDs
intelsat
ISP
ISS
JSON
Kelso
Kelso's
kelso
login
McCants
mccants
merchantability
multimonth
navstar
NORAD
OID
OIDs
Optionmenu
orbcomm
redirections
SATCAT
Sladen
sladen
Sladen's
STDERR
STDOUT
SpaceTrack
SpaceTrackTk
vesselsats
Wyant
ZZZ
attrib
celestrak
checkbox
co
cpan
olist
onorbit
org
redistributer
redistributers
satcat
spaceflight
spacetrack
stdout
sts
tle
tles
txt
unzip
unzipped
URI
usa
username
webcmd
Westford
www
xxx
