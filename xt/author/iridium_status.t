package main;

use strict;
use warnings;

use Astro::SpaceTrack;
use Test;

# The following hash is used to compute the todo list. The keys are
# the OIDs for the Iridium satellites. The value for each key is a hash
# containing the names of inconsistent data sources and a true value for
# each inconsistent name. If all three sources are mutually inconsistent,
# only two source names need be given.

my %known_inconsistent = (
###    27375 => {mccants => 1},	# Kelso & Sladen: operational;
    				# McCants: spare.
###    24946 => {kelso => 1},	# Kelso: operational; others: tumbling
###    27372 => {mccants => 1},	# Kelso & Sladen: operational;
    				# McCants: spare.
    24906 => { kelso => 1 },	# Kelso: spare; others: operational
###    25578 => { kelso => 1 },	# Kelso: operational; others: spare
###    24903 => { kelso => 1 },	# Kelso: in service; others: failed.
);
#~14-Jan-2007 - McCants has 27450 (Iridium 97) in service,
#		24967 (Iridium 36) spare. No change Kelso.
# 21-Feb-2007 - Kelso has 27450 (Iridium 97) in service,
#		24967 (Iridium 36) tumbling. No change McCants.
# 06-Mar-2007 - McCants assumes Iridium 36 has failed.
# 07-Aug-2008 - McCants has 24948 (Iridium 28) with possible control
#		issues about July 19 2008, with 27375 (Iridium 95) moved
#		about 14 seconds behind it. No change Kelso.
# 23-Dec-2008 - McCants has 24948 (Iridium 28) uncontrolled, with 27375
# 		(Iridium 98) replacing it.
# 10-Feb-2009 - Iridium 33 (24946) hit Cosmos 2251 (22675).
#               11-Feb-2009 - Sladen noted probably nonfunctional, though
#                   he still carries it in his operational grid.
#               12-Feb-2009 - McCants noted tumbling.
#               18-Feb-2009 - Kelso noted tumbling.
#               09-Mar-2009 - Sladen & Kelso note Iridium 91 in service.
#               22-May-2009 - Mike McCants notes Iridium 91 in service.
# 03-Nov-2010 - Apparant failure of Iridium 23 (24906); replaced by Iridium 11
#               (25578).
#               13-Nov-2010 - McCants & Sladen noted.
#               15-Dec-2010 - Kelso noted, but listed 24906 as spare.
# 29-Aug-2011 - McCants notes Iridium 23 (24906) as partial failure(?),
#               but stable. Sladen simply notes it as not failed.
#               McCants and Sladen note Iridium 26 (24903) as apparently
#               failed. The date may be off by one, as I was unable to
#               run the tests on the 28th due to a power outage caused
#               by hurricane Irene.
#               30-Aug-2011 Kelso marks Iriidum 26 tumbling

my %status_map = (
    &Astro::SpaceTrack::BODY_STATUS_IS_OPERATIONAL => 'Operational',
    &Astro::SpaceTrack::BODY_STATUS_IS_SPARE => 'Spare',
    &Astro::SpaceTrack::BODY_STATUS_IS_TUMBLING => 'Tumbling',
);

my $st = Astro::SpaceTrack->new ();

my @sources = qw{kelso mccants sladen};

my (%skip, %text, %status);
my %name;
foreach my $src (@sources) {
    my ($rslt, $data) = $st->iridium_status($src);
    if ($rslt->is_success) {
	$text{$src} = $rslt->content;
	my %sts;
	ref $data eq 'ARRAY'
	    and %sts = map {$_->[0] => $_->[4]} @$data;
	$status{$src} = \%sts;
	foreach (@$data) {
	    $name{$_->[0]} ||= $_->[1];
	}
    } else {
	$skip{$src} = ucfirst($src) . ' data unavailable';
    }
}

my @pairs;
foreach my $inx (0 .. (scalar @sources - 2)) {
    foreach my $jnx ($inx + 1 .. (scalar @sources - 1)) {
	push @pairs, [$sources[$inx], $sources[$jnx]];
    }
}

my @todo;
my @keys;
{	#	Begin local symbol block
    my %ky;
    foreach my $src (keys %status) {
	foreach my $oid (keys %{$status{$src}}) {
	    $ky{$oid}++;
	}
    }
    @keys = sort {$a <=> $b} keys %ky;
    my $test = scalar @sources + 1;	# Skip the bulk compares
    foreach my $id (@keys) {
	my $ki = $known_inconsistent{$id};
	foreach my $pr (@pairs) {
	    ($ki->{$pr->[0]} || $ki->{$pr->[1]})
		and push @todo, $test;
	    $test++;
	}
    }
}

plan tests => scalar @sources + scalar @keys * scalar @pairs, todo => \@todo;

my $test = 0;

