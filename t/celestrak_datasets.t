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
    name => 'Fengyun 1C Debris',
    note => 'Not actually provided as a fetchable data set.',
    todo => 0,
};
if ($expect{sts}) {
    $expect{sts}{note} = 'Only available when a mission is in progress.';
    $expect{sts}{todo} = 1;
}

my @todo;
{
    my $test;
    foreach my $key (sort keys %expect) {
	$test++;
	$expect{$key}{todo} and push @todo, $test;
    }
}

plan (tests => scalar (keys %expect) + 1, # Extra test is for added links.
    todo => \@todo);

my $test;
foreach my $key (sort keys %expect) {
    $test++;
    print "# Test $test - $key ($expect{$key}{name})\n";
    $expect{$key}{note} and print "#     $expect{$key}{note}\n";
    ok (delete $got{$key});
}
$test++;
print "# Test $test - The above is all there is\n";
ok (!%got);
if (%got) {
    print "# The following have been added:\n";
    foreach (sort keys %got) {
	print "     $_ => '$got{$_}{name}'\n";
    }
}

use HTML::Parser;

sub parse_string {
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
    $psr->parse (@_);
    %data;
}