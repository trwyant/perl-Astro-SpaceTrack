package main;

use 5.006002;

use strict;
use warnings;

use Astro::SpaceTrack;
use Test::More 0.88;	# Because of done_testing();

my $st = Astro::SpaceTrack->new(
    space_track_version	=> 2,
);

defined $st->getv( 'username' )
    and defined $st->getv( 'password' )
    or plan skip_all => 'Environment variable SPACETRACK_USER not set';

note <<'EOD';
The purpose of this test is to alert me when ranges can be used in lists
of OIDs in the Space Track REST interface.
EOD

{
    my @oids = qw{ 25778 27372-27376 27450 };
    local $ENV{SPACETRACK_REST_RANGE_OPERATOR} = 1;
    my $rslt = $st->retrieve( { json => 1 }, @oids );

    ok $rslt->is_success(), "Retrieve OIDs @oids"
	or diag $rslt->status_line();

    if ( $rslt->is_success() ) {
	# Method _get_json_object() is unsupported and undocumented.
	my $json = $st->_get_json_object();
	my $data = $json->decode( $rslt->content() );
	# Method _expand_oid_list() is unsupported and undocumented.
	my @expect = $st->_expand_oid_list( @oids );

	cmp_ok scalar @{ $data }, '!=', scalar @expect,
	    "Did not retrieve @{[ scalar @expect ]} OIDs"
		or diag <<'EOD';
We got the correct number of OIDs. You can consider using ranges for
REST queries.
EOD
    }
}

done_testing;

1;

# ex: set textwidth=72 :