foreach (["Mike McCants' Iridium status",
	mccants => <<'EOD'],
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
 24870   Iridium 17     tum      Failed in August 2005
 24871   Iridium 920    tum      Failed; was called Iridium 20
 24872   Iridium 18              Celestrak
 24873   Iridium 921    tum      Failed; was called Iridium 21
 24903   Iridium 26     unc      Apparently failed in August 2011.
 24904   Iridium 25              Celestrak
 24905   Iridium 46              Celestrak
 24906   Iridium 23              Partial failure? in November 2010
 24907   Iridium 22              Celestrak
 24925   Dummy mass 1   dum      Celestrak
 24926   Dummy mass 2   dum      Celestrak
 24944   Iridium 29              Celestrak
 24945   Iridium 32              Celestrak
 24946   Iridium 33     tum      Destroyed by a collision on Feb. 10, 2009
 24948   Iridium 28     unc      Assumed failed about July 19, 2008
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
 25578   Iridium 11              was called Iridium 20
 25777   Iridium 14     ?        Spare   was called Iridium 14A
 25778   Iridium 21              Replaced Iridium 74   was called Iridium 21A
 27372   Iridium 91              Replaced Iridium 33 about Mar. 2, 2009   was called Iridium 90
 27373   Iridium 90     ?        Spare (new plane Jan. 2008)   was called Iridium 91
 27374   Iridium 94     ?        Spare
 27375   Iridium 95              Replaced Iridium 28 about July 26, 2008
 27376   Iridium 96     ?        Spare
 27450   Iridium 97              Replaced Iridium 36 on Jan. 10, 2007
 27451   Iridium 98     ?        Spare (new plane May 2007)
EOD
	["T. S. Kelso's Iridium list",
	kelso => <<'EOD'],
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
 24903   Iridium 26     [-]      Tumbling
 24904   Iridium 25     [+]      
 24905   Iridium 46     [+]      
 24906   Iridium 23     [S]      Spare
 24907   Iridium 22     [+]      
 24925   Dummy mass 1   [-]      Tumbling
 24926   Dummy mass 2   [-]      Tumbling
 24944   Iridium 29     [+]      
 24945   Iridium 32     [+]      
 24946   Iridium 33     [-]      Tumbling
 24948   Iridium 28     [-]      Tumbling
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
 25578   Iridium 11     [+]      
 25777   Iridium 14     [S]      Spare
 25778   Iridium 21     [+]      
 27372   Iridium 91     [+]      
 27373   Iridium 90     [S]      Spare
 27374   Iridium 94     [S]      Spare
 27375   Iridium 95     [+]      
 27376   Iridium 96     [S]      Spare
 27450   Iridium 97     [+]      
 27451   Iridium 98     [S]      Spare
EOD
	["Rod Sladen's Iridium Constellation Status",
	sladen => <<'EOD'],
 24792   Iridium 8      [+]      Plane 4
 24793   Iridium 7      [+]      Plane 4
 24794   Iridium 6      [+]      Plane 4
 24795   Iridium 5      [+]      Plane 4
 24796   Iridium 4      [+]      Plane 4
 24836   Iridium 914    [-]      Plane 5
 24837   Iridium 12     [+]      Plane 5
 24839   Iridium 10     [+]      Plane 5
 24840   Iridium 13     [+]      Plane 5
 24841   Iridium 16     [-]      Plane 5
 24842   Iridium 911    [-]      Plane 5
 24869   Iridium 15     [+]      Plane 6
 24870   Iridium 17     [-]      Plane 6 - Failed on station?
 24871   Iridium 920    [-]      Plane 6
 24872   Iridium 18     [+]      Plane 6
 24873   Iridium 921    [-]      Plane 6
 24903   Iridium 26     [-]      Plane 2 - Failed on station?
 24904   Iridium 25     [+]      Plane 2
 24905   Iridium 46     [+]      Plane 2
 24906   Iridium 23     [+]      Plane 2
 24907   Iridium 22     [+]      Plane 2
 24925   Dummy mass 1   [-]      Dummy
 24926   Dummy mass 2   [-]      Dummy
 24944   Iridium 29     [+]      Plane 3
 24945   Iridium 32     [+]      Plane 3
 24946   Iridium 33     [-]      Plane 3 - Failed on station?
 24948   Iridium 28     [-]      Plane 3 - Failed on station?
 24949   Iridium 30     [+]      Plane 3
 24950   Iridium 31     [+]      Plane 3
 24965   Iridium 19     [+]      Plane 4
 24966   Iridium 35     [+]      Plane 4
 24967   Iridium 36     [-]      Plane 4
 24968   Iridium 37     [+]      Plane 4
 24969   Iridium 34     [+]      Plane 4
 25039   Iridium 43     [+]      Plane 6
 25040   Iridium 41     [+]      Plane 6
 25041   Iridium 40     [+]      Plane 6
 25042   Iridium 39     [+]      Plane 6
 25043   Iridium 38     [-]      Plane 6
 25077   Iridium 42     [+]      Plane 6
 25078   Iridium 44     [-]      Plane 6
 25104   Iridium 45     [+]      Plane 2
 25105   Iridium 24     [-]      Plane 2
 25106   Iridium 47     [+]      Plane 2
 25108   Iridium 49     [+]      Plane 2
 25169   Iridium 52     [+]      Plane 5
 25170   Iridium 56     [+]      Plane 5
 25171   Iridium 54     [+]      Plane 5
 25172   Iridium 50     [+]      Plane 5
 25173   Iridium 53     [+]      Plane 5
 25262   Iridium 51     [S]      Plane 4
 25263   Iridium 61     [+]      Plane 4
 25272   Iridium 55     [+]      Plane 3
 25273   Iridium 57     [+]      Plane 3
 25274   Iridium 58     [+]      Plane 3
 25275   Iridium 59     [+]      Plane 3
 25276   Iridium 60     [+]      Plane 3
 25285   Iridium 62     [+]      Plane 1
 25286   Iridium 63     [+]      Plane 1
 25287   Iridium 64     [+]      Plane 1
 25288   Iridium 65     [+]      Plane 1
 25289   Iridium 66     [+]      Plane 1
 25290   Iridium 67     [+]      Plane 1
 25291   Iridium 68     [+]      Plane 1
 25319   Iridium 69     [-]      Plane 2
 25320   Iridium 71     [-]      Plane 2
 25342   Iridium 70     [+]      Plane 1
 25343   Iridium 72     [+]      Plane 1
 25344   Iridium 73     [-]      Plane 1
 25345   Iridium 74     [S]      Plane 1
 25346   Iridium 75     [+]      Plane 1
 25431   Iridium 3      [+]      Plane 2
 25432   Iridium 76     [+]      Plane 2
 25467   Iridium 82     [+]      Plane 6
 25468   Iridium 81     [+]      Plane 6
 25469   Iridium 80     [+]      Plane 6
 25471   Iridium 77     [+]      Plane 6
 25527   Iridium 2      [-]      Plane 5
 25528   Iridium 86     [+]      Plane 5
 25530   Iridium 84     [+]      Plane 5
 25531   Iridium 83     [+]      Plane 5
 25577   Iridium 20     [+]      Plane 2
 25578   Iridium 11     [+]      Plane 2
 25777   Iridium 14     [S]      Plane 1
 25778   Iridium 21     [+]      Plane 1
 27372   Iridium 91     [+]      Plane 3
 27373   Iridium 90     [S]      Plane 5
 27374   Iridium 94     [S]      Plane 3
 27375   Iridium 95     [+]      Plane 3
 27376   Iridium 96     [S]      Plane 3
 27450   Iridium 97     [+]      Plane 4
 27451   Iridium 98     [S]      Plane 6
EOD
	) {
#####    my ($what, $skip, $got, $file, $data) = @$_;
    my ($what, $file, $data) = @$_;
    $test++;
    $data ||= '';
    my $got = $skip{$file} ? 'skip' : $text{$file};
    1 while $got =~ s/\015\012/\n/gm;
    print <<eod;
#
# Test $test: Content of $what
eod
    skip ($skip{$file}, $got eq $data);
    unless ($skip{$file} || $got eq $data) {
	my $fn = "$file.expect";
	open (my $fh, '>', $fn) or die "Unable to open $fn: $!";
	print $fh $data;
	close $fh;
	$fn = "$file.got";
	open ($fh, '>', $fn) or die "Unable to open $fn: $!";
	print $fh $got;
	close $fh;
	warn <<eod;
#
# Expected and gotten information written to $file.expect and
# $file.got respectively.
#
eod
    }
}

foreach my $id (@keys) {
    foreach my $pr (@pairs) {
	my @data;
	foreach my $src (@$pr) {
	    push @data,
		$skip{$src} ? ['skipped'] :
		exists $status{$src}{$id} ?
		    [$status{$src}{$id}, $status_map{$status{$src}{$id}}] :
		    ['missing'];
	}
	$test++;
	print <<eod;
#
# Test $test - Status of $id ($name{$id})
eod
	foreach my $inx (0, 1) {
	    printf "#%12s: %s\n", $pr->[$inx], join ' - ', @{$data[$inx]};
	}
	@data = map {$_->[0]} @data;
	if ($data[0] =~ m/\D/ || $data[1] =~ m/\D/) {
	    skip ($skip{$pr->[0]} || $skip{$pr->[1]}, $data[0] eq $data[1]);
	} else {
	    skip ($skip{$pr->[0]} || $skip{$pr->[1]}, $data[0] == $data[1]);
	}
    }
}

1;
