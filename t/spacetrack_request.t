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

my $st = Astro::SpaceTrack->new(
    space_track_version	=> 1,
    dump_headers =>
	Astro::SpaceTrack->DUMP_REQUEST | Astro::SpaceTrack->DUMP_NO_EXECUTE,
);

my $base_url = $st->_make_space_track_base_url();

note 'Space Track v1 interface';

is_resp qw{retrieve 25544}, {
	args => {
	    _sessionid => '',
	    _submitted => 1,
	    ascii => 'yes',
	    common_name => '',
	    descending => '',
	    ids => 25544,
	    sort => 'catnum',
	    timeframe => 'latest',
	},
	method => 'POST',
	url => "$base_url/perl/id_query.pl",
	version => 1,
    },
;

is_resp qw{retrieve -sort catnum 25544}, {
	args => {
	    _sessionid => '',
	    _submitted => 1,
	    ascii => 'yes',
	    common_name => '',
	    descending => '',
	    ids => 25544,
	    sort => 'catnum',
	    timeframe => 'latest',
	},
	method => 'POST',
	url => "$base_url/perl/id_query.pl",
	version => 1,
    },
;

is_resp qw{retrieve -sort epoch 25544}, {
	args => {
	    _sessionid => '',
	    _submitted => 1,
	    ascii => 'yes',
	    common_name => '',
	    descending => '',
	    ids => 25544,
	    sort => 'epoch',
	    timeframe => 'latest',
	},
	method => 'POST',
	url => "$base_url/perl/id_query.pl",
	version => 1,
    },
;

is_resp qw{retrieve -descending 25544}, {
	args => {
	    _sessionid => '',
	    _submitted => 1,
	    ascii => 'yes',
	    common_name => '',
	    descending => 'yes',
	    ids => 25544,
	    sort => 'catnum',
	    timeframe => 'latest',
	},
	method => 'POST',
	url => "$base_url/perl/id_query.pl",
	version => 1,
    },
;

is_resp qw{retrieve -last5 25544}, {
	args => {
	    _sessionid => '',
	    _submitted => 1,
	    ascii => 'yes',
	    common_name => '',
	    descending => '',
	    ids => 25544,
	    sort => 'catnum',
	    timeframe => 'last5',
	},
	method => 'POST',
	url => "$base_url/perl/id_query.pl",
	version => 1,
    },
;

is_resp qw{retrieve -start_epoch 2009-04-01 25544}, {
	args => {
	    _sessionid => '',
	    _submitted => 1,
	    ascii => 'yes',
	    common_name => '',
	    descending => '',
	    end_day => 2,
	    end_month => 4,
	    end_year => 2009,
	    ids => 25544,
	    sort => 'catnum',
	    start_day => 1,
	    start_month => 4,
	    start_year => 2009,
	    timeframe => 'timespan',
	},
	method => 'POST',
	url => "$base_url/perl/id_query.pl",
	version => 1,
    },
;

is_resp qw{retrieve -last5 -start_epoch 2009-04-01 25544}, {
	args => {
	    _sessionid => '',
	    _submitted => 1,
	    ascii => 'yes',
	    common_name => '',
	    descending => '',
	    end_day => 2,
	    end_month => 4,
	    end_year => 2009,
	    ids => 25544,
	    sort => 'catnum',
	    start_day => 1,
	    start_month => 4,
	    start_year => 2009,
	    timeframe => 'timespan',
	},
	method => 'POST',
	url => "$base_url/perl/id_query.pl",
	version => 1,
    },
;

is_resp qw{retrieve -end_epoch 2009-04-01 25544}, {
	args => {
	    _sessionid => '',
	    _submitted => 1,
	    ascii => 'yes',
	    common_name => '',
	    descending => '',
	    end_day => 1,
	    end_month => 4,
	    end_year => 2009,
	    ids => 25544,
	    sort => 'catnum',
	    start_day => 31,
	    start_month => 3,
	    start_year => 2009,
	    timeframe => 'timespan',
	},
	method => 'POST',
	url => "$base_url/perl/id_query.pl",
	version => 1,
    },
