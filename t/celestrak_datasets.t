package main;

use strict;
use warnings;

use Astro::SpaceTrack;
use LWP::UserAgent;
use Test;

unless ($ENV{DEVELOPER_TEST}) {
    print "1..0 # skip Environment variable DEVELOPER_TEST not set.\n";
    exit;
}

my $ua = LWP::UserAgent->new ();
my $rslt = $ua->get ('http://celestrak.com/NORAD/elements/');
unless ($rslt->is_success) {
    print "1..0 # skip Celestrak inaccessable: " . $rslt->status_line;
    exit;
}

my %got = parse_string ($rslt->content);

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
    name => 'Fengyun 1C debris',
    note => 'Not actually provided as a fetchable data set.',
    todo => 0,
};
$expect{'cosmos-2251-debris'} = {
    name => 'Cosmos 2251 debris',
    note => 'Not actually provided as a fetchable data set.',
    todo => 0,
};
$expect{'iridium-33-debris'} = {
    name => 'Iridium 33 debris',
    note => 'Not actually provided as a fetchable data set.',
    todo => 0,
};

=begin comment

# Removed October 23, 2008

$expect{'usa-193-debris'} = {
    name => 'USA 193 Debris',
    note => 'Not actually provided as a fetchable data set.',
    todo => 0,
};

=end comment

=cut

if ($expect{sts}) {
    $expect{sts}{note} = 'Only available when a mission is in progress.';
    $expect{sts}{todo} = 1;
    $expect{sts}{ignore} = 1;	# What it says. Trumps todo.
}

my @todo;
my $test = 1;	# Allow extra test for added links.
{
    foreach my $key (sort keys %expect) {
	if ($expect{$key}{ignore}) {
	} else {
	    $test++;
	    $expect{$key}{todo} and push @todo, $test;
	}
    }
}

plan (tests => $test, todo => \@todo);

$test = 0;
foreach my $key (sort keys %expect) {
    if ($expect{$key}{ignore}) {
	warn "\n# Ignored - $key (@{[($got{$key} ||
		$expect{$key})->{name}]})\n";
	$expect{$key}{note} and warn "#     $expect{$key}{note}\n";
	if (my $item = delete $got{$key}) {
	    warn "#     present\n";
	} else {
	    warn "#     not present\n";
	}
    } else {
	$test++;
	print "# Test $test - $key ($expect{$key}{name})\n";
	$expect{$key}{note} and print "#     $expect{$key}{note}\n";
	ok (delete $got{$key});
    }
}
$test++;
print "# Test $test - The above is all there is\n";
ok (!%got);
if (%got) {
    print "# The following have been added:\n";
    foreach (sort keys %got) {
	print "#     $_ => '$got{$_}{name}'\n";
    }
}

use HTML::Parser;

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
