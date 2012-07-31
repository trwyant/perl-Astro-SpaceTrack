package main;

use 5.006002;

use strict;
use warnings;

use Astro::SpaceTrack;
use JSON;
use Test::More 0.88;	# Because of done_testing();

$ENV{SPACETRACK_USER}
    or plan skip_all => 'Environment variable SPACETRACK_USER not defined';

my $st = Astro::SpaceTrack->new();
my $json = JSON->new()->pretty()->canonical()->utf8();

my $rslt = $st->spacetrack_query_v2( qw{
    basicspacedata modeldef class satcat
    } );

ok $rslt->is_success(), 'Fetch modeldef for class satcat';

if ( $rslt->is_success() ) {

    my $expect = $json->decode( <<'EOD' );
{
   "controller" : "basicspacedata",
   "data" : [
      {
         "Default" : "",
         "Extra" : "",
         "Field" : "INTLDES",
         "Key" : "",
         "Null" : "NO",
         "Type" : "char(12)"
      },
      {
         "Default" : "0",
         "Extra" : "",
         "Field" : "NORAD_CAT_ID",
         "Key" : "",
         "Null" : "NO",
         "Type" : "mediumint(8) unsigned"
      },
      {
         "Default" : "",
         "Extra" : "",
         "Field" : "OBJECT_TYPE",
         "Key" : "",
         "Null" : "NO",
         "Type" : "varchar(11)"
      },
      {
         "Default" : "",
         "Extra" : "",
         "Field" : "SATNAME",
         "Key" : "",
         "Null" : "NO",
         "Type" : "char(25)"
      },
      {
         "Default" : "",
         "Extra" : "",
         "Field" : "COUNTRY",
         "Key" : "",
         "Null" : "NO",
         "Type" : "char(6)"
      },
      {
         "Default" : null,
         "Extra" : "",
         "Field" : "LAUNCH",
         "Key" : "",
         "Null" : "YES",
         "Type" : "date"
      },
      {
         "Default" : null,
         "Extra" : "",
         "Field" : "SITE",
         "Key" : "",
         "Null" : "YES",
         "Type" : "char(5)"
      },
      {
         "Default" : null,
         "Extra" : "",
         "Field" : "DECAY",
         "Key" : "",
         "Null" : "YES",
         "Type" : "date"
      },
      {
         "Default" : null,
         "Extra" : "",
         "Field" : "PERIOD",
         "Key" : "",
         "Null" : "YES",
         "Type" : "float"
      },
      {
         "Default" : null,
         "Extra" : "",
         "Field" : "INCLINATION",
         "Key" : "",
         "Null" : "YES",
         "Type" : "float"
      },
      {
         "Default" : null,
         "Extra" : "",
         "Field" : "APOGEE",
         "Key" : "",
         "Null" : "YES",
         "Type" : "int(10) unsigned"
      },
      {
         "Default" : null,
         "Extra" : "",
         "Field" : "PERIGEE",
         "Key" : "",
         "Null" : "YES",
         "Type" : "int(10) unsigned"
      },
      {
         "Default" : null,
         "Extra" : "",
         "Field" : "COMMENT",
         "Key" : "",
         "Null" : "YES",
         "Type" : "char(32)"
      },
      {
         "Default" : null,
         "Extra" : "",
         "Field" : "COMMENTCODE",
         "Key" : "",
         "Null" : "YES",
         "Type" : "tinyint(3) unsigned"
      },
      {
         "Default" : null,
         "Extra" : "",
         "Field" : "RCSVALUE",
         "Key" : "",
         "Null" : "YES",
         "Type" : "float"
      },
      {
         "Default" : null,
         "Extra" : "",
         "Field" : "RCSSOURCE",
         "Key" : "",
         "Null" : "YES",
         "Type" : "char(3)"
      },
      {
         "Default" : "0",
         "Extra" : "",
         "Field" : "FILE",
         "Key" : "",
         "Null" : "NO",
         "Type" : "smallint(5) unsigned"
      },
      {
         "Default" : "0",
         "Extra" : "",
         "Field" : "LAUNCH_YEAR",
         "Key" : "",
         "Null" : "NO",
         "Type" : "smallint(5) unsigned"
      },
      {
         "Default" : "0",
         "Extra" : "",
         "Field" : "LAUNCH_NUM",
         "Key" : "",
         "Null" : "NO",
         "Type" : "smallint(5) unsigned"
      },
      {
         "Default" : "",
         "Extra" : "",
         "Field" : "LAUNCH_PIECE",
         "Key" : "",
         "Null" : "NO",
         "Type" : "char(3)"
      },
      {
         "Default" : "N",
         "Extra" : "",
         "Field" : "CURRENT",
         "Key" : "",
         "Null" : "NO",
         "Type" : "enum('Y','N')"
      }
   ]
}
EOD
    my $got = $json->decode( $rslt->content() );
    is_deeply $got, $expect, 'Got expected modeldef for class satcat'
	or do {
	diag <<'EOD';
Writing modeldef we got and we expect to satcat.got and satcat.expect
EOD
	dump_json( 'satcat.got', $got );
	dump_json( 'satcat.expect', $expect );
    };
}

$rslt = $st->spacetrack_query_v2( qw{
    basicspacedata modeldef class tle
    } );

