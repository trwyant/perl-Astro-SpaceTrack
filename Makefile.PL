use 5.006002;

use strict;
use warnings;

use lib qw{ inc };
use My::Module::Meta;

use Config;
use ExtUtils::MakeMaker qw{WriteMakefile prompt};
use FileHandle;
use Getopt::Std;

my %opt;
getopts ('ny', \%opt) or die <<'EOD';
The only legal options are
  -n = answer all questions 'no'.
  -y = answer all questions 'yes'.
You may not assert both of these at once - it's too confusing.
EOD

my @exe_files;
my @clean_files;

my @possible_exes = ('SpaceTrack');
my $tk = eval { require Tk; 1 } and push @possible_exes, 'SpaceTrackTk';
print $tk ? <<'EOD' : <<'EOD';

The following scripts can be installed:

  SpaceTrack is an interactive interface to Astro::SpaceTrack;
  SpaceTrackTk is a windowed interface to Astro::SpaceTrack, using
    Perl/Tk.

EOD

The following script can be installed:

   SpaceTrack is an interactive interface to Astro::SpaceTrack.

SpaceTrackTk, a windowed interface to Astro::SpaceTrack, is provided
but will not be installed because you do not have the Tk package
installed. If you want this, install Tk and then rerun Makefile.PL.

EOD

if ($opt{n}) {
    print "Because you have asserted -n, the executables will not be installed.\n\n";
    }
  elsif ($opt{y}) {
    print "Because you have asserted -y, the executables will be installed.\n\n";
    @exe_files = @possible_exes;
    }
  else {
    print <<'EOD';
To supress the following prompts, run Makefile.PL with the -y option to
install the scripts, or with the -n option not to install the scripts.
Setting environment variable PERL_MM_USE_DEFAULT true, or running non-
interactively without data on STDIN will also cause the scripts not to
be installed.

EOD

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

my $meta = My::Module::Meta->new();

(my $mmv = ExtUtils::MakeMaker->VERSION) =~ s/_//g;

my %attr = (
    NAME => 'Astro::SpaceTrack',
    VERSION_FROM => 'lib/Astro/SpaceTrack.pm',
    PREREQ_PM => $meta->requires(),
    PL_FILES => {},	# Prevent old MakeMaker from running Build.PL
    EXE_FILES => \@exe_files,
    'dist' => {COMPRESS => 'gzip', SUFFIX => 'gz'},
    realclean => {FILES => join ' ', @clean_files},
    AUTHOR => 'Tom Wyant (wyant at cpan dot org)',
    ABSTRACT => 'Download satellite orbital elements from Space Track',
);

$mmv >= 6.31 and $attr{LICENSE} = 'perl';

if ( $mmv >= 6.4501 ) {
    $attr{META_ADD} = {
	no_index => {
	    directory => [ qw{ inc t xt } ],
	},
    };
    $attr{META_MERGE} = {
	resources => {
	    bugtracker => 'https://rt.cpan.org/Public/Dist/Display.html?Name=Astro-SpaceTrack',
	    license => 'http://dev.perl.org/licenses/',
	},
    };
}

$mmv >= 6.4701 and $attr{MIN_PERL_VERSION} = $meta->requires_perl();

$mmv >= 6.5501
    and $attr{BUILD_REQUIRES} = $meta->build_requires()
    or $mmv >= 6.4501
    and $attr{META_MERGE}{build_requires} = $meta->build_requires();

WriteMakefile (%attr);
