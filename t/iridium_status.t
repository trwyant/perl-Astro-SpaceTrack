#!/usr/local/bin/perl

use strict;
use warnings;

use Astro::SpaceTrack;
use Test;

my %known_inconsistent = map {$_ => 1} ();
#~14-Jan-2007 - McCants has 27450 (Iridium 97) in service,
#		24967 (Iridium 36) spare. No change Kelso.
# 21-Feb-2007 - Kelso has 27450 (Iridium 97) in service,
#		24967 (Iridium 36) tumbling. No change McCants.
# 06-Mar-2007 - McCants assumes Iridium 36 has failed.

my $st = Astro::SpaceTrack->new ();

$st->set (iridium_status_format => 'mccants');
my ($rslt, $data) = $st->iridium_status ();
my $skip_mc = "Mccants data unavailable" unless $rslt->is_success;
my $mccants_txt = $rslt->content unless $skip_mc;
my %mccants_st = map {$_->[0] => $_->[4]} @$data if ref $data eq 'ARRAY';

$st->set (iridium_status_format => 'kelso');
($rslt, $data) = $st->iridium_status ();
my $skip_ke = "Kelso data unavailable" unless $rslt->is_success;
my $kelso_txt = $rslt->content unless $skip_ke;
my %kelso_st = map {$_->[0] => $_->[4]} @$data if ref $data eq 'ARRAY';

my @todo;
{	#	Begin local symbol block
    my $test = 3;	# Skip the bulk compares
    foreach my $id (sort keys %mccants_st) {
	$known_inconsistent{$id} and push @todo, $test;
	$test++;
    }
}

plan tests => 2 + scalar keys %mccants_st, todo => \@todo;

my $test = 0;

