#!/usr/local/bin/perl

use strict;
use warnings;

use Astro::SpaceTrack;
use Test;

my $st = Astro::SpaceTrack->new ();

my $skip;

$st->set (iridium_status_format => 'mccants');
my ($rslt, $data) = $st->iridium_status ();
$skip ||= "Mccants data unavailable" unless $rslt->is_success;
my %mccants = map {$_->[0] => $_->[4]} @$data if ref $data eq 'ARRAY';

$st->set (iridium_status_format => 'kelso');
($rslt, $data) = $st->iridium_status ();
$skip ||= "Kelso data unavailable" unless $rslt->is_success;
my %kelso = map {$_->[0] => $_->[4]} @$data if ref $data eq 'ARRAY';

$skip and $mccants{skip} = 'skip';

plan tests => scalar keys %mccants;

my $test = 0;
foreach my $id (sort keys %mccants) {
    my $want = $mccants{$id};
    my $got = $skip ? 'skipped' : exists $kelso{$id} ? $kelso{$id} : 'missing';
    $test++;
    print <<eod;
#
# Test $test - Status of $id
#     McCants: $want
#       Kelso: $got
eod
    if ($want =~ m/\D/ || $got =~ m/\D/) {
	skip ($skip, $want eq $got);
    } else {
	skip ($skip, $want == $got);
    }
}