;

is_resp qw{retrieve -start_epoch 2009-03-01 -end_epoch 2009-04-01 25544}, {
	args => {
	    _sessionid => '',
	    _submitted => 1,
	    ascii => 'yes',
	    common_name => '',
	    descending => '',
	    end_day => 1,
	    end_month => 4,
	    end_year => 2009,
	    ids => 25544,
	    sort => 'catnum',
	    start_day => 1,
	    start_month => 3,
	    start_year => 2009,
	    timeframe => 'timespan',
	},
	method => 'POST',
	url => "$base_url/perl/id_query.pl",
	version => 1,
    },
;

is_resp qw{set with_name 1}, 'OK';

is_resp qw{retrieve 25544}, {
	args => {
	    _sessionid => '',
	    _submitted => 1,
	    ascii => 'yes',
	    common_name => 'yes',
	    descending => '',
	    ids => 25544,
	    sort => 'catnum',
	    timeframe => 'latest',
	},
	method => 'POST',
	url => "$base_url/perl/id_query.pl",
	version => 1,
    },
;

is_resp qw{search_date 2009-04-01}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'month',
	    exclude => [],
	    launch_day => '01',
	    launch_month => '04',
	    launch_year => '2009',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_date -status all 2009-04-01}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'month',
	    exclude => [],
	    launch_day => '01',
	    launch_month => '04',
	    launch_year => '2009',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_date -status onorbit 2009-04-01}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'month',
	    exclude => [],
	    launch_day => '01',
	    launch_month => '04',
	    launch_year => '2009',
	    status => 'onorbit',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_date -status decayed 2009-04-01}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'month',
	    exclude => [],
	    launch_day => '01',
	    launch_month => '04',
	    launch_year => '2009',
	    status => 'decayed',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_date -exclude debris 2009-04-01}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'month',
	    exclude => [qw{debris}],
	    launch_day => '01',
	    launch_month => '04',
	    launch_year => '2009',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_date -exclude rocket 2009-04-01}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'month',
	    exclude => [qw{rocket}],
	    launch_day => '01',
	    launch_month => '04',
	    launch_year => '2009',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

{
    no warnings qw{qw};	## no critic (ProhibitNoWarnings)
    is_resp qw{search_date -exclude debris,rocket 2009-04-01}, {
	    args => {
		_sessionid => '',
		_submit => 'submit',
		_submitted => 1,
		date_spec => 'month',
		exclude => [qw{debris rocket}],
		launch_day => '01',
		launch_month => '04',
		launch_year => '2009',
		status => 'all',
	    },
	    method => 'POST',
	    url => "$base_url/perl/launch_query.pl",
	version => 1,
	},
    ;
}

is_resp qw{search_date -exclude debris -exclude rocket 2009-04-01}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'month',
	    exclude => [qw{debris rocket}],
	    launch_day => '01',
	    launch_month => '04',
	    launch_year => '2009',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_id 98067}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'number',
	    exclude => [],
	    launch_number => '067',
	    launch_year => '1998',
	    piece => '',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_id 98}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'number',
	    exclude => [],
	    launch_number => '',
	    launch_year => '1998',
	    piece => '',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_id 98067A}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'number',
	    exclude => [],
	    launch_number => '067',
	    launch_year => '1998',
	    piece => 'A',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_id -status all 98067}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'number',
	    exclude => [],
	    launch_number => '067',
	    launch_year => '1998',
	    piece => '',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_id -status onorbit 98067}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'number',
	    exclude => [],
	    launch_number => '067',
	    launch_year => '1998',
	    piece => '',
	    status => 'onorbit',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_id -status decayed 98067}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'number',
	    exclude => [],
	    launch_number => '067',
	    launch_year => '1998',
	    piece => '',
	    status => 'decayed',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_id -exclude debris 98067}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'number',
	    exclude => [qw{debris}],
	    launch_number => '067',
	    launch_year => '1998',
	    piece => '',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_id -exclude rocket 98067}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'number',
	    exclude => [qw{rocket}],
	    launch_number => '067',
	    launch_year => '1998',
	    piece => '',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

