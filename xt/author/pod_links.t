package main;

use 5.008;

use strict;
use warnings;

use Test::More 0.88;	# Because of done_testing();

BEGIN {
    local $@ = undef;
    eval {
	require Test::Pod::LinkCheck::Lite;
	Test::Pod::LinkCheck::Lite->import( ':const' );
	1;
    } or plan skip_all => 'Unable to load Test::Pod::LinkCheck::Lite';
}

Test::Pod::LinkCheck::Lite->new(
    ignore_url		=> [
	qr< \A https?://spaceflight[.]nasa[.]gov (?: / | \z ) >smx,
	qw{
	    https://www.nasa.gov/station
	},
    ],
    prohibit_redirect	=> ALLOW_REDIRECT_TO_INDEX,
)->all_pod_files_ok(
    qw{ blib eg tools },
);

done_testing;

1;

# ex: set textwidth=72 :
