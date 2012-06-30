package main;

use strict;
use warnings;

use Astro::SpaceTrack;
use HTML::Parser;
use LWP::UserAgent;
use Test::More 0.96;	# Because of subtest()

$ENV{SPACETRACK_USER}
    or plan skip_all => 'Environment variable SPACETRACK_USER not defined';

my $st = Astro::SpaceTrack->new (
    space_track_version	=> 1,	# v2 does not support this. Yet.
);
my $rslt = $st->_get ('perl/bulk_files.pl');
$rslt->is_success()
    or plan skip_all => 'Space Track inaccessable: ' . $rslt->status_line();

my %got = parse_string ($rslt->content);

my %expect;
{
    my $rslt = $st->names ('spacetrack');
    foreach (split '\n', $rslt->content ()) {
	my ($code, $name) = split '\s*:\s*', $_, 2;
	$code =~ s/\s+\((\d+)\)$//;
	my $number = $1;
	$expect{$code} = {
	    number => $number,
	    name => $name,
	    todo => 0,
	};
    }
}

$expect{satellite_situation_report} = {
    name => 'Satellite Situation Report',
    number => 25,
    note => 'Not fetchable via Astro::SpaceTrack',
    todo => 0,
    ignore => 1,	# What it says. Trumps todo.
    silent => 1,	# Ignore silently.
};

=begin comment

$expect{'1999-025'} = {
    name => 'Fengyun 1C Debris',
    note => 'Not actually provided as a fetchable data set.',
    todo => 0,
};
if ($expect{sts}) {
    $expect{sts}{note} = 'Only available when a mission is in progress.';
    $expect{sts}{todo} = 1;
    $expect{sts}{ignore} = 1;	# What it says. Trumps todo.
}

=end comment

=cut

foreach my $key (sort keys %expect) {
    my $number = $expect{$key}{number};
    if ( $expect{$key}{ignore} ) {
	if ( $expect{$key}{silent} ) {
	    delete $got{$number};
	} else {
	    my $info = $got{$number} || $expect{$key};
	    note "\nIgnored - $key ($info->{name})";
	    $expect{$key}{note}
		and note "    $expect{$key}{note}";
	    note '    ' . ( delete $got{$number} ? 'present' : 'not present' );
	}
    } else {
	ok delete $got{$number}, "$key ($expect{$key}{name})";
	$expect{$key}{note}
	    and note "    $expect{$key}{note}";
	if ( $number++ ) {
	    ok delete $got{$number}, "$key ($expect{$key}{name}) with names";
	}
    }
}

done_testing;

sub parse_string {
    my $string = shift;
    my $psr = HTML::Parser->new (api_version => 3);
    $psr->case_sensitive (0);
    my %data;
    my $collect;
    $psr->handler (start => sub {
	    if ($_[1] eq 'a' && $_[2]{href} &&
		$_[2]{href} =~ m/dl\.pl\?ID=(\d+)$/ && $1 < 100) {
##		$data{$_[2]{href}} = $collect = {
		$data{$1} = $collect = {
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
