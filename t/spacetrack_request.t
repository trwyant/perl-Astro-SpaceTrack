package main;

use strict;
use warnings;

use Test::More 0.96;

use Astro::SpaceTrack;
use HTTP::Status qw{ HTTP_I_AM_A_TEAPOT };

sub is_resp (@);
sub warning_like (@);
sub year();

my $loader = Astro::SpaceTrack->__get_loader() or do {
    plan skip_all => 'JSON required to check Space Track requests.';
    exit;
};

note 'Space Track v2 interface';

my $st = Astro::SpaceTrack->new(
    space_track_version	=> 2,
    dump_headers =>
	Astro::SpaceTrack->DUMP_REQUEST | Astro::SpaceTrack->DUMP_NO_EXECUTE,
);

my $base_url = $st->_make_space_track_base_url();

is_resp qw{retrieve 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle_latest',
	    format	=> 'tle',
	    orderby	=> 'OBJECT_NUMBER asc',
	    OBJECT_NUMBER => 25544,
	    ORDINAL	=> 1,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle_latest/format/tle/orderby/OBJECT_NUMBER%20asc/OBJECT_NUMBER/25544/ORDINAL/1",
	version => 2,
    } ],
;

is_resp qw{retrieve -sort catnum 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle_latest',
	    format	=> 'tle',
	    orderby	=> 'OBJECT_NUMBER asc',
	    OBJECT_NUMBER => 25544,
	    ORDINAL	=> 1,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle_latest/format/tle/orderby/OBJECT_NUMBER%20asc/OBJECT_NUMBER/25544/ORDINAL/1",
	version => 2,
    } ],
;

is_resp qw{retrieve -sort epoch 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle_latest',
	    format	=> 'tle',
	    orderby	=> 'EPOCH asc',
	    OBJECT_NUMBER => 25544,
	    ORDINAL	=> 1,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle_latest/format/tle/orderby/EPOCH%20asc/OBJECT_NUMBER/25544/ORDINAL/1",
	version => 2,
    } ],
;

is_resp qw{retrieve -descending 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle_latest',
	    format	=> 'tle',
	    orderby	=> 'OBJECT_NUMBER desc',
	    OBJECT_NUMBER => 25544,
	    ORDINAL	=> 1,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle_latest/format/tle/orderby/OBJECT_NUMBER%20desc/OBJECT_NUMBER/25544/ORDINAL/1",
	version => 2,
    } ],
;

is_resp qw{retrieve -last5 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle_latest',
	    format	=> 'tle',
	    orderby	=> 'OBJECT_NUMBER asc',
	    OBJECT_NUMBER => 25544,
	    ORDINAL	=> '1--5',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle_latest/format/tle/orderby/OBJECT_NUMBER%20asc/OBJECT_NUMBER/25544/ORDINAL/1--5",
	version => 2,
    } ],
;