{
    no warnings qw{qw};	## no critic (ProhibitNoWarnings)
    is_resp qw{search_id -exclude debris,rocket 98067}, {
	    args => {
		_sessionid => '',
		_submit => 'submit',
		_submitted => 1,
		date_spec => 'number',
		exclude => [qw{debris rocket}],
		launch_number => '067',
		launch_year => '1998',
		piece => '',
		status => 'all',
	    },
	    method => 'POST',
	    url => "$base_url/perl/launch_query.pl",
	    version => 1,
	},
    ;
}

is_resp qw{search_id -exclude debris -exclude rocket 98067}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'number',
	    exclude => [qw{debris rocket}],
	    launch_number => '067',
	    launch_year => '1998',
	    piece => '',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_name ISS}, {
	args => {
	    _sessionid => '',
	    _submit => 'Submit',
	    _submitted => 1,
	    exclude => [],
	    launch_year_end => year,
	    launch_year_start => 1957,
	    name => 'ISS',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/name_query.pl",
	version => 1,
    },
;

is_resp qw{search_name -status all ISS}, {
	args => {
	    _sessionid => '',
	    _submit => 'Submit',
	    _submitted => 1,
	    exclude => [],
	    launch_year_end => year,
	    launch_year_start => 1957,
	    name => 'ISS',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/name_query.pl",
	version => 1,
    },
;

is_resp qw{search_name -status onorbit ISS}, {
	args => {
	    _sessionid => '',
	    _submit => 'Submit',
	    _submitted => 1,
	    exclude => [],
	    launch_year_end => year,
	    launch_year_start => 1957,
	    name => 'ISS',
	    status => 'onorbit',
	},
	method => 'POST',
	url => "$base_url/perl/name_query.pl",
	version => 1,
    },
;

is_resp qw{search_name -status decayed ISS}, {
	args => {
	    _sessionid => '',
	    _submit => 'Submit',
	    _submitted => 1,
	    exclude => [],
	    launch_year_end => year,
	    launch_year_start => 1957,
	    name => 'ISS',
	    status => 'decayed',
	},
	method => 'POST',
	url => "$base_url/perl/name_query.pl",
	version => 1,
    },
;

is_resp qw{search_name -exclude debris ISS}, {
	args => {
	    _sessionid => '',
	    _submit => 'Submit',
	    _submitted => 1,
	    exclude => [qw{debris}],
	    launch_year_end => year,
	    launch_year_start => 1957,
	    name => 'ISS',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/name_query.pl",
	version => 1,
    },
;

is_resp qw{search_name -exclude rocket ISS}, {
	args => {
	    _sessionid => '',
	    _submit => 'Submit',
	    _submitted => 1,
	    exclude => [qw{rocket}],
	    launch_year_end => year,
	    launch_year_start => 1957,
	    name => 'ISS',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/name_query.pl",
	version => 1,
    },
;

{
    no warnings qw{qw};	## no critic (ProhibitNoWarnings)
    is_resp qw{search_name -exclude debris,rocket ISS}, {
	    args => {
		_sessionid => '',
		_submit => 'Submit',
		_submitted => 1,
		exclude => [qw{debris rocket}],
		launch_year_end => year,
		launch_year_start => 1957,
		name => 'ISS',
		status => 'all',
	    },
	    method => 'POST',
	    url => "$base_url/perl/name_query.pl",
	    version => 1,
	},
    ;
}

is_resp qw{search_name -exclude debris -exclude rocket ISS}, {
	args => {
	    _sessionid => '',
	    _submit => 'Submit',
	    _submitted => 1,
	    exclude => [qw{debris rocket}],
	    launch_year_end => year,
	    launch_year_start => 1957,
	    name => 'ISS',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/name_query.pl",
	version => 1,
    },
;

is_resp qw{spacetrack iridium}, {
	args => {
	    ID => 10,
	},
	method => 'GET',
	url => "$base_url/perl/dl.pl?ID=10",
	version => 1,
    },
;

is_resp qw{set with_name 0}, 'OK';

is_resp qw{spacetrack iridium}, {
	args => {
	    ID => 9,
	},
	method => 'GET',
	url => "$base_url/perl/dl.pl?ID=9",
	version => 1,
    },
;

is_resp { allow_warning => 1 }, qw{spacetrack 10}, {
	args => {
	    ID => 10,
	},
	method => 'GET',
	url => "$base_url/perl/dl.pl?ID=10",
	version => 1,
    },
;

warning_like qr{\ACatalog '10' will not be supported},
    q{spacetrack( 10 ) should warn};

is_resp qw{box_score}, {
	args => {
	},
	method => 'GET',
	url => "$base_url/perl/boxscore.pl",
	version => 1,
    },
;

################################

note 'Space Track v2 interface';

$st->set( space_track_version => 2 );

$base_url = $st->_make_space_track_base_url();

is_resp qw{retrieve 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle_latest',
	    format	=> 'tle',
	    orderby	=> 'NORAD_CAT_ID asc',
	    NORAD_CAT_ID => 25544,
	    ORDINAL	=> 1,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle_latest/format/tle/orderby/NORAD_CAT_ID%20asc/NORAD_CAT_ID/25544/ORDINAL/1",
	version => 2,
    } ],
;

is_resp qw{retrieve -sort catnum 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle_latest',
	    format	=> 'tle',
	    orderby	=> 'NORAD_CAT_ID asc',
	    NORAD_CAT_ID => 25544,
	    ORDINAL	=> 1,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle_latest/format/tle/orderby/NORAD_CAT_ID%20asc/NORAD_CAT_ID/25544/ORDINAL/1",
	version => 2,
    } ],
;

is_resp qw{retrieve -sort epoch 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle_latest',
	    format	=> 'tle',
	    orderby	=> 'EPOCH asc',
	    NORAD_CAT_ID => 25544,
	    ORDINAL	=> 1,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle_latest/format/tle/orderby/EPOCH%20asc/NORAD_CAT_ID/25544/ORDINAL/1",
	version => 2,
    } ],
;

is_resp qw{retrieve -descending 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle_latest',
	    format	=> 'tle',
	    orderby	=> 'NORAD_CAT_ID desc',
	    NORAD_CAT_ID => 25544,
	    ORDINAL	=> 1,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle_latest/format/tle/orderby/NORAD_CAT_ID%20desc/NORAD_CAT_ID/25544/ORDINAL/1",
	version => 2,
    } ],
;

is_resp qw{retrieve -last5 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle_latest',
	    format	=> 'tle',
	    orderby	=> 'NORAD_CAT_ID asc',
	    NORAD_CAT_ID => 25544,
	    ORDINAL	=> '1--5',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle_latest/format/tle/orderby/NORAD_CAT_ID%20asc/NORAD_CAT_ID/25544/ORDINAL/1--5",
	version => 2,
    } ],
