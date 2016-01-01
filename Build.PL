use 5.006002;

use strict;
use warnings;

use lib qw{ inc };

use My::Module::Build;
use My::Module::Meta;
use Config;
use FileHandle;
use Module::Build;

my $meta = My::Module::Meta->new();

(my $mbv = Module::Build->VERSION) =~ s/_//g;

my %attr = (
    dist_author => 'Tom Wyant (wyant at cpan dot org)',
    dist_abstract => 'Download satellite orbital elements from Space Track',
    module_name => 'Astro::SpaceTrack',
    get_options => {y => {}, n => {}},
    license => 'perl',
    requires => $meta->requires(
	perl	=> $meta->requires_perl(),
    ),
    build_requires => $meta->build_requires(),
    configure_requires => {},	# Don't require Module::Build
);

$mbv >= 0.28
    and $attr{meta_merge} = $meta->meta_merge();

# Don't require Module::Build if we're making a distribution, since the
# the user may simply prefer ExtUtils::MakeMaker.

$mbv >= 0.34
    and $attr{auto_configure_requires} = !$meta->distribution();

#	Generate a builder object.

my $bldr = My::Module::Build->new (%attr);

#	Find out what the user wants to do.

my %opt = $bldr->args ();

my @exe_files = map {"bin/$_"}
    $meta->notice( \%opt, sub { return $bldr->prompt( @_ ) } );

#	Tell Module::Build what we want to do.

$bldr->script_files (\@exe_files);

#	Generate the build script, at long last.

$bldr->create_build_script ();