ok $rslt->is_success(), 'Fetch modeldef for class tle';

if ( $rslt->is_success() ) {

    my $expect = $json->decode( <<'EOD' );
{
   "controller" : "basicspacedata",
   "data" : [
      {
         "Default" : "",
         "Extra" : "",
         "Field" : "COMMENT",
         "Key" : "",
         "Null" : "NO",
         "Type" : "varchar(32)"
      },
      {
         "Default" : "",
         "Extra" : "",
         "Field" : "ORIGINATOR",
         "Key" : "",
         "Null" : "NO",
         "Type" : "varchar(5)"
      },
      {
         "Default" : "0",
         "Extra" : "",
         "Field" : "NORAD_CAT_ID",
         "Key" : "",
         "Null" : "NO",
         "Type" : "mediumint(8) unsigned"
      },
      {
         "Default" : "",
         "Extra" : "",
         "Field" : "CLASSIFICATION_TYPE",
         "Key" : "",
         "Null" : "NO",
         "Type" : "char(1)"
      },
      {
         "Default" : "",
         "Extra" : "",
         "Field" : "INTLDES",
         "Key" : "",
         "Null" : "NO",
         "Type" : "varbinary(11)"
      },
      {
         "Default" : "0000-00-00 00:00:00",
         "Extra" : "",
         "Field" : "EPOCH",
         "Key" : "",
         "Null" : "NO",
         "Type" : "datetime"
      },
      {
         "Default" : "0",
         "Extra" : "",
         "Field" : "EPOCH_MICROSECONDS",
         "Key" : "",
         "Null" : "NO",
         "Type" : "mediumint(8) unsigned"
      },
      {
         "Default" : "0",
         "Extra" : "",
         "Field" : "MEAN_MOTION",
         "Key" : "",
         "Null" : "NO",
         "Type" : "double"
      },
      {
         "Default" : "0",
         "Extra" : "",
         "Field" : "ECCENTRICITY",
         "Key" : "",
         "Null" : "NO",
         "Type" : "double"
      },
      {
         "Default" : "0",
         "Extra" : "",
         "Field" : "INCLINATION",
         "Key" : "",
         "Null" : "NO",
         "Type" : "double"
      },
      {
         "Default" : "0",
         "Extra" : "",
         "Field" : "RA_OF_ASC_NODE",
         "Key" : "",
         "Null" : "NO",
         "Type" : "double"
      },
      {
         "Default" : "0",
         "Extra" : "",
         "Field" : "ARG_OF_PERICENTER",
         "Key" : "",
         "Null" : "NO",
         "Type" : "double"
      },
      {
         "Default" : "0",
         "Extra" : "",
         "Field" : "MEAN_ANOMALY",
         "Key" : "",
         "Null" : "NO",
         "Type" : "double"
      },
      {
         "Default" : "0",
         "Extra" : "",
         "Field" : "EPHEMERIS_TYPE",
         "Key" : "",
         "Null" : "NO",
         "Type" : "tinyint(3) unsigned"
      },
      {
         "Default" : "0",
         "Extra" : "",
         "Field" : "ELEMENT_SET_NO",
         "Key" : "",
         "Null" : "NO",
         "Type" : "smallint(5) unsigned"
      },
      {
         "Default" : "0",
         "Extra" : "",
         "Field" : "REV_AT_EPOCH",
         "Key" : "",
         "Null" : "NO",
         "Type" : "float"
      },
      {
         "Default" : "0",
         "Extra" : "",
         "Field" : "BSTAR",
         "Key" : "",
         "Null" : "NO",
         "Type" : "double"
      },
      {
         "Default" : "0",
         "Extra" : "",
         "Field" : "MEAN_MOTION_DOT",
         "Key" : "",
         "Null" : "NO",
         "Type" : "double"
      },
      {
         "Default" : "0",
         "Extra" : "",
         "Field" : "MEAN_MOTION_DDOT",
         "Key" : "",
         "Null" : "NO",
         "Type" : "double"
      },
      {
         "Default" : "0",
         "Extra" : "",
         "Field" : "FILE",
         "Key" : "",
         "Null" : "NO",
         "Type" : "int(10) unsigned"
      },
      {
         "Default" : "",
         "Extra" : "",
         "Field" : "TLE_LINE1",
         "Key" : "",
         "Null" : "NO",
         "Type" : "char(71)"
      },
      {
         "Default" : "",
         "Extra" : "",
         "Field" : "TLE_LINE2",
         "Key" : "",
         "Null" : "NO",
         "Type" : "char(71)"
      }
   ]
}
EOD
    my $got = $json->decode( $rslt->content() );
    is_deeply $got, $expect, 'Got expected modeldef for class tle'
	or do {
	diag <<'EOD';
Writing modeldef we got and we expect to tle.got and tle.expect
EOD
	dump_json( 'tle.got', $got );
	dump_json( 'tle.expect', $expect );
    };
}

done_testing;

1;

sub dump_json {
    my ( $fn, $data ) = @_;
    open my $fh, '>', $fn
	or die "Unable to open $fn for output: $!\n";
    print $fh, $json->encode( $data );
    close $fh;
    return;
}

# ex: set textwidth=72 :