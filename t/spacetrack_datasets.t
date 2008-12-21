use strict;
use warnings;

use Astro::SpaceTrack;
use LWP::UserAgent;
use Test;

unless ($ENV{DEVELOPER_TEST}) {
    print "1..0 # skip Environment variable DEVELOPER_TEST not set.\n";
    exit;
}

unless ($ENV{SPACETRACK_USER}) {
    print "1..0 # skip Environment variable SPACETRACK_USER not defined.\n";
    exit;
}

my $st = Astro::SpaceTrack->new ();
my $rslt = $st->_get ('perl/bulk_files.pl');
unless ($rslt->is_success) {
    print "1..0 # skip Spacetrack inaccessable: " . $rslt->status_line;
    exit;
}

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

my @todo;
my $test = 1;	# Allow extra test for added links.
{
    foreach my $key (sort keys %expect) {
	if ($expect{$key}{ignore}) {
	} else {
	    $test++;
	    $expect{$key}{todo} and push @todo, $test;
	    if ($expect{$key}{number}) {
		$test++;
		$expect{$key}{todo} and push @todo, $test;
	    }
	}
    }
}

plan (tests => $test, todo => \@todo);

$test = 0;
foreach my $key (sort keys %expect) {
    my $number = $expect{$key}{number};
    if ($expect{$key}{ignore}) {
	if ($expect{$key}{silent}) {
	    delete $got{$number};
	} else {
	    warn "\n# Ignored - $key (@{[($got{$number} ||
		    $expect{$key})->{name}]})\n";
	    $expect{$key}{note} and warn "#     $expect{$key}{note}\n";
	    if (my $item = delete $got{$number}) {
		warn "#     present\n";
	    } else {
		warn "#     not present\n";
	    }
	}
    } else {
	$test++;
	print "# Test $test - $key ($expect{$key}{name})\n";
	$expect{$key}{note} and print "#     $expect{$key}{note}\n";
	ok (delete $got{$number});
	if ($number++) {
	    ok (delete $got{$number});
	}
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
    $psr->parse (@_);
    %data;
}