{
    no warnings qw{ uninitialized };
    local $ENV{SPACETRACK_REST_FRACTIONAL_DATE} = undef;

    is_resp qw{retrieve -start_epoch 2009-04-01 25544}, [ {
	    args => [
		basicspacedata	=> 'query',
		class	=> 'tle',
		format	=> 'tle',
		orderby	=> 'OBJECT_NUMBER asc',
		EPOCH	=> '2009-04-01 00:00:00--2009-04-02 00:00:00',
		OBJECT_NUMBER => 25544,
	    ],
	    method => 'GET',
	    url => "$base_url/basicspacedata/query/class/tle/format/tle/orderby/OBJECT_NUMBER%20asc/EPOCH/2009-04-01%2000:00:00--2009-04-02%2000:00:00/OBJECT_NUMBER/25544",
	    version => 2,
	} ],
    ;

    is_resp qw{retrieve -last5 -start_epoch 2009-04-01 25544}, [ {
	    args => [
		basicspacedata	=> 'query',
		class	=> 'tle',
		format	=> 'tle',
		orderby	=> 'OBJECT_NUMBER asc',
		EPOCH	=> '2009-04-01 00:00:00--2009-04-02 00:00:00',
		OBJECT_NUMBER => 25544,
	    ],
	    method => 'GET',
	    url => "$base_url/basicspacedata/query/class/tle/format/tle/orderby/OBJECT_NUMBER%20asc/EPOCH/2009-04-01%2000:00:00--2009-04-02%2000:00:00/OBJECT_NUMBER/25544",
	    version => 2,
	} ],
    ;

    is_resp qw{retrieve -end_epoch 2009-04-01 25544}, [ {
	    args => [
		basicspacedata	=> 'query',
		class	=> 'tle',
		format	=> 'tle',
		orderby	=> 'OBJECT_NUMBER asc',
		EPOCH	=> '2009-03-31 00:00:00--2009-04-01 00:00:00',
		OBJECT_NUMBER => 25544,
	    ],
	    method => 'GET',
	    url => "$base_url/basicspacedata/query/class/tle/format/tle/orderby/OBJECT_NUMBER%20asc/EPOCH/2009-03-31%2000:00:00--2009-04-01%2000:00:00/OBJECT_NUMBER/25544",
	    version => 2,
	} ],
    ;

    is_resp qw{retrieve -start_epoch 2009-03-01 -end_epoch 2009-04-01 25544}, [ {
	    args => [
		basicspacedata	=> 'query',
		class	=> 'tle',
		format	=> 'tle',
		orderby	=> 'OBJECT_NUMBER asc',
		EPOCH	=> '2009-03-01 00:00:00--2009-04-01 00:00:00',
		OBJECT_NUMBER => 25544,
	    ],
	    method => 'GET',
	    url => "$base_url/basicspacedata/query/class/tle/format/tle/orderby/OBJECT_NUMBER%20asc/EPOCH/2009-03-01%2000:00:00--2009-04-01%2000:00:00/OBJECT_NUMBER/25544",
	    version => 2,
	} ],
    ;

}

note <<'EOD';
The point of the following test is to ensure that the request is being
properly broken into two pieces, and that the joining of the JSON in the
responses is being handled properly.
EOD

{

    local $Astro::SpaceTrack::RETRIEVAL_SIZE = 50;
    # Force undocumented hack to be turned off.
    no warnings qw{ uninitialized };
    local $ENV{SPACETRACK_REST_RANGE_OPERATOR} = undef;

    is_resp retrieve => 1 .. 66, [
	{
	    args => [
		basicspacedata	=> 'query',
		class		=> 'tle_latest',
		format		=> 'tle',
		orderby		=> 'OBJECT_NUMBER asc',
		OBJECT_NUMBER	=> '1--50',
		ORDINAL		=> 1,
	    ],
	    method	=> 'GET',
	    url => "$base_url/basicspacedata/query/class/tle_latest/format/tle/orderby/OBJECT_NUMBER%20asc/OBJECT_NUMBER/1--50/ORDINAL/1",
	    version	=> 2
	},
	{
	    args => [
		basicspacedata	=> 'query',
		class		=> 'tle_latest',
		format		=> 'tle',
		orderby		=> 'OBJECT_NUMBER asc',
		OBJECT_NUMBER	=> '51--66',
		ORDINAL		=> 1,
	    ],
	    method	=> 'GET',
	    url => "$base_url/basicspacedata/query/class/tle_latest/format/tle/orderby/OBJECT_NUMBER%20asc/OBJECT_NUMBER/51--66/ORDINAL/1",
	    version	=> 2
	},
    ],
    ;
}

is_resp qw{set with_name 1}, 'OK';

# NOTE That the following request is forced to JSON format so that we
# can build a NASA-format TLE from the result.
is_resp qw{retrieve 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle_latest',
	    format	=> '3le',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'OBJECT_NAME,TLE_LINE1,TLE_LINE2',
	    OBJECT_NUMBER => 25544,
	    ORDINAL	=> 1,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle_latest/format/3le/orderby/OBJECT_NUMBER%20asc/predicates/OBJECT_NAME,TLE_LINE1,TLE_LINE2/OBJECT_NUMBER/25544/ORDINAL/1",
	version => 2,
    } ],
;

is_resp qw{search_date 2009-04-01}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    LAUNCH	=> '2009-04-01',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/null-val/LAUNCH/2009-04-01",
	version => 2,
    },
;

