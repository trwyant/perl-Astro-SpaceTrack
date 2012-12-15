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
attrib
celestrak
celestrak's
checkbox
checksums
China's
co
com
cpan
dataset
designator
ephemeris
executables
exportable
fallback
Fengyun
filename
globalstar
glonass
hoc
HTTPS
IDs
inmarsat
intelsat
ISP
ISS
JSON
kelso
Kelso
Kelso's
login
mccants
merchantability
multimonth
navstar
NORAD
OID
OIDs
olist
onorbit
Optionmenu
orbcomm
org
pre
redirections
redistributer
redistributers
RMS
satcat
sladen
Sladen's
spaceflight
spacetrack
SpaceTrackTk
SSL
STDERR
stdout
sts
tle
tles
txt
un
unzip
unzipped
URI
usa
username
vesselsats
webcmd
Westford
www
Wyant
xxx
ZZZ