foreach (["Mike McCants' Iridium status",
        $skip_mc, $mccants_txt,
	mccants => <<eod],
 24792   Iridium 8               Celestrak
 24793   Iridium 7               Celestrak
 24794   Iridium 6               Celestrak
 24795   Iridium 5               Celestrak
 24796   Iridium 4               Celestrak
 24836   Iridium 914    tum      Failed; was called Iridium 14
 24837   Iridium 12              Celestrak
 24839   Iridium 10              Celestrak
 24840   Iridium 13              Celestrak
 24841   Iridium 16     tum      Removed from operation about April 7, 2005
 24842   Iridium 911    tum      Failed; was called Iridium 11
 24869   Iridium 15              Celestrak
 24870   Iridium 17     tum?     Failed in August 2005?
 24871   Iridium 920    tum      Failed; was called Iridium 20
 24872   Iridium 18              Celestrak
 24873   Iridium 921    tum      Failed; was called Iridium 21
 24903   Iridium 26              Celestrak
 24904   Iridium 25              Celestrak
 24905   Iridium 46              Celestrak
 24906   Iridium 23              Celestrak
 24907   Iridium 22              Celestrak
 24925   Dummy mass 1   dum      Celestrak
 24926   Dummy mass 2   dum      Celestrak
 24944   Iridium 29              Celestrak
 24945   Iridium 32              Celestrak
 24946   Iridium 33              Celestrak
 24948   Iridium 28              Celestrak
 24949   Iridium 30              Celestrak
 24950   Iridium 31              Celestrak
 24965   Iridium 19              Celestrak
 24966   Iridium 35              Celestrak
 24967   Iridium 36     tum      Failed in January 2007
 24968   Iridium 37              Celestrak
 24969   Iridium 34              Celestrak
 25039   Iridium 43              Celestrak
 25040   Iridium 41              Celestrak
 25041   Iridium 40              Celestrak
 25042   Iridium 39              Celestrak
 25043   Iridium 38     tum      Failed in August 2003
 25077   Iridium 42              Celestrak
 25078   Iridium 44     tum      Failed
 25104   Iridium 45              Celestrak
 25105   Iridium 24     tum      Failed
 25106   Iridium 47              Celestrak
 25108   Iridium 49              Celestrak
 25169   Iridium 52              Celestrak
 25170   Iridium 56              Celestrak
 25171   Iridium 54              Celestrak
 25172   Iridium 50              Celestrak
 25173   Iridium 53              Celestrak
 25262   Iridium 51     ?        Spare
 25263   Iridium 61              Celestrak
 25272   Iridium 55              Celestrak
 25273   Iridium 57              Celestrak
 25274   Iridium 58              Celestrak
 25275   Iridium 59              Celestrak
 25276   Iridium 60              Celestrak
 25285   Iridium 62              Celestrak
 25286   Iridium 63              Celestrak
 25287   Iridium 64              Celestrak
 25288   Iridium 65              Celestrak
 25289   Iridium 66              Celestrak
 25290   Iridium 67              Celestrak
 25291   Iridium 68              Celestrak
 25319   Iridium 69     tum      Failed
 25320   Iridium 71     tum      Failed
 25342   Iridium 70              Celestrak
 25343   Iridium 72              Celestrak
 25344   Iridium 73     tum      Failed
 25345   Iridium 74     ?        Removed from operation about January 8, 2006
 25346   Iridium 75              Celestrak
 25431   Iridium 3               Celestrak
 25432   Iridium 76              Celestrak
 25467   Iridium 82              Celestrak
 25468   Iridium 81              Celestrak
 25469   Iridium 80              Celestrak
 25471   Iridium 77              Celestrak
 25527   Iridium 2      tum      Failed
 25528   Iridium 86              Celestrak
 25530   Iridium 84              Celestrak
 25531   Iridium 83              Celestrak
 25577   Iridium 20              was called Iridium 11
 25578   Iridium 11     ?        Spare   was called Iridium 20
 25777   Iridium 14     ?        Spare   was called Iridium 14A
 25778   Iridium 21              Replaced Iridium 74   was called Iridium 21A
 27372   Iridium 91     ?        Spare   was called Iridium 90
 27373   Iridium 90     ?        Moving between planes (Oct. 2005) was called I 91
 27374   Iridium 94     ?        Spare
 27375   Iridium 95     ?        Spare
 27376   Iridium 96     ?        Spare
 27450   Iridium 97              Moved next to Iridium 36 on Jan. 10, 2007
 27451   Iridium 98     ?        Moving between planes (June 2005)
eod
	["T. S. Kelso's Iridium list",
	$skip_ke, $kelso_txt,
	kelso => <<eod],
 24792   Iridium 8      [+]      
 24793   Iridium 7      [+]      
 24794   Iridium 6      [+]      
 24795   Iridium 5      [+]      
 24796   Iridium 4      [+]      
 24836   Iridium 914    [-]      Tumbling
 24837   Iridium 12     [+]      
 24839   Iridium 10     [+]      
 24840   Iridium 13     [+]      
 24841   Iridium 16     [-]      Tumbling
 24842   Iridium 911    [-]      Tumbling
 24869   Iridium 15     [+]      
 24870   Iridium 17     [-]      Tumbling
 24871   Iridium 920    [-]      Tumbling
 24872   Iridium 18     [+]      
 24873   Iridium 921    [-]      Tumbling
 24903   Iridium 26     [+]      
 24904   Iridium 25     [+]      
 24905   Iridium 46     [+]      
 24906   Iridium 23     [+]      
 24907   Iridium 22     [+]      
 24925   Dummy mass 1   [-]      Tumbling
 24926   Dummy mass 2   [-]      Tumbling
 24944   Iridium 29     [+]      
 24945   Iridium 32     [+]      
 24946   Iridium 33     [+]      
 24948   Iridium 28     [+]      
 24949   Iridium 30     [+]      
 24950   Iridium 31     [+]      
 24965   Iridium 19     [+]      
 24966   Iridium 35     [+]      
 24967   Iridium 36     [-]      Tumbling
 24968   Iridium 37     [+]      
 24969   Iridium 34     [+]      
 25039   Iridium 43     [+]      
 25040   Iridium 41     [+]      
 25041   Iridium 40     [+]      
 25042   Iridium 39     [+]      
 25043   Iridium 38     [-]      Tumbling
 25077   Iridium 42     [+]      
 25078   Iridium 44     [-]      Tumbling
 25104   Iridium 45     [+]      
 25105   Iridium 24     [-]      Tumbling
 25106   Iridium 47     [+]      
 25108   Iridium 49     [+]      
 25169   Iridium 52     [+]      
 25170   Iridium 56     [+]      
 25171   Iridium 54     [+]      
 25172   Iridium 50     [+]      
 25173   Iridium 53     [+]      
 25262   Iridium 51     [S]      Spare
 25263   Iridium 61     [+]      
 25272   Iridium 55     [+]      
 25273   Iridium 57     [+]      
 25274   Iridium 58     [+]      
 25275   Iridium 59     [+]      
 25276   Iridium 60     [+]      
 25285   Iridium 62     [+]      
 25286   Iridium 63     [+]      
 25287   Iridium 64     [+]      
 25288   Iridium 65     [+]      
 25289   Iridium 66     [+]      
 25290   Iridium 67     [+]      
 25291   Iridium 68     [+]      
 25319   Iridium 69     [-]      Tumbling
 25320   Iridium 71     [-]      Tumbling
 25342   Iridium 70     [+]      
 25343   Iridium 72     [+]      
 25344   Iridium 73     [-]      Tumbling
 25345   Iridium 74     [S]      Spare
 25346   Iridium 75     [+]      
 25431   Iridium 3      [+]      
 25432   Iridium 76     [+]      
 25467   Iridium 82     [+]      
 25468   Iridium 81     [+]      
 25469   Iridium 80     [+]      
 25471   Iridium 77     [+]      
 25527   Iridium 2      [-]      Tumbling
 25528   Iridium 86     [+]      
 25530   Iridium 84     [+]      
 25531   Iridium 83     [+]      
 25577   Iridium 20     [+]      
 25578   Iridium 11     [S]      Spare
 25777   Iridium 14     [S]      Spare
 25778   Iridium 21     [+]      
 27372   Iridium 91     [S]      Spare
 27373   Iridium 90     [S]      Spare
 27374   Iridium 94     [S]      Spare
 27375   Iridium 95     [S]      Spare
 27376   Iridium 96     [S]      Spare
 27450   Iridium 97     [+]      
 27451   Iridium 98     [S]      Spare
eod
	) {
    my ($what, $skip, $got, $file, $data) = @$_;
    $test++;
    $skip ||= 'No comparison data provided' unless $data;
    $got = 'skip' if $skip;
    1 while $got =~ s/\015\012/\n/gm;
    print <<eod;
#
# Test $test: Content of $what
eod
    skip ($skip, $got eq $data);
    unless ($skip || $got eq $data) {
	open (HANDLE, ">$file.expect");
	print HANDLE $data;
	open (HANDLE, ">$file.got");
	print HANDLE $got;
	warn <<eod;
#
# Expected and gotten information written to $file.expect and
# $file.got respectively.
#
eod
	}
    }

my $skip_cp = $skip_mc || $skip_ke;
foreach my $id (sort keys %mccants_st) {
    my $want = $mccants_st{$id};
    my $got = $skip_cp ? 'skipped' :
	exists $kelso_st{$id} ? $kelso_st{$id} : 'missing';
    $test++;
    print <<eod;
#
# Test $test - Status of $id
#     McCants: $want
#       Kelso: $got
eod
    if ($want =~ m/\D/ || $got =~ m/\D/) {
	skip ($skip_cp, $want eq $got);
    } else {
	skip ($skip_cp, $want == $got);
    }
}