is_resp qw{search_date -status all 2009-04-01}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    LAUNCH	=> '2009-04-01',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/LAUNCH/2009-04-01",
	version => 2,
    },
;

is_resp qw{search_date -status onorbit 2009-04-01}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    LAUNCH	=> '2009-04-01',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/null-val/LAUNCH/2009-04-01",
	version => 2,
    },
;

is_resp qw{search_date -status decayed 2009-04-01}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> '<>null-val',
	    LAUNCH	=> '2009-04-01',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/%3C%3Enull-val/LAUNCH/2009-04-01",
	version => 2,
    },
;

is_resp qw{search_date -exclude debris 2009-04-01}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    LAUNCH	=> '2009-04-01',
	    OBJECT_TYPE	=> 'PAYLOAD,ROCKET BODY,UNKNOWN,TBA,OTHER',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/null-val/LAUNCH/2009-04-01/OBJECT_TYPE/PAYLOAD,ROCKET%20BODY,UNKNOWN,TBA,OTHER",
	version => 2,
    },
;

is_resp qw{search_date -exclude rocket 2009-04-01}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    LAUNCH	=> '2009-04-01',
	    OBJECT_TYPE	=> 'PAYLOAD,DEBRIS,UNKNOWN,TBA,OTHER',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/null-val/LAUNCH/2009-04-01/OBJECT_TYPE/PAYLOAD,DEBRIS,UNKNOWN,TBA,OTHER",
	version => 2,
    },
;

{
    no warnings qw{qw};	## no critic (ProhibitNoWarnings)
    is_resp qw{search_date -exclude debris,rocket 2009-04-01}, {
	    args => [
		basicspacedata	=> 'query',
		class	=> 'satcat',
		format	=> 'json',
		orderby	=> 'OBJECT_NUMBER asc',
		predicates	=> 'all',
		CURRENT	=> 'Y',
		DECAY	=> 'null-val',
		LAUNCH	=> '2009-04-01',
		OBJECT_TYPE	=> 'PAYLOAD,UNKNOWN,TBA,OTHER',
	    ],
	    method => 'GET',
	    url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/null-val/LAUNCH/2009-04-01/OBJECT_TYPE/PAYLOAD,UNKNOWN,TBA,OTHER",
	version => 2,
	},
    ;
}

is_resp qw{search_date -exclude debris -exclude rocket 2009-04-01}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    LAUNCH	=> '2009-04-01',
	    OBJECT_TYPE	=> 'PAYLOAD,UNKNOWN,TBA,OTHER',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/null-val/LAUNCH/2009-04-01/OBJECT_TYPE/PAYLOAD,UNKNOWN,TBA,OTHER",
	version => 2,
    },
;

is_resp qw{search_id 98067}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    OBJECT_ID	=> '~~1998-067',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/null-val/OBJECT_ID/~~1998-067",
	version => 2,
    },
;

is_resp qw{search_id 98}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    OBJECT_ID	=> '~~1998-',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/null-val/OBJECT_ID/~~1998-",
	version => 2,
    },
;

is_resp qw{search_id 98067A}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    OBJECT_ID	=> '1998-067A',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/null-val/OBJECT_ID/1998-067A",
	version => 2,
    },
;

is_resp qw{search_id -status all 98067}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    OBJECT_ID	=> '~~1998-067',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/OBJECT_ID/~~1998-067",
	version => 2,
    },
;

is_resp qw{search_id -status onorbit 98067}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    OBJECT_ID	=> '~~1998-067',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/null-val/OBJECT_ID/~~1998-067",
	version => 2,
    },
;

is_resp qw{search_id -status decayed 98067}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> '<>null-val',
	    OBJECT_ID	=> '~~1998-067',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/%3C%3Enull-val/OBJECT_ID/~~1998-067",
	version => 2,
    },
;

is_resp qw{search_id -exclude debris 98067}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    OBJECT_ID	=> '~~1998-067',
	    OBJECT_TYPE	=> 'PAYLOAD,ROCKET BODY,UNKNOWN,TBA,OTHER',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/null-val/OBJECT_ID/~~1998-067/OBJECT_TYPE/PAYLOAD,ROCKET%20BODY,UNKNOWN,TBA,OTHER",
	version => 2,
    },
