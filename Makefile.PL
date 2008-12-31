use 5.006;

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

The following scripts can be installed:

  SpaceTrack is an interactive interface to Astro::SpaceTrack;
  SpaceTrackTk is a windowed interface to Astro::SpaceTrack, using
    Perl/Tk.

eod

The following script can be installed:

   SpaceTrack is an interactive interface to Astro::SpaceTrack.

SpaceTrackTk, a windowed interface to Astro::SpaceTrack, is provided
but will not be installed because you do not have the Tk package
installed. If you want this, install Tk and then rerun Makefile.PL.

eod

if ($opt{n}) {
    print "Because you have asserted -n, the executables will not be installed.\n\n";
    }
  elsif ($opt{y}) {
    print "Because you have asserted -y, the executables will be installed.\n\n";
    @exe_files = @possible_exes;
    }
  else {
    print <<eod;
To supress the following prompts, run Makefile.PL with the -y option to
install the scripts, or with the -n option not to install the scripts.
Setting environment variable PERL_MM_USE_DEFAULT true, or running non-
interactively without data on STDIN will also cause the scripts not to
be installed.

eod

    foreach (@possible_exes) {
	push @exe_files, $_
	    if prompt ("Do you want to install $_?", 'n') =~ m/^y/i
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

(my $mmv = ExtUtils::MakeMaker->VERSION) =~ s/_//g;

my %attr = (
    NAME => 'Astro::SpaceTrack',
    VERSION_FROM => 'lib/Astro/SpaceTrack.pm',
    PREREQ_PM => {
	'Compress::Zlib' => 0,
	'HTML::Parser' => 0,
	'HTTP::Response' => 0,
	'HTTP::Status' => 0,
	'LWP::UserAgent' => 0,
	'Params::Util' => 0.12,
    },
    PL_FILES => {},	# Prevent old MakeMaker from running Build.PL
    EXE_FILES => \@exe_files,
    'dist' => {COMPRESS => 'gzip', SUFFIX => 'gz'},
    realclean => {FILES => join ' ', @clean_files},
    AUTHOR => 'Tom Wyant (wyant at cpan dot org)',
    ABSTRACT => 'Download satellite orbital elements from Space Track',
);

$mmv >= 6.31 and $attr{LICENSE} = 'perl';

$mmv >= 6.4501 and $attr{META_MERGE} = {
    resources => {
	license => 'http://dev.perl.org/licenses/',
    },
};

WriteMakefile (%attr);
