package main;

use 5.006002;

use strict;
use warnings;

use Astro::SpaceTrack;
use Test::More 0.96;	# For subtest

use lib qw{ inc };
use My::Module::Test;

my $skip;
$skip = site_check 'mike.mccants'
    and plan skip_all => $skip;

my $st = Astro::SpaceTrack->new();

is_success $st, qw{ mccants classified }, 'Get classified elements';

is $st->content_type(), 'orbit', "Content type is 'orbit'";

is $st->content_source(), 'mccants', "Content source is 'mccants'";

is_success $st, qw{ mccants integrated }, 'Get integrated elements';

is $st->content_type(), 'orbit', "Content type is 'orbit'";

is $st->content_source(), 'mccants', "Content source is 'mccants'";

my $temp = File::Temp->new();

# In order to try to force a cache miss, we set the access and
# modification time of the file to the epoch.
my @opt = eval { utime 0, 0, $temp->filename() } ?
    ( '-file' => $temp->filename() ) :
    ();

is_success $st, 'mccants', @opt, 'mcnames',
    'Get molczan-style magnitudes';

is $st->content_type(), 'molczan', "Content type is 'molczan'";

is $st->content_source(), 'mccants', "Content source is 'mccants'";

ok ! $st->cache_hit(), 'Content did not come from cache';

if ( @opt ) {
    my $want = most_recent_http_response()->content();
    is_success $st, qw{ mccants -file }, $temp->filename(), 'mcnames',
	'Get molczan-style magnitudes from cache';

    ok $st->cache_hit(), 'This time content came from cache';
    is most_recent_http_response()->content(), $want,
	'We got the same result from the cache as from on line';
} else {
    note 'Cache test skipped';
}

is_success $st, qw{ mccants quicksat }, 'Get quicksat-style magnitudes';

is $st->content_type(), 'quicksat', "Content type is 'quicksat'";

is $st->content_source(), 'mccants', "Content source is 'mccants'";

is_success $st, qw{ mccants rcs }, 'Get McCants-format RCS data';

is $st->content_type(), 'rcs.mccants', "Content type is 'rcs.mccants'";

is $st->content_source(), 'mccants', "Content source is 'mccants'";

is_success $st, qw{ mccants vsnames }, 'Get molczan-style magnitudes for visual satellites';

is $st->content_type(), 'molczan', "Content type is 'molczan'";

is $st->content_source(), 'mccants', "Content source is 'mccants'";

done_testing;

1;

# ex: set textwidth=72 :