;

is_resp qw{search_id -exclude rocket 98067}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    OBJECT_ID	=> '~~1998-067',
	    OBJECT_TYPE	=> 'PAYLOAD,DEBRIS,UNKNOWN,TBA,OTHER',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/null-val/OBJECT_ID/~~1998-067/OBJECT_TYPE/PAYLOAD,DEBRIS,UNKNOWN,TBA,OTHER",
	version => 2,
    },
;

{
    no warnings qw{qw};	## no critic (ProhibitNoWarnings)
    is_resp qw{search_id -exclude debris,rocket 98067}, {
	    args => [
		basicspacedata	=> 'query',
		class	=> 'satcat',
		format	=> 'json',
		orderby	=> 'OBJECT_NUMBER asc',
		predicates	=> 'all',
		CURRENT	=> 'Y',
		DECAY	=> 'null-val',
		OBJECT_ID	=> '~~1998-067',
		OBJECT_TYPE	=> 'PAYLOAD,UNKNOWN,TBA,OTHER',
	    ],
	    method => 'GET',
	    url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/null-val/OBJECT_ID/~~1998-067/OBJECT_TYPE/PAYLOAD,UNKNOWN,TBA,OTHER",
	version => 2,
	},
    ;
}

is_resp qw{search_id -exclude debris -exclude rocket 98067}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    OBJECT_ID	=> '~~1998-067',
	    OBJECT_TYPE	=> 'PAYLOAD,UNKNOWN,TBA,OTHER',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/null-val/OBJECT_ID/~~1998-067/OBJECT_TYPE/PAYLOAD,UNKNOWN,TBA,OTHER",
	version => 2,
    },
;

is_resp qw{search_name ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    OBJECT_NAME	=> '~~ISS',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/null-val/OBJECT_NAME/~~ISS",
	version => 2,
    },
;

is_resp qw{search_name -status all ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    OBJECT_NAME	=> '~~ISS',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/OBJECT_NAME/~~ISS",
	version => 2,
    },
;

is_resp qw{search_name -status onorbit ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    OBJECT_NAME	=> '~~ISS',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/null-val/OBJECT_NAME/~~ISS",
	version => 2,
    },
;

is_resp qw{search_name -status decayed ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> '<>null-val',
	    OBJECT_NAME	=> '~~ISS',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/%3C%3Enull-val/OBJECT_NAME/~~ISS",
	version => 2,
    },
;

is_resp qw{search_name -exclude debris ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    OBJECT_NAME	=> '~~ISS',
	    OBJECT_TYPE	=> 'PAYLOAD,ROCKET BODY,UNKNOWN,TBA,OTHER',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/null-val/OBJECT_NAME/~~ISS/OBJECT_TYPE/PAYLOAD,ROCKET%20BODY,UNKNOWN,TBA,OTHER",
	version => 2,
    },
;

is_resp qw{search_name -exclude rocket ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    OBJECT_NAME	=> '~~ISS',
	    OBJECT_TYPE	=> 'PAYLOAD,DEBRIS,UNKNOWN,TBA,OTHER',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/null-val/OBJECT_NAME/~~ISS/OBJECT_TYPE/PAYLOAD,DEBRIS,UNKNOWN,TBA,OTHER",
	version => 2,
    },
;

{
    no warnings qw{qw};	## no critic (ProhibitNoWarnings)
    is_resp qw{search_name -exclude debris,rocket ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    OBJECT_NAME	=> '~~ISS',
	    OBJECT_TYPE	=> 'PAYLOAD,UNKNOWN,TBA,OTHER',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/null-val/OBJECT_NAME/~~ISS/OBJECT_TYPE/PAYLOAD,UNKNOWN,TBA,OTHER",
	version => 2,
	},
    ;
}

is_resp qw{search_name -exclude debris -exclude rocket ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'OBJECT_NUMBER asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    OBJECT_NAME	=> '~~ISS',
	    OBJECT_TYPE	=> 'PAYLOAD,UNKNOWN,TBA,OTHER',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/OBJECT_NUMBER%20asc/predicates/all/CURRENT/Y/DECAY/null-val/OBJECT_NAME/~~ISS/OBJECT_TYPE/PAYLOAD,UNKNOWN,TBA,OTHER",
	version => 2,
    },
;

is_resp qw{spacetrack iridium}, {
	args => [
	    basicspacedata	=> 'query',
	    class		=> 'tle_latest',
	    format		=> '3le',
	    orderby		=> 'OBJECT_NUMBER asc',
	    predicates		=> 'OBJECT_NAME,TLE_LINE1,TLE_LINE2',
	    EPOCH		=> '>now-30',
	    OBJECT_NAME		=> 'iridium~~',
	    OBJECT_TYPE		=> 'payload',
	    ORDINAL		=> 1,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle_latest/format/3le/orderby/OBJECT_NUMBER%20asc/predicates/OBJECT_NAME,TLE_LINE1,TLE_LINE2/EPOCH/%3Enow-30/OBJECT_NAME/iridium~~/OBJECT_TYPE/payload/ORDINAL/1",
	version => 2,
    },
;

is_resp qw{ spacetrack special }, {
	args => [
	    basicspacedata	=> 'query',
	    class		=> 'tle_latest',
	    favorites		=> 'Special_interest',
	    format		=> '3le',
	    predicates		=> 'OBJECT_NAME,TLE_LINE1,TLE_LINE2',
	    EPOCH		=> '>now-30',
	    ORDINAL		=> 1
	],
	method	=> 'GET',
	url	=> "$base_url/basicspacedata/query/class/tle_latest/favorites/Special_interest/format/3le/predicates/OBJECT_NAME,TLE_LINE1,TLE_LINE2/EPOCH/%3Enow-30/ORDINAL/1",
	version	=> 2
    }
;

is_resp qw{set with_name 0}, 'OK';


is_resp qw{spacetrack iridium}, {
	args => [
	    basicspacedata	=> 'query',
	    class		=> 'tle_latest',
	    format		=> 'tle',
	    orderby		=> 'OBJECT_NUMBER asc',
	    EPOCH		=> '>now-30',
	    OBJECT_NAME		=> 'iridium~~',
	    OBJECT_TYPE		=> 'payload',
	    ORDINAL		=> 1,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle_latest/format/tle/orderby/OBJECT_NUMBER%20asc/EPOCH/%3Enow-30/OBJECT_NAME/iridium~~/OBJECT_TYPE/payload/ORDINAL/1",
	version => 2,
    },
;

=begin comment

# TODO Not supported by Space Track v2 interface
is_resp qw{spacetrack 10}, {
	args => [
	    basicspacedata	=> 'query',
	],
	method => 'GET',
	url => $base_url,
	version => 2,
    },
;

=end comment

=cut

is_resp qw{box_score}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'boxscore',
	    format	=> 'json',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/boxscore/format/json/predicates/all",
	version => 2,
    },
;

done_testing;

my $warning;

sub warning_like (@) {
    splice @_, 0, 0, $warning;
    goto &like;
}

sub is_resp (@) {	## no critic (RequireArgUnpacking)
    my @args = @_;
    my $opt = 'HASH' eq ref $args[0] ? shift @args : {};
    my $method = shift @args;
    my $query = pop @args;
    my $name = "\$st->$method(" . join( ', ', map {"'$_'"} @args ) . ')';
    my $resp;
    {
	$warning = undef;
	local $SIG{__WARN__} = sub { $warning = $_[0] };
	$resp = $st->$method( @args );
	not defined $warning
	    or $opt->{allow_warning}
	    or do {
	    $warning =~ s{\bat t/spacetrack_request.t\b.*}{}sm;
	    @_ = qq{$name. Unexpected warning "$warning"};
	    goto &fail;
	};
    }
    my ($got);

    if ( $resp && $resp->isa('HTTP::Response') ) {
	if ( $resp->code() == HTTP_I_AM_A_TEAPOT ) {
	    $got = $loader->( $resp->content() );
	} elsif ( $resp->is_success() ) {
	    $got = $resp->content();
	} else {
	    $got = $resp->status_line();
	}
    } else {
	$got = $resp;
    }

    @_ = ($got, $query, $name);
    goto &is_deeply;
}

sub year () {
    return (localtime)[5] + 1900;
}

1;
