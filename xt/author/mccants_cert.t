package main;

use 5.006002;

use strict;
use warnings;

use Test::More 0.88;	# Because of done_testing();

use LWP::UserAgent;

note <<'EOD';
The point of this test is to let me know when Perl starts to recognize
the cert returned by Mike McCants' web site, so I can change the default
for the validate_hostname attribute back to true.
EOD

my $ua = LWP::UserAgent->new(
    ssl_opts	=> { verify_hostname => 1 },
);

my $resp = $ua->get(
    'http://www.prismnet.com/~mmccants/tles/iridium.html',
);

ok got_expected_response( $resp ),
    q{Perl does not recognize Mike's certificate}
    or diag $resp->status_line(), <<'EOD';
You might be able to change the default for validate_hostname
back to true.
EOD

done_testing;

sub got_expected_response {
    my ( $resp ) = @_;
    $resp->is_success()
	and return 0;
    500 == $resp->code()
	or return 0;
    return $resp->status_line() =~ m/certificate verify failed/sm;
}

1;

# ex: set textwidth=72 :
