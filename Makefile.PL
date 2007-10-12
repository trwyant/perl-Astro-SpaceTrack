use strict;
use warnings;

use Config;
use ExtUtils::MakeMaker qw{WriteMakefile prompt};
use FileHandle;
use Getopt::Std;

my %opt;
getopts ('ny', \%opt) or die <<eod;
The only legal options are
  -n = answer all questions 'no'.
  -y = answer all questions 'yes'.
You may not assert both of these at once - it's too confusing.
eod

my @exe_files;
my @clean_files;

my @possible_exes = ('SpaceTrack');
my $tk = eval {require Tk} and push @possible_exes, 'SpaceTrackTk';
print $tk ? <<eod : <<eod;

The following scripts will be installed:

  SpaceTrack is an interactive interface to Astro::SpaceTrack;
  SpaceTrackTk is a windowed interface to Astro::SpaceTrack, using
    Perl/Tk.
eod

The following script will be installed:

   SpaceTrack is an interactive interface to Astro::SpaceTrack.

SpaceTrackTk, a windowed interface to Astro::SpaceTrack, is provided
but will not be installed because you do not have the Tk package
installed. If you want this, install Tk and then rerun Makefile.PL.
eod
print <<eod;

If you do not want this, run Makefile.PL with the -n option.

Unless you are running MSWin32 or VMS (which are special-cased),
I will assume you're running some version of U*ix, and behave
accordingly.

eod


if ($opt{n}) {
    print "Because you have asserted -n, the executables will not be installed.\n\n";
    }
  elsif ($opt{y}) {
    print "Because you have asserted -y, the executables will be installed.\n\n";
    @exe_files = @possible_exes;
    }
  else {
    foreach (@possible_exes) {
	push @exe_files, $_
##	    if prompt ("Do you want to install $_?", 'n') =~ m/^y/i
	    ;
	}
    }

if (@exe_files) {
    if ($^O eq 'MSWin32') {
	@exe_files = map {"bin/$_"} @exe_files;
	foreach (@exe_files) {`pl2bat $_`}
	@clean_files = @exe_files =
	    grep {-e $_} map {"$_.bat"} @exe_files;
	}
      elsif ($^O eq 'VMS') {
	foreach my $fni (map {"[.bin]$_"} @exe_files) {
	    my $fno = "$fni.com";
	    my $fhi = FileHandle->new ("<$fni") or die <<eod;
Error - Unable to open $fni
        $!
eod
	    my $fho = FileHandle->new (">$fno") or die <<eod;
Error - Unable to open $fno
        $!
eod
	    print $fho "$Config{startperl}\n";
	    while (<$fhi>) {print $fho $_}
	    }
	@clean_files = @exe_files = map {"[.bin]$_.com"} @exe_files;
	}
      else {
	@exe_files = map {"bin/$_"} @exe_files;
	}
    }

##my $vers = $] >= 5.008 ? '-5.8' : '';
my $vers = '';

WriteMakefile (
	NAME => 'Astro::SpaceTrack',
	VERSION_FROM => 'lib/Astro/SpaceTrack.pm',
	PREREQ_PM => {
			$^O eq 'MSWin32' ? () : (
				'LWP::UserAgent' => 0,
				)
			},
	PL_FILES => {},	# Prevent old MakeMaker from running Build.PL
	EXE_FILES => \@exe_files,
#	'linkext' => {LINKTYPE => ''},
	'dist' => {COMPRESS => 'gzip', SUFFIX => 'gz'},
	realclean => {FILES => join ' ', @clean_files},
	$] >= 5.005 ? (
		AUTHOR => 'Tom Wyant (wyant at cpan dot org)',
		ABSTRACT => 'Download satellite orbital elements from Space Track',
		BINARY_LOCATION => "$Config{archname}$vers/Astro-SpaceTrack.tar.gz",
		(ExtUtils::MakeMaker->VERSION >= 6.31 ?
		    (LICENSE => 'perl') : ())
		) : (),
	);

