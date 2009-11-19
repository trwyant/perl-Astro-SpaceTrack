package main;

use strict;
use warnings;

BEGIN {

    eval {
	require Test::More;
	Test::More->VERSION( 0.40 );
	Test::More->import();
	1;
    } or do {
	print "1..0 # skip Test::More 0.40 or above required.\n";
	exit;
    };

    eval {
	require ExtUtils::Manifest;
	ExtUtils::Manifest->import( qw{ maniread } );
	1;
    } or do {
	print "1..0 # skip ExtUtils::Manifest required.\n";
	exit;
    };

}

my $manifest = maniread ();

my @check;
foreach ( sort keys %{ $manifest } ) {
    m/ \A bin \b /smx and next;
    m/ \A eg \b /smx and next;
    push @check, $_;
}

plan (tests => scalar @check);

foreach my $file (@check) {
    open (my $fh, '<', $file) or die "Unable to open $file: $!\n";
    local $_ = <$fh>;
    close $fh;
    my @stat = stat $file;
    my $executable = $stat[2] & oct( 111 ) || m/ \A \# ! .* perl /smx;
    ok( !$executable, "File $file is not executable" );
}

1;