;

is_resp qw{retrieve -start_epoch 2009-04-01 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle',
	    format	=> 'tle',
	    orderby	=> 'NORAD_CAT_ID asc',
	    EPOCH	=> '2009-04-01--2009-04-02',
	    NORAD_CAT_ID => 25544,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle/format/tle/orderby/NORAD_CAT_ID%20asc/EPOCH/2009-04-01--2009-04-02/NORAD_CAT_ID/25544",
	version => 2,
    } ],
;

is_resp qw{retrieve -last5 -start_epoch 2009-04-01 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle',
	    format	=> 'tle',
	    orderby	=> 'NORAD_CAT_ID asc',
	    EPOCH	=> '2009-04-01--2009-04-02',
	    NORAD_CAT_ID => 25544,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle/format/tle/orderby/NORAD_CAT_ID%20asc/EPOCH/2009-04-01--2009-04-02/NORAD_CAT_ID/25544",
	version => 2,
    } ],
;

is_resp qw{retrieve -end_epoch 2009-04-01 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle',
	    format	=> 'tle',
	    orderby	=> 'NORAD_CAT_ID asc',
	    EPOCH	=> '2009-03-31--2009-04-01',
	    NORAD_CAT_ID => 25544,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle/format/tle/orderby/NORAD_CAT_ID%20asc/EPOCH/2009-03-31--2009-04-01/NORAD_CAT_ID/25544",
	version => 2,
    } ],
