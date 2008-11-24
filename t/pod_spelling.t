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

our $VERSION = '0.009';

if ($skip) {
    skip ($skip, 1);
} else {
    add_stopwords (<DATA>);

    all_pod_files_spelling_ok ();
}
__DATA__
amsat
Celestrak
China's
com
exportable
fallback
Fengyun
IDs
ISP
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
TLE
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
txt
unzip
username
webcmd
www
