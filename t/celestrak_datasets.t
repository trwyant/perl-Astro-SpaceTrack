use strict;
use warnings;

use Astro::SpaceTrack;
use LWP::UserAgent;
use Test;

my $ua = LWP::UserAgent->new ();
my $rslt = $ua->get ('http://celestrak.com/NORAD/elements/');
unless ($rslt->is_success) {
    print "1..0 # skip Celestrak inaccessable: " . $rslt->status_line;
    exit;
}

my %got = map {$_ => 1} parse_string ($rslt->content);

my $st = Astro::SpaceTrack->new (direct => 1);

(undef, my $names) = $st->names ('celestrak');
my %expect;
foreach (@$names) {
    $expect{$_->[1]} = {
	name => $_->[0],
	todo => 0,
    };
}
$expect{'1999-025'} = {
    name => 'Fengyun 1C Debris',
    todo => 1,		# Not provided as a fetchable data set.
};

my @todo;
{
    my $test;
    foreach my $key (sort keys %expect) {
	$test++;
####	$expect{$key}{todo} and push @todo, $test;
    }
}

plan (tests => scalar (keys %expect) + 1, # Extra test is for added links.
    todo => \@todo);

my $test;
foreach my $key (sort keys %expect) {
    $test++;
    print "# Test $test - $key ($expect{$key}{name})\n";
    ok (delete $got{$key});
}
$test++;
print "# Test $test - The above is all there is\n";
ok (!%got);

use HTML::Parser;

sub parse_string {
    my $psr = HTML::Parser->new (api_version => 3);
    my @data;
    $psr->handler (start => sub {
	    lc $_[1] eq 'a' && $_[2]{href} && $_[2]{href} =~ s/\.txt$//i
		and push @data, $_[2]{href};
	}, 'self,tagname,attr');
    $psr->parse (@_);
    @data;
}