;

is_resp qw{retrieve -start_epoch 2009-03-01 -end_epoch 2009-04-01 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle',
	    format	=> 'tle',
	    orderby	=> 'NORAD_CAT_ID asc',
	    EPOCH	=> '2009-03-01--2009-04-01',
	    NORAD_CAT_ID => 25544,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle/format/tle/orderby/NORAD_CAT_ID%20asc/EPOCH/2009-03-01--2009-04-01/NORAD_CAT_ID/25544",
	version => 2,
    } ],
;

note <<'EOD';
The point of the following test is to ensure that the request is being
properly broken into two pieces, and that the joining of the JSON in the
responses is being handled properly.
EOD

{

    local $Astro::SpaceTrack::RETRIEVAL_SIZE = 50;
    # Force undocumented hack to be turned off.
    local $ENV{SPACETRACK_REST_RANGE_OPERATOR} = 0;

    is_resp retrieve => 1 .. 66, [
	{
	    args => [
		basicspacedata	=> 'query',
		class		=> 'tle_latest',
		format		=> 'tle',
		orderby		=> 'NORAD_CAT_ID asc',
		NORAD_CAT_ID	=> '1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50',
		ORDINAL		=> 1,
	    ],
	    method	=> 'GET',
	    url => "$base_url/basicspacedata/query/class/tle_latest/format/tle/orderby/NORAD_CAT_ID%20asc/NORAD_CAT_ID/1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50/ORDINAL/1",
	    version	=> 2
	},
	{
	    args => [
		basicspacedata	=> 'query',
		class		=> 'tle_latest',
		format		=> 'tle',
		orderby		=> 'NORAD_CAT_ID asc',
		NORAD_CAT_ID	=> '51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66',
		ORDINAL		=> 1,
	    ],
	    method	=> 'GET',
	    url => "$base_url/basicspacedata/query/class/tle_latest/format/tle/orderby/NORAD_CAT_ID%20asc/NORAD_CAT_ID/51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66/ORDINAL/1",
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
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'OBJECT_NAME,TLE_LINE1,TLE_LINE2',
	    NORAD_CAT_ID => 25544,
	    ORDINAL	=> 1,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle_latest/format/3le/orderby/NORAD_CAT_ID%20asc/predicates/OBJECT_NAME,TLE_LINE1,TLE_LINE2/NORAD_CAT_ID/25544/ORDINAL/1",
	version => 2,
    } ],
;

is_resp qw{search_date 2009-04-01}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    LAUNCH	=> '2009-04-01',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/null-val/LAUNCH/2009-04-01",
	version => 2,
    },
;

is_resp qw{search_date -status all 2009-04-01}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    LAUNCH	=> '2009-04-01',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/LAUNCH/2009-04-01",
	version => 2,
    },
;

is_resp qw{search_date -status onorbit 2009-04-01}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    LAUNCH	=> '2009-04-01',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/null-val/LAUNCH/2009-04-01",
	version => 2,
    },
;

is_resp qw{search_date -status decayed 2009-04-01}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> '<>null-val',
	    LAUNCH	=> '2009-04-01',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/%3C%3Enull-val/LAUNCH/2009-04-01",
	version => 2,
    },
