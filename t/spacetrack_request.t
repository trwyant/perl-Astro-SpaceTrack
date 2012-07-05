package main;

use strict;
use warnings;

use Test::More 0.96;

use Astro::SpaceTrack;

sub is_resp (@);
sub year();

my $loader = Astro::SpaceTrack->__get_yaml_loader() or do {
    plan skip_all => 'YAML required to check Space Track requests.';
    exit;
};

my $st = Astro::SpaceTrack->new(
    debug_url => 'dump-request:',
    space_track_version	=> 1,
);

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
	method => 'post',
	url => 'https://www.space-track.org/perl/id_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/id_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/id_query.pl',
    },
;

###############

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
	method => 'post',
	url => 'https://www.space-track.org/perl/id_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/id_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/id_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/id_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/id_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/id_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/id_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/launch_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/launch_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/launch_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/launch_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/launch_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/launch_query.pl',
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
	    method => 'post',
	    url => 'https://www.space-track.org/perl/launch_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/launch_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/launch_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/launch_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/launch_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/launch_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/launch_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/launch_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/launch_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/launch_query.pl',
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
	    method => 'post',
	    url => 'https://www.space-track.org/perl/launch_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/launch_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/name_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/name_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/name_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/name_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/name_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/name_query.pl',
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
	    method => 'post',
	    url => 'https://www.space-track.org/perl/name_query.pl',
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
	method => 'post',
	url => 'https://www.space-track.org/perl/name_query.pl',
    },
;

is_resp qw{spacetrack iridium}, {
	args => {
	    ID => 10,
	},
	method => 'get',
	url => 'https://www.space-track.org/perl/dl.pl',
    },
;

is_resp qw{set with_name 0}, 'OK';

is_resp qw{spacetrack iridium}, {
	args => {
	    ID => 9,
	},
	method => 'get',
	url => 'https://www.space-track.org/perl/dl.pl',
    },
;

is_resp qw{spacetrack 10}, {
	args => {
	    ID => 10,
	},
	method => 'get',
	url => 'https://www.space-track.org/perl/dl.pl',
    },
;

################################

$st->set( space_track_version => 2 );

is_resp qw{retrieve 25544}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle',
	    NORAD_CAT_ID => 25544,
	    format	=> 'tle',
	    limit	=> 1,
	    orderby	=> 'NORAD_CAT_ID asc',
	],
	method => 'get_rest',
	url => 'https://beta.space-track.org',
    },
;

is_resp qw{retrieve -sort catnum 25544}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle',
	    NORAD_CAT_ID => 25544,
	    format	=> 'tle',
	    limit	=> 1,
	    orderby	=> 'NORAD_CAT_ID asc',
	],
	method => 'get_rest',
	url => 'https://beta.space-track.org',
    },
;

is_resp qw{retrieve -sort epoch 25544}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle',
	    NORAD_CAT_ID => 25544,
	    format	=> 'tle',
	    limit	=> 1,
	    orderby	=> 'EPOCH asc',
	],
	method => 'get_rest',
	url => 'https://beta.space-track.org',
    },
;

done_testing;

sub is_resp (@) {	## no critic (RequireArgUnpacking)
    my ($method, @args) = @_;
    my $query = pop @args;
    my $name = "\$st->$method(" . join( ', ', map {"'$_'"} @args ) . ')';
    my $resp = $st->$method( @args );
    my ($got);

    if ( $resp && $resp->isa('HTTP::Response') ) {
	if ( $resp->is_success() ) {
	    $got = $resp->content();
	    $got =~ m/ \A --- /smx
		and $got = $loader->( $got );
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
