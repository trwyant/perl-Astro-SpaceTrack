package main;

use strict;
use warnings;

use Astro::SpaceTrack;
use HTML::Parser;
use LWP::UserAgent;
use Test::More 0.96;

my $ua = LWP::UserAgent->new ();
my $rslt = $ua->get ('http://celestrak.com/NORAD/elements/');
unless ($rslt->is_success) {
    plan skip_all => 'Celestrak inaccessable: ' . $rslt->status_line;
    exit;	# Defensive code.
}

my %got = parse_string ($rslt->content);

my $st = Astro::SpaceTrack->new (direct => 1);

(undef, my $names) = $st->names ('celestrak');
my %expect;
foreach (@$names) {
    $expect{$_->[1]} = {
	name => $_->[0],
	ignore => 0,
    };
}

$expect{'1999-025'} = {
    name => 'Fengyun 1C debris',
    note => 'Not actually provided as a fetchable data set.',
    ignore => 1,
};
$expect{'cosmos-2251-debris'} = {
    name => 'Cosmos 2251 debris',
    note => 'Not actually provided as a fetchable data set.',
    ignore => 1,
};
$expect{'iridium-33-debris'} = {
    name => 'Iridium 33 debris',
    note => 'Not actually provided as a fetchable data set.',
    ignore => 1,
};
$expect{'2012-044'} = {
    name => 'BREEZE-M R/B Breakup (2012-044C)',
    note => 'Not actually provided as a fetchable data set.',
    ignore => 1,
};

=begin comment

# Removed October 23, 2008

$expect{'usa-193-debris'} = {
    name => 'USA 193 Debris',
    note => 'Not actually provided as a fetchable data set.',
    ignore => 1,
};

=end comment

=cut

if ($expect{sts}) {
    $expect{sts}{note} = 'Only available when a mission is in progress.';
    $expect{sts}{ignore} = 1;	# What it says.
}

foreach my $key (sort keys %expect) {
    if ($expect{$key}{ignore}) {
	my $presence = delete $got{$key} ? 'present' : 'not present';
	note "Ignored - $key (@{[($got{$key} ||
		$expect{$key})->{name}]}): $presence";
	$expect{$key}{note} and note( "    $expect{$key}{note}" );
    } else {
	ok delete $got{$key}, $expect{$key}{name};
	$expect{$key}{note} and note "    $expect{$key}{note}";
    }
}

ok ( !%got, 'The above is all there is' ) or do {
    diag( 'The following have been added:' );
    foreach (sort keys %got) {
	diag( "    $_ => '$got{$_}{name}'" );
    }
};

done_testing;

sub parse_string {
    my $string = shift;
    my $psr = HTML::Parser->new (api_version => 3);
    $psr->case_sensitive (0);
    my %data;
    my $collect;
    $psr->handler (start => sub {
	    if ($_[1] eq 'a' && $_[2]{href} && $_[2]{href} =~ s/\.txt$//i) {
		$data{$_[2]{href}} = $collect = {
		    name => undef,
		};
	    }
	}, 'self,tagname,attr');
    $psr->handler (text => sub {
	    if ($collect) {
		if (defined $collect->{name}) {
		    $collect->{name} .= ' ' . $_[1];
		} else {
		    $collect->{name} = $_[1];
		}
	    }
	}, 'self,text');
    $psr->handler (end => sub {
	    $_[1] eq 'a' and $collect = undef;
	}, 'self,tagname');
    $psr->parse ($string);
    return %data;
}

1;

# ex: set textwidth=72 :