;

is_resp qw{search_date -exclude debris 2009-04-01}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    LAUNCH	=> '2009-04-01',
	    OBJECT_TYPE	=> 'PAYLOAD,ROCKET BODY,UNKNOWN,OTHER',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/null-val/LAUNCH/2009-04-01/OBJECT_TYPE/PAYLOAD,ROCKET%20BODY,UNKNOWN,OTHER",
	version => 2,
    },
;

is_resp qw{search_date -exclude rocket 2009-04-01}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    LAUNCH	=> '2009-04-01',
	    OBJECT_TYPE	=> 'PAYLOAD,DEBRIS,UNKNOWN,OTHER',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/null-val/LAUNCH/2009-04-01/OBJECT_TYPE/PAYLOAD,DEBRIS,UNKNOWN,OTHER",
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
		orderby	=> 'NORAD_CAT_ID asc',
		predicates	=> 'all',
		CURRENT	=> 'Y',
		DECAY	=> 'null-val',
		LAUNCH	=> '2009-04-01',
		OBJECT_TYPE	=> 'PAYLOAD,UNKNOWN,OTHER',
	    ],
	    method => 'GET',
	    url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/null-val/LAUNCH/2009-04-01/OBJECT_TYPE/PAYLOAD,UNKNOWN,OTHER",
	version => 2,
	},
    ;
}

is_resp qw{search_date -exclude debris -exclude rocket 2009-04-01}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    LAUNCH	=> '2009-04-01',
	    OBJECT_TYPE	=> 'PAYLOAD,UNKNOWN,OTHER',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/null-val/LAUNCH/2009-04-01/OBJECT_TYPE/PAYLOAD,UNKNOWN,OTHER",
	version => 2,
    },
;

is_resp qw{search_id 98067}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    INTLDES	=> '~~1998-067',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/null-val/INTLDES/~~1998-067",
	version => 2,
    },
;

is_resp qw{search_id 98}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    INTLDES	=> '~~1998-',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/null-val/INTLDES/~~1998-",
	version => 2,
    },
;

is_resp qw{search_id 98067A}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    INTLDES	=> '1998-067A',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/null-val/INTLDES/1998-067A",
	version => 2,
    },
;

is_resp qw{search_id -status all 98067}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    INTLDES	=> '~~1998-067',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/INTLDES/~~1998-067",
	version => 2,
    },
;

is_resp qw{search_id -status onorbit 98067}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    INTLDES	=> '~~1998-067',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/null-val/INTLDES/~~1998-067",
	version => 2,
    },
;

is_resp qw{search_id -status decayed 98067}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> '<>null-val',
	    INTLDES	=> '~~1998-067',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/%3C%3Enull-val/INTLDES/~~1998-067",
	version => 2,
    },
;

is_resp qw{search_id -exclude debris 98067}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    INTLDES	=> '~~1998-067',
	    OBJECT_TYPE	=> 'PAYLOAD,ROCKET BODY,UNKNOWN,OTHER',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/null-val/INTLDES/~~1998-067/OBJECT_TYPE/PAYLOAD,ROCKET%20BODY,UNKNOWN,OTHER",
	version => 2,
    },
;

is_resp qw{search_id -exclude rocket 98067}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    INTLDES	=> '~~1998-067',
	    OBJECT_TYPE	=> 'PAYLOAD,DEBRIS,UNKNOWN,OTHER',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/null-val/INTLDES/~~1998-067/OBJECT_TYPE/PAYLOAD,DEBRIS,UNKNOWN,OTHER",
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
		orderby	=> 'NORAD_CAT_ID asc',
		predicates	=> 'all',
		CURRENT	=> 'Y',
		DECAY	=> 'null-val',
		INTLDES	=> '~~1998-067',
		OBJECT_TYPE	=> 'PAYLOAD,UNKNOWN,OTHER',
	    ],
	    method => 'GET',
	    url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/null-val/INTLDES/~~1998-067/OBJECT_TYPE/PAYLOAD,UNKNOWN,OTHER",
	version => 2,
	},
    ;
}

is_resp qw{search_id -exclude debris -exclude rocket 98067}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    INTLDES	=> '~~1998-067',
	    OBJECT_TYPE	=> 'PAYLOAD,UNKNOWN,OTHER',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/null-val/INTLDES/~~1998-067/OBJECT_TYPE/PAYLOAD,UNKNOWN,OTHER",
	version => 2,
    },
;

is_resp qw{search_name ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    SATNAME	=> '~~ISS',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/null-val/SATNAME/~~ISS",
	version => 2,
    },
;

is_resp qw{search_name -status all ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    SATNAME	=> '~~ISS',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/SATNAME/~~ISS",
	version => 2,
    },
;

is_resp qw{search_name -status onorbit ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    SATNAME	=> '~~ISS',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/null-val/SATNAME/~~ISS",
	version => 2,
    },
;

is_resp qw{search_name -status decayed ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> '<>null-val',
	    SATNAME	=> '~~ISS',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/%3C%3Enull-val/SATNAME/~~ISS",
	version => 2,
    },
;

is_resp qw{search_name -exclude debris ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    OBJECT_TYPE	=> 'PAYLOAD,ROCKET BODY,UNKNOWN,OTHER',
	    SATNAME	=> '~~ISS',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/null-val/OBJECT_TYPE/PAYLOAD,ROCKET%20BODY,UNKNOWN,OTHER/SATNAME/~~ISS",
	version => 2,
    },
;

is_resp qw{search_name -exclude rocket ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    OBJECT_TYPE	=> 'PAYLOAD,DEBRIS,UNKNOWN,OTHER',
	    SATNAME	=> '~~ISS',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/null-val/OBJECT_TYPE/PAYLOAD,DEBRIS,UNKNOWN,OTHER/SATNAME/~~ISS",
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
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    OBJECT_TYPE	=> 'PAYLOAD,UNKNOWN,OTHER',
	    SATNAME	=> '~~ISS',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/null-val/OBJECT_TYPE/PAYLOAD,UNKNOWN,OTHER/SATNAME/~~ISS",
	version => 2,
	},
    ;
}

is_resp qw{search_name -exclude debris -exclude rocket ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    OBJECT_TYPE	=> 'PAYLOAD,UNKNOWN,OTHER',
	    SATNAME	=> '~~ISS',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all/CURRENT/Y/DECAY/null-val/OBJECT_TYPE/PAYLOAD,UNKNOWN,OTHER/SATNAME/~~ISS",
	version => 2,
    },
;

is_resp qw{spacetrack iridium}, {
	args => [
	    basicspacedata	=> 'query',
	    class		=> 'satcat',
	    format		=> 'json',
	    predicates		=> 'NORAD_CAT_ID',
	    CURRENT		=> 'Y',
	    DECAY		=> 'null-val',
	    OBJECT_TYPE		=> 'PAYLOAD',
	    SATNAME		=> '~~IRIDIUM',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/predicates/NORAD_CAT_ID/CURRENT/Y/DECAY/null-val/OBJECT_TYPE/PAYLOAD/SATNAME/~~IRIDIUM",
	version => 2,
    },
;

is_resp qw{set with_name 0}, 'OK';


is_resp qw{spacetrack iridium}, {
	args => [
	    basicspacedata	=> 'query',
	    class		=> 'satcat',
	    format		=> 'json',
	    predicates		=> 'NORAD_CAT_ID',
	    CURRENT		=> 'Y',
	    DECAY		=> 'null-val',
	    OBJECT_TYPE		=> 'PAYLOAD',
	    SATNAME		=> '~~IRIDIUM',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/satcat/format/json/predicates/NORAD_CAT_ID/CURRENT/Y/DECAY/null-val/OBJECT_TYPE/PAYLOAD/SATNAME/~~IRIDIUM",
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
