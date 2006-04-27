#!/usr/bin/perl

=head1 NAME

Astro::SpaceTrack - Retrieve orbital data from www.space-track.org.

=head1 SYNOPSIS

 my $st = Astro::SpaceTrack->new (username => $me,
     password => $secret, with_name => 1) or die;
 my $rslt = $st->spacetrack ('special');
 print $rslt->is_success ? $rslt->content :
     $rslt->status_line;

or

 perl -MAstro::SpaceTrack=shell -e shell
 
 (some banner text gets printed here)
 
 SpaceTrack> set username me password secret
 OK
 SpaceTrack> set with_name 1
 OK
 SpaceTrack> spacetrack special >special.txt
 SpaceTrack> celestrak visual >visual.txt
 SpaceTrack> exit

=head1 LEGAL NOTICE

The following two paragraphs are quoted from the Space Track web site.

Due to existing National Security Restrictions pertaining to access of
and use of U.S. Government-provided information and data, all users
accessing this web site must be an approved registered user to access
data on this site.

By logging in to the site, you accept and agree to the terms of the
User Agreement specified in
L<http://www.space-track.org/perl/user_agreement.pl>.

You should consult the above link for the full text of the user
agreement before using this software.

=head1 DESCRIPTION

This package accesses the Space-Track web site,
L<http://www.space-track.org>, and retrieves orbital data from this
site. You must register and get a username and password before you
can make use of this package, and you must abide by the site's
restrictions, which include not making the data available to a
third party.

In addition, the celestrak method queries L<http://celestrak.com/> for
a named data set, and then queries L<http://www.space-track.org> for
the orbital elements of the objects in the data set.

Beginning with version 0.017, there is provision for retrieval of
historical data.

Nothing is exported by default, but the shell method/subroutine
can be exported if you so desire.

Most methods return an HTTP::Response object. See the individual
method document for details. Methods which return orbital data on
success add a 'Pragma: spacetrack-type = orbit' header to the
HTTP::Response object if the request succeeds.

=head2 Methods

The following methods should be considered public:

=over 4

=cut

# Help for syntax-highlighting editor that does not understand POD '

use strict;
use warnings;

use 5.006;

package Astro::SpaceTrack;

use base qw{Exporter};
use vars qw{$VERSION @EXPORT_OK};

$VERSION = "0.017";
@EXPORT_OK = qw{shell};

use Astro::SpaceTrack::Parser;
use Carp;
use Compress::Zlib ();
use Config;
use FileHandle;
use Getopt::Long;
use HTTP::Response;	# Not in the base, but comes with LWP.
use HTTP::Status qw{RC_NOT_FOUND RC_OK RC_PRECONDITION_FAILED
	RC_UNAUTHORIZED RC_INTERNAL_SERVER_ERROR};	# Not in the base, but comes with LWP.
use LWP::UserAgent;	# Not in the base.
use POSIX qw{strftime};
use Text::ParseWords;
use Time::Local;
use UNIVERSAL qw{isa};

use constant COPACETIC => 'OK';
use constant INVALID_CATALOG =>
	'Catalog name %s invalid. Legal names are %s.';
use constant LOGIN_FAILED => 'Login failed';
use constant NO_CREDENTIALS => 'Username or password not specified.';
use constant NO_CAT_ID => 'No catalog IDs specified.';
use constant NO_OBJ_NAME => 'No object name specified.';
use constant NO_RECORDS => 'No records found.';

use constant DOMAIN => 'www.space-track.org';
use constant SESSION_PATH => '/';
use constant SESSION_KEY => 'spacetrack_session';

my %catalogs = (	# Catalog names (and other info) for each source.
    celestrak => {
	'tle-new' => {name => "Last 30 Days' Launches"},
	stations => {name => 'International Space Station'},
	visual => {name => '100 (or so) brightest'},
	weather => {name => 'Weather'},
	noaa => {name => 'NOAA'},
	goes => {name => 'GOES'},
	resource => {name => 'Earth Resources'},
	sarsat => {name => 'Search and Rescue (SARSAT)'},
	dmc => {name => 'Disaster Monitoring'},
	tdrss => {name => 'Tracking and Data Relay Satellite System (TDRSS)'},
	geo => {name => 'Geostationary'},
	intelsat => {name => 'Intelsat'},
	gorizont => {name => 'Gorizont'},
	raduga => {name => 'Raduga'},
	molniya => {name => 'Molniya'},
	iridium => {name => 'Iridium'},
	orbcomm => {name => 'Orbcomm'},
	globalstar => {name => 'Globalstar'},
	amateur => {name => 'Amateur Radio'},
	'x-comm' => {name => 'Experimental Communications'},
	'other-comm' => {name => 'Other communications'},
	'gps-ops' => {name => 'GPS Operational'},
	'glo-ops' => {name => 'Glonass Operational'},
	nnss => {name => 'Navy Navigation Satellite System (NNSS)'},
	musson => {name => 'Russian LEO Navigation'},
	science => {name => 'Space and Earth Science'},
	geodetic => {name => 'Geodetic'},
	engineering => {name => 'Engineering'},
	education => {name => 'Education'},
	military => {name => 'Miscellaneous Military'},
	radar => {name => 'Radar Calibration'},
	cubesat => {name => 'CubeSats'},
	other => {name => 'Other'},
	},
    spacetrack => {
	md5 => {name => 'MD5 checksums', number => 0, special => 1},
	full => {name => 'Full catalog', number => 1},
	geosynchronous => {name => 'Geosynchronous satellites', number => 3},
	navigation => {name => 'Navigation satellites', number => 5},
	weather => {name => 'Weather satellites', number => 7},
	iridium => {name => 'Iridium satellites', number => 9},
	orbcomm => {name => 'OrbComm satellites', number => 11},
	globalstar => {name => 'Globalstar satellites', number => 13},
	intelsat => {name => 'Intelsat satellites', number => 15},
	inmarsat => {name => 'Inmarsat satellites', number => 17},
	amateur => {name => 'Amateur Radio satellites', number => 19},
	visible => {name => 'Visible satellites', number => 21},
	special => {name => 'Special satellites', number => 23},
	},
    );


my %mutator = (	# Mutators for the various attributes.
    addendum => \&_mutate_attrib,		# Addendum to banner text.
    banner => \&_mutate_attrib,
    cookie_expires => \&_mutate_attrib,
    direct => \&_mutate_attrib,
    dump_headers => \&_mutate_attrib,	# Dump all HTTP headers. Undocumented and unsupported.
    filter => \&_mutate_attrib,
    max_range => \&_mutate_number,
    password => \&_mutate_attrib,
    session_cookie => \&_mutate_cookie,
    username => \&_mutate_attrib,
    verbose => \&_mutate_attrib,
    webcmd => \&_mutate_attrib,
    with_name => \&_mutate_attrib,
    );
# Maybe I really want a cookie_file attribute, which is used to do
# $self->{agent}->cookie_jar ({file => $self->{cookie_file}, autosave => 1}).
# We'll want to use a false attribute value to pass an empty hash. Going to
# this may imply modification of the new () method where the cookie_jar is
# defaulted and the session cookie's age is initialized.


=item $st = Astro::SpaceTrack->new ( ... )

This method instantiates a new Space-Track accessor object. If any
arguments are passed, the set () method is called on the new object,
and passed the arguments given.

Proxies are taken from the environment if defined. See the ENVIRONMENT
section of the Perl LWP documentation for more information on how to
set these up.

=cut

my @inifil;

=begin comment

At some point I thought that an initialization file would be a good
idea. But it seems unlikely to me that anyone will want commands
other than 'set' commands issued every time an object is instantiated,
and the 'set' commands are handled by the environment variables. So
I changed my mind.

my $inifil = $^O eq 'MSWin32' || $^O eq 'VMS' || $^O eq 'MacOS' ?
    'SpaceTrack.ini' : '.SpaceTrack';

$inifil = $^O eq 'VMS' ? "SYS\$LOGIN:$inifil" :
    $^O eq 'MacOS' ? $inifil :
    $ENV{HOME} ? "$ENV{HOME}/$inifil" :
    $ENV{LOGDIR} ? "$ENV{LOGDIR}/$inifil" : undef or warn <<eod;
Warning - Can't find home directory. Initialization file will not be
        executed.
eod

# Help for syntax-highlighting editor that does not understand here documents '

@inifil = __PACKAGE__->_source ($inifil) if $inifil && -e $inifil;

=end comment

=cut

sub new {
my $class = shift;
$class = ref $class if ref $class;

my $self = {
    agent => LWP::UserAgent->new (),
    banner => 1,	# shell () displays banner if true.
    cookie_expires => undef,
    dump_headers => 0,	# No dumping.
    filter => 0,	# Filter mode.
    max_range => 500,	# Sanity limit on range size.
    password => undef,	# Login password.
    session_cookie => undef,
    username => undef,	# Login username.
    verbose => undef,	# Verbose error messages for catalogs.
    webcmd => undef,	# Command to get web help.
    with_name => undef,	# True to retrieve three-line element sets.
    };
bless $self, $class;

$self->{agent}->env_proxy;

if (@inifil) {
    $self->{filter} = 1;
    $self->shell (@inifil, 'exit');
    $self->{filter} = 0;
    }

$ENV{SPACETRACK_OPT} and
    $self->set (grep {defined $_} split '\s+', $ENV{SPACETRACK_OPT});

$ENV{SPACETRACK_USER} and do {
    my ($user, $pass) = split '/', $ENV{SPACETRACK_USER}, 2;
    $self->set (username => $user, password => $pass);
    };

@_ and $self->set (@_);

$self->{agent}->cookie_jar ({})
    unless $self->{agent}->cookie_jar;

$self->_check_cookie ();

return $self;
}


=item $resp = banner ();

This method is a convenience/nuisance: it simply returns a fake
HTTP::Response with standard banner text. It's really just for the
benefit of the shell method.

=cut

# Help for syntax-highlighting editor that does not understand POD '

sub banner {
my $self = shift;
HTTP::Response->new (RC_OK, undef, undef, <<eod);

@{[__PACKAGE__]} version $VERSION
Perl $Config{version} under $^O

You must register with http://@{[DOMAIN]}/ and get a
username and password before you can make use of this package,
and you must abide by that site's restrictions, which include
not making the data available to a third party without prior
permission.

Copyright 2005, 2006 T. R. Wyant (wyant at cpan dot org). All
rights reserved.

This module is free software; you can use it, redistribute it
and/or modify it under the same terms as Perl itself.
@{[$self->{addendum} || '']}
eod

# Help for syntax-highlighting editor that does not understand here documents '

}


=item $resp = $st->celestrak ($name);

This method takes the name of a Celestrak data set and returns an
HTTP::Response object whose content is the relevant element sets.
If called in list context, the first element of the list is the
aforementioned HTTP::Response object, and the second element is a
list reference to list references  (i.e. a list of lists). Each
of the list references contains the catalog ID of a satellite or
other orbiting body and the common name of the body.

If the 'direct' attribute is true, the elements will be fetched
directly from Celestrak, and no login is needed. Otherwise, This
method implicitly calls the login () method if the session cookie
is missing or expired. If login () fails, you will get the
HTTP::Response from login ().

If this method succeeds, a 'Pragma: spacetrack-type = orbit' header is
added to the HTTP::Response object returned.

=cut

# Help for syntax-highlighting editor that does not understand POD '

{	# Local symbol block.

my %valid_type = ('text/plain' => 1, 'text/text' => 1);

sub celestrak {
my $self = shift;
delete $self->{_content_type};
my $name = shift;
my $resp = $self->{direct} ?
    $self->{agent}->get ("http://celestrak.com/NORAD/elements/$name.txt") :
    $self->{agent}->get ("http://celestrak.com/SpaceTrack/query/$name.txt");
return $self->_no_such_catalog (celestrak => $name)
    if $resp->code == RC_NOT_FOUND;
return $resp unless $resp->is_success;
return $self->_no_such_catalog (celestrak => $name)
    unless $valid_type{lc $resp->header ('Content-Type')};
$self->_convert_content ($resp);
if ($self->{direct}) {
    $self->{_content_type} = 'orbit';
    $resp->push_header (pragma => 'spacetrack-type = orbit');
    $self->_dump_headers ($resp) if $self->{dump_headers};
    return $resp;
    }
  else {
    return $self->_handle_observing_list ($resp->content);
    }
}

}	# End local symbol block.


=item $type = $st->content_type ($resp);

This method takes the given HTTP::Response object and returns the
data type specified by the 'Pragma: spacetrack-type =' header. The
following values are supported:

 'get': The content is a parameter value.
 'help': The content is help text.
 'orbit': The content is NORAD data sets.
 undef: No spacetrack-type pragma was specified. The
        content is something else (typically 'OK').

If the response object is not provided, it returns the data type
from the last method call that returned an HTTP::Response object.

=cut

sub content_type {
my $self = shift;
return $self->{_content_type} unless @_;
my $resp = shift;
foreach ($resp->header ('Pragma')) {
    m/spacetrack-type = (.+)/i and return $1;
    }
return;
}


=item $resp = $st->file ($name)

This method takes the name of an observing list file, or a handle to
an open observing list file, and returns an HTTP::Response object whose
content is the relevant element sets. If called in list context, the
first element of the list is the aforementioned HTTP::Response object,
and the second element is a list reference to list references  (i.e.
a list of lists). Each of the list references contains the catalog ID
of a satellite or other orbiting body and the common name of the body.

This method implicitly calls the login () method if the session cookie
is missing or expired. If login () fails, you will get the
HTTP::Response from login ().

The observing list file is (how convenient!) in the Celestrak format,
with the first five characters of each line containing the object ID,
and the rest containing a name of the object. Lines whose first five
characters do not look like a right-justified number will be ignored.

If this method succeeds, a 'Pragma: spacetrack-type = orbit' header is
added to the HTTP::Response object returned.

=cut

sub file {
my $self = shift;
delete $self->{_content_type};
my $name = shift;
ref $name and fileno ($name) and return $self->_handle_observing_list (<$name>);
-e $name or return HTTP::Response->new (RC_NOT_FOUND, "Can't find file $name");
my $fh = FileHandle->new ($name) or
    return HTTP::Response->new (RC_INTERNAL_SERVER_ERROR, "Can't open $name: $!");
local $/;
$/ = undef;
return $self->_handle_observing_list (<$fh>)
}


=item $resp = $st->get (attrib)

B<This method returns an HTTP::Response object> whose content is the value
of the given attribute. If called in list context, the second element
of the list is just the value of the attribute, for those who don't want
to winkle it out of the response object. We croak on a bad attribute name.

See L</Attributes> for the names and functions of the attributes.

=cut

# Help for syntax-highlighting editor that does not understand POD '

sub get {
my $self = shift;
delete $self->{_content_type};
my $name = shift;
croak "Attribute $name may not be gotten. Legal attributes are ",
	join (', ', sort keys %mutator), ".\n"
    unless $mutator{$name};
my $resp = HTTP::Response->new (RC_OK, undef, undef, $self->{$name});
$self->{_content_type} = 'get';
$resp->push_header (pragma => 'spacetrack-type = get');
$self->_dump_headers ($resp) if $self->{dump_headers};
return wantarray ? ($resp, $self->{$name}) : $resp;
}


=item $resp = $st->help ()

This method exists for the convenience of the shell () method. It
always returns success, with the content being whatever it's
convenient (to the author) to include.

=cut

# Help for syntax-highlighting editor that does not understand POD '

sub help {
my $self = shift;
delete $_[0]->{_content_type};
if ($self->{webcmd}) {
    system (join ' ', $self->{webcmd},
	"http://search.cpan.org/~wyant/Astro-SpaceTrack-$VERSION/");
    HTTP::Response->new (RC_OK, undef, undef, 'OK');
    }
  else {
    my $resp = HTTP::Response->new (RC_OK, undef, undef, <<eod);
The following commands are defined:
  celestrak name
    Retrieves the named catalog of IDs from Celestrak. If the
    direct attribute is false (the default), the corresponding
    orbital elements come from Space Track. If true, they come
    from Celestrak, and no login is needed.
  exit (or bye)
    Terminate the shell. End-of-file also works.
  file filename
    Retrieve the catalog IDs given in the named file (one per
    line, with the first five characters being the ID).
  get
    Get the value of a single attribute.
  help
    Display this help text.
  iridium_status
    Status of Iridium satellites, from Mike McCants.
  login
    Acquire a session cookie. You must have already set the
    username and password attributes. This will be called
    implicitly if needed by any method that accesses data.
  names source
    Lists the catalog names from the given source.
  retrieve number ...
    Retieves the latest orbital elements for the given
    catalog numbers.
  search_id id ...
    Retrieves orbital elements by international designator.
  search_name name ...
    Retrieves orbital elements by satellite common name.
  set attribute value ...
    Sets the given attributes. Legal attributes are
      addendum = extra text for the shell () banner;
      banner = false to supress the shell () banner;
      cookie_expires = Perl date the session cookie expires;
      direct = true to fetch orbital elements directly
        from a redistributor. Currently this only affects the
        celestrak() method. The default is false.
      dump_headers is unsupported, and intended for debugging -
        don't be suprised at anything it does, and don't rely
        on anything it does;
      filter = true supresses all output to stdout except
        orbital elements;
      max_range = largest range of numbers that can be re-
        trieved (default: 500);
      password = the Space-Track password;
      session_cookie = the text of the session cookie;
      username = the Space-Track username;
      verbose = true for verbose catalog error messages;
      webcmd = command to launch a URL (for web-based help);
      with_name = true to retrieve common names as well.
    The session_cookie and cookie_expires attributes should
    only be set to previously-retrieved, matching values.
  source filename
    Executes the contents of the given file as shell commands.
  spaceflight
    Retrieves orbital elements from http://spaceflight.nasa.gov/.
    No login needed, but you get at most the ISS and the current
    shuttle mission.
  spacetrack name
    Retrieves the named catalog of orbital elements from
    Space Track.
The shell supports a pseudo-redirection of standard output,
using the usual Unix shell syntax (i.e. '>output_file').
eod
    $self->{_content_type} = 'help';
    $resp->push_header (pragma => 'spacetrack-type = help');
    $self->_dump_headers ($resp) if $self->{dump_headers};
    $resp;
    }
}


=item $resp = $st->iridium_status ();

This method queries Mike McCants' "Status of Iridium Payloads" web
page, http://users2.ev1.net/~mmccants/tles/iridium.html (which gives
status on non-function Iridium satellites) and the Celestrak list of
all Iridium satellites. It returns an HTTP::Response object. If the
query was successful, the content of the object is the status table
from Mike McCants' page, with the Celestrak data merged in so that
all Iridium satellites are represented. The Celestrak data are
identified with the word 'Celestrak' in the comment field. Any other
comment indicates data from Mike McCants.

As of 20-Feb-2006 Mike's web page documented the possible statuses as
follows:

 blank - object is operational
 'tum' - tumbling
 '?' - not at operational altitude
 'man' - maneuvering, at least slightly.

In addition, the data from Celestrak may contain the fillowing
status:

 'dum' - Dummy mass

=cut

# Help editor that does not understand POD. '

sub iridium_status {
my $self = shift;
delete $self->{_content_type};
my %rslt;
my $resp = $self->{agent}->get ("http://celestrak.com/SpaceTrack/query/iridium.txt");
$resp->is_success or return $resp;
foreach my $buffer (split '\n', $resp->content) {
    $buffer =~ s/\s+$//;
    my $id = substr ($buffer, 0, 5) + 0;
    my $name = substr ($buffer, 5);
    my $status = $name =~ m/^IRIDIUM/i ? '' : 'dum';
    $name = ucfirst lc $name;
    $rslt{$id} = sprintf "%6d   %-15s%-8s Celestrak\n",
	$id, $name, $status;
    }
$resp = $self->{agent}->get ('http://users2.ev1.net/~mmccants/tles/iridium.html');
$resp->is_success or return $resp;
foreach my $buffer (split '\n', $resp->content) {
    $buffer =~ m/^\s*(\d+)\s+Iridium\s+\S+/ or next;
    my $id = $1 + 0;
    $buffer =~ s/\s+$//;
    $rslt{$id} = $buffer . "\n";
#0         1         2         3         4         5         6         7
#01234567890123456789012345678901234567890123456789012345678901234567890
# 24836   Iridium 914    tum      Failed; was called Iridium 14
    }
$resp->content (join '', map {$rslt{$_}} sort {$a <=> $b} keys %rslt);
$self->{_content_type} = 'iridium-status';
$resp->push_header (pragma => 'spacetrack-type = iridium-status');
$self->_dump_headers ($resp) if $self->{dump_headers};
$resp;
}

=item $resp = $st->login ( ... )

If any arguments are given, this method passes them to the set ()
method. Then it executes a login. The return is normally the
HTTP::Response object from the login. But if no session cookie was
obtained, the return is an HTTP::Response with an appropriate message
and the code set to RC_UNAUTHORIZED from HTTP::Status (a.k.a. 401). If
a login is attempted without the username and password being set, the
return is an HTTP::Response with an appropriate message and the
code set to RC_PRECONDITION_FAILED from HTTP::Status (a.k.a. 412).

=cut

sub login {
my $self = shift;
delete $self->{_content_type};
@_ and $self->set (@_);
$self->{username} && $self->{password} or
    return HTTP::Response->new (
	RC_PRECONDITION_FAILED, NO_CREDENTIALS);
$self->{dump_headers} and warn <<eod;
Logging in as $self->{username}.
eod

#	Do not use the _post method to retrieve the session cookie,
#	unless you like bottomless recursions.
my $resp = $self->{agent}->post (
    "http://@{[DOMAIN]}/perl/login.pl", [
	username => $self->{username},
	password => $self->{password},
	_submitted => 1,
	_sessionid => "",
	]);

$resp->is_success or return $resp;
$self->_dump_headers ($resp) if $self->{dump_headers};

$self->_check_cookie () > time ()
    or return HTTP::Response->new (RC_UNAUTHORIZED, LOGIN_FAILED);

$self->{dump_headers} and warn <<eod;
Login successful.
eod
HTTP::Response->new (RC_OK, undef, undef, "Login successful.\n");
}


=item $resp = $st->names (source)

This method retrieves the names of the catalogs for the given source,
either 'celestrak' or 'spacetrack', in the content of the given
HTTP::Response object. In list context, you also get a reference to
a list of two-element lists; each inner list contains the description
and the catalog name (suitable for inserting into a Tk Optionmenu).

=cut

sub names {
my $self = shift;
delete $self->{_content_type};
my $name = lc shift;
$catalogs{$name} or return HTTP::Response (
	RC_NOT_FOUND, "Data source '$name' not found.");
my $src = $catalogs{$name};
my @list;
foreach my $cat (sort keys %$src) {
    push @list, "$cat: $src->{$cat}{name}\n";
    }
my $resp = HTTP::Response->new (RC_OK, undef, undef, join ('', @list));
return $resp unless wantarray;
@list = ();
foreach my $cat (sort {$src->{$a}{name} cmp $src->{$b}{name}} keys %$src) {
    push @list, [$src->{$cat}{name}, $cat];
    }
return ($resp, \@list);
}


=item $resp = $st->retrieve (number_or_range ...)

This method retrieves the latest element set for each of the given
catalog numbers. Non-numeric catalog numbers are ignored, as are
(at a later stage) numbers that do not actually represent a satellite.

Number ranges are represented as 'start-end', where both 'start' and
'end' are catalog numbers. If 'start' > 'end', the numbers will be
taken in the reverse order. Non-numeric ranges are ignored.

You can specify options for the retrieval as either command-type
options (e.g. -last5) or as a leading hash reference (e.g.
{last5 => 1}, ...). If you specify the hash reference, option
names must be specified in full, without the leading '-', and the
argument list will not be parsed for command-type options. If you
specify command-type options, they may be abbreviated, as long as
the abbreviation is unique. Errors in either sort result in an
exception being thrown.

The legal options are:

 descending
   specifies the data be returned in descending order.
 end_epoch date
   specifies the end epoch for the desired data.
 last5
   specifies the last 5 element sets be retrieved.
   Ignored if start_epoch or end_epoch specified.
 start_epoch date
   specifies the start epoch for the desired data.
 sort type
   specifies how to sort the data. Legal types are
   'catnum' and 'epoch', with 'catnum' the default.

If you specify either start_epoch or end_epoch, you get data with
epochs at least equal to the start epoch, but less than the end
epoch (i.e. the interval is closed at the beginning but open at
the end). If you specify only one of these, you get a one-day
interval. Dates are specified either numerically (as a Perl date)
or as numeric year-month-day, punctuated by any non-numeric string.
It is an error to specify an end_epoch before the start_epoch.

If you are passing the options as a hash reference, you must specify
a value the boolean options 'descending' and 'last5'. This value is
interpreted in the Perl sense - that is, undef, 0, and '' are false,
and anything else is true.

In order not to load the Space Track web site too heavily, data are
retrieved in batches of 50. Ranges will be subdivided and handled in
more than one retrieval if necessary. To limit the damage done by a
pernicious range, ranges greater than the max_range setting (which
defaults to 500) will be ignored with a warning to STDERR.

This method implicitly calls the login () method if the session cookie
is missing or expired. If login () fails, you will get the
HTTP::Response from login ().

If this method succeeds, a 'Pragma: spacetrack-type = orbit' header is
added to the HTTP::Response object returned.

=cut

use constant RETRIEVAL_SIZE => 50;

sub retrieve {
my $self = shift;
delete $self->{_content_type};

@_ = _parse_retrieve_args (@_) unless ref $_[0] eq 'HASH';
my $opt = shift;

foreach my $key (qw{end_epoch start_epoch}) {
    next unless $opt->{$key};
    next if ref $opt->{$key};
    $opt->{$key} !~ m/\D/ or
	$opt->{$key} =~ m/^(\d+)\D+(\d+)\D+(\d+)$/ and
	    $opt->{$key} = eval {timegm (0, 0, 0, $3, $2-1, $1)} or
	croak <<eod;
Error - Illegal date '$opt->{$key}'. Valid dates are a number
	(interpreted as a Perl date) or numeric year-month-day.
eod
    my ($opp, $off) = $key eq 'start_epoch' ?
	(end_epoch => 1) : (start_epoch => -1);
    unless ($opt->{$opp}) {
	$opt->{$opp} = [gmtime (86400 * $off + $opt->{$key})];
	}
    $opt->{$key} = [gmtime  ($opt->{$key})];
    }

$opt->{sort} ||= 'catnum';

$opt->{sort} eq 'catnum' || $opt->{sort} eq 'epoch' or die <<eod;
Error - Illegal sort '$opt->{sort}'. You must specify 'catnum'
        (the default) or 'epoch'.
eod

my @params = $opt->{start_epoch} ?
    (timeframe => 'timespan',
	start_year => $opt->{start_epoch}[5] + 1900,
	start_month => $opt->{start_epoch}[4] + 1,
	start_day => $opt->{start_epoch}[3],
	end_year => $opt->{end_epoch}[5] + 1900,
	end_month => $opt->{end_epoch}[4] + 1,
	end_day => $opt->{end_epoch}[3],
	) :
    $opt->{last5} ? (timeframe => 'last5') : (timeframe => 'latest');
push @params, common_name => $self->{with_name} ? 'yes' : '';
push @params, sort => $opt->{sort};
push @params, descending => $opt->{descending} ? 'yes' : '';

@_ = grep {m/^\d+(?:-\d+)?$/} @_;

@_ or return HTTP::Response->new (RC_PRECONDITION_FAILED, NO_CAT_ID);
my $content = '';
local $_;
my $resp;
while (@_) {
    my @batch;
    my $ids = 0;
    while (@_ && $ids < RETRIEVAL_SIZE) {
	$ids++;
	my ($lo, $hi) = split '-', shift @_;
	defined $hi and do {
	    ($lo, $hi) = ($hi, $lo) if $lo > $hi;
	    $hi - $lo >= $self->{max_range} and do {
		carp <<eod;
Warning - Range $lo-$hi ignored because it is greater than the
          currently-set maximum of $self->{max_range}.
eod
		next;
		};
	    $ids += $hi - $lo;
	    $ids > RETRIEVAL_SIZE and do {
		my $mid = $hi - $ids + RETRIEVAL_SIZE;
		unshift @_, "@{[$mid + 1]}-$hi";
		$hi = $mid;
		};
	    $lo = "$lo-$hi" if $hi > $lo;
	    };
	push @batch, $lo;
	}
    next unless @batch;
    $resp = $self->_post ('perl/id_query.pl',
	ids => "@batch",
	@params,
	ascii => 'yes',		# or ''
	_sessionid => '',
	_submitted => 1,
	);
    return $resp unless $resp->is_success;
    $_ = $resp->content;
    next if m/No records found/i;
    s|</pre>.*||ms;
    s|.*<pre>||ms;
    s|^\n||ms;
    $content .= $_;
    }
$content or return HTTP::Response->new (RC_NOT_FOUND, NO_RECORDS);
$resp->content ($content);
$self->_convert_content ($resp);
$self->{_content_type} = 'orbit';
$resp->push_header (pragma => 'spacetrack-type = orbit');
$resp;
}


=item $resp = $st->search_id (id ...)

This method searches the database for objects having the given
international IDs. The international ID is the last two digits
of the launch year (in the range 1957 through 2056), the
three-digit sequence number of the launch within the year (with
leading zeroes as needed), and the piece (A through ZZ, with A
typically being the payload). You can omit the piece and get all
pieces of that launch, or omit both the piece and the launch
number and get all launches for the year. There is no
mechanism to restrict the search to a given date range, on-orbit
status, or to filter out debris or rocket bodies.

This method implicitly calls the login () method if the session cookie
is missing or expired. If login () fails, you will get the
HTTP::Response from login ().

On success, this method returns an HTTP::Response object whose content
is the relevant element sets. If called in list context, the first
element of the list is the aforementioned HTTP::Response object, and
the second element is a list reference to list references  (i.e. a list
of lists). The first list reference contains the header text for all
columns returned, and the subsequent list references contain the data
for each match.

If this method succeeds, a 'Pragma: spacetrack-type = orbit' header is
added to the HTTP::Response object returned.

You can specify the L<retrieve> options on this method as well.

=cut

sub search_id {
my $self = shift;
delete $self->{_content_type};

@_ = _parse_retrieve_args (@_) unless ref $_[0] eq 'HASH';
my $opt = shift;

@_ or return HTTP::Response->new (RC_PRECONDITION_FAILED, NO_OBJ_NAME);

my $p = Astro::SpaceTrack::Parser->new ();
my @table;
my %id;
foreach my $name (@_) {
# Note that the only difference between this and search_name is
# the code from here vvvvvvvv
    my ($year, $number, $piece) =
	$name =~ m/^(\d\d)(\d{3})?([[:alpha:]])?$/ or next;
    $year += $year < 57 ? 2000 : 1900;
    my $resp = $self->_post ('perl/launch_query.pl',
	launch_year => $year,
	launch_number => $number || '',
	piece => uc ($piece || ''),
	status => 'all',	# or 'onorbit' or 'decayed'.
##	exclude => '',		# or 'debris' or 'rocket' or both.
	_sessionid => '',
	_submit => 'submit',
	_submitted => 1,
	);
# to here ^^^^^^^^^^^^^^^^
    return $resp unless $resp->is_success;
    my $content = $resp->content;
    next if $content =~ m/No results found/i;
    my @this_page = @{$p->parse_string (table => $content)};
    my @data = @{$this_page[0]};
    foreach my $row (@data) {
	pop @$row; pop @$row;
	}
    if (@table) {shift @data} else {push @table, shift @data};
    foreach my $row (@data) {
	push @table, $row unless $id{$row->[0]}++;
	}
    }
my $resp = $self->retrieve ($opt, sort {$a <=> $b} keys %id);
wantarray ? ($resp, \@table) : $resp;
}

=item $resp = $st->search_name (name ...)

This method searches the database for the named objects. Matches
are case-insensitive and all matches are returned. There is no
mechanism to restrict the search to a given date range, on-orbit
status, or to filter out debris or rocket bodies.

This method implicitly calls the login () method if the session cookie
is missing or expired. If login () fails, you will get the
HTTP::Response from login ().

On success, this method returns an HTTP::Response object whose content
is the relevant element sets. If called in list context, the first
element of the list is the aforementioned HTTP::Response object, and
the second element is a list reference to list references  (i.e. a list
of lists). The first list reference contains the header text for all
columns returned, and the subsequent list references contain the data
for each match.

If this method succeeds, a 'Pragma: spacetrack-type = orbit' header is
added to the HTTP::Response object returned.

You can specify the L<retrieve> options on this method as well.

=cut

sub search_name {
my $self = shift;
delete $self->{_content_type};

@_ = _parse_retrieve_args (@_) unless ref $_[0] eq 'HASH';
my $opt = shift;

@_ or return HTTP::Response->new (RC_PRECONDITION_FAILED, NO_OBJ_NAME);
my $p = Astro::SpaceTrack::Parser->new ();

my @table;
my %id;
foreach my $name (@_) {
# Note that the only difference between this and search_id is
# the code from here vvvvvvvv
    my $resp = $self->_post ('perl/name_query.pl',
	name => $name,
	launch_year_start => 1957,
	launch_year_end => (gmtime)[5] + 1900,
	status => 'all',	# or 'onorbit' or 'decayed'.
##	exclude => '',		# or 'debris' or 'rocket' or both.
	_sessionid => '',
	_submit => 'Submit',
	_submitted => 1,
	);
# to here ^^^^^^^^^^^^^^^^
    return $resp unless $resp->is_success;
    my $content = $resp->content;
    next if $content =~ m/No results found/i;
    my @this_page = @{$p->parse_string (table => $content)};
    my @data = @{$this_page[0]};
    foreach my $row (@data) {
	pop @$row; pop @$row;
	}
    if (@table) {shift @data} else {push @table, shift @data};
    foreach my $row (@data) {
	push @table, $row unless $id{$row->[0]}++;
	}
    }
my $resp = $self->retrieve ($opt, sort {$a <=> $b} keys %id);
wantarray ? ($resp, \@table) : $resp;
}


=item $st->set ( ... )

This is the mutator method for the object. It can be called explicitly,
but other methods as noted may call it implicitly also. It croaks if
you give it an odd number of arguments, or if given an attribute that
either does not exist or cannot be set.

For the convenience of the shell method we return a HTTP::Response
object with a success status if all goes well. But if we encounter an
error we croak.

See L</Attributes> for the names and functions of the attributes.

=cut

sub set {
my $self = shift;
delete $self->{_content_type};
croak "@{[__PACKAGE__]}->set (@{[join ', ', map {qq{'$_'}} @_]}) requires an even number of arguments"
    if @_ % 2;
while (@_) {
    my $name = shift;
    croak "Attribute $name may not be set. Legal attributes are ",
	    join (', ', sort keys %mutator), ".\n"
	unless $mutator{$name};
    my $value = shift;
    $mutator{$name}->($self, $name, $value);
    }
HTTP::Response->new (RC_OK, undef, undef, COPACETIC);
}


=item $st->shell ()

This method implements a simple shell. Any public method name except
'new' or 'shell' is a command, and its arguments if any are parameters.
We use Text::ParseWords to parse the line, and blank lines or lines
beginning with a hash mark ('#') are ignored. Input is via
Term::ReadLine if that is available. If not, we do the best we can.

We also recognize 'bye' and 'exit' as commands.

For commands that produce output, we allow a sort of pseudo-redirection
of the output to a file, using the syntax ">filename" or ">>filename".
If the ">" is by itself the next argument is the filename. In addition,
we do pseudo-tilde expansion by replacing a leading tilde with the
contents of environment variable HOME. Redirection can occur anywhere
on the line. For example,

 SpaceTrack> catalog special >special.txt

sends the "Special Interest Satellites" to file special.txt. Line
terminations in the file should be appropriate to your OS.

This method can also be called as a subroutine - i.e. as

 Astro::SpaceTrack::shell (...)

Whether called as a method or as a subroutine, each argument passed
(if any) is parsed as though it were a valid command. After all such
have been executed, control passes to the user. Unless, of course,
one of the arguments was 'exit'.

Unlike most of the other methods, this one returns nothing.

=cut

# Help for syntax-highlighting editor that does not understand POD '

my ($read, $print, $out, $rdln);

sub shell {
my $self = shift if UNIVERSAL::isa $_[0], __PACKAGE__;
$self ||= Astro::SpaceTrack->new (addendum => <<eod);

'help' gets you a list of valid commands.
eod

my $prompt = 'SpaceTrack> ';

$out = \*STDOUT;
$print = sub {
	my $hndl = UNIVERSAL::isa ($_[0], 'FileHandle') ? shift : $out;
	print $hndl @_};

unshift @_, 'banner' if $self->{banner} && !$self->{filter};
while (1) {
    my $buffer;
    if (@_) {
	$buffer = shift;
	}
      else {
	unless ($read) {
	    -t STDIN ? eval {
		require Term::ReadLine;
		$rdln ||= Term::ReadLine->new ('SpaceTrack orbital element access');
		$out = $rdln->OUT || \*STDOUT;
		$read = sub {$rdln->readline ($prompt)};
		} || ($read = sub {print $out $prompt; <STDIN>}):
		eval {$read = sub {<STDIN>}};
	    }
	$buffer = $read->();
	}
    last unless defined $buffer;

    chomp $buffer;
    $buffer =~ s/^\s+//;
    $buffer =~ s/\s+$//;
    next unless $buffer;
    next if $buffer =~ m/^#/;
    my @args = parse_line ('\s+', 0, $buffer);
    my $redir = '';
    @args = map {m/^>/ ? do {$redir = $_; ()} :
	$redir =~ m/^>+$/ ? do {$redir .= $_; ()} :
	$_} @args;
    $redir =~ s/^(>+)~/$1$ENV{HOME}/;
    my $verb = lc shift @args;
    last if $verb eq 'exit' || $verb eq 'bye';
    $verb eq 'source' and do {
	eval {
	    splice @_, 0, 0, $self->_source (shift @args);
	    };
	$@ and warn $@;
	next;
	};
    $verb eq 'new' || $verb =~ m/^_/ || $verb eq 'shell' ||
	!$self->can ($verb) and do {
	warn <<eod;
Verb '$verb' undefined. Use 'help' to get help.
eod
	next;
	};
    my @fh = (FileHandle->new ($redir)) or do {warn <<eod; next} if $redir;
Error - Failed to open $redir
        $^E
eod
    my $rslt = eval {$self->$verb (@args)};
    $@ and do {warn $@; next; };
    if ($rslt->is_success) {
	my $content = $rslt->content;
	chomp $content;
	$print->(@fh, "$content\n")
	    if !$self->{filter} || $self->content_type ();
	}
      else {
	my $status = $rslt->status_line;
	chomp $status;
	warn $status, "\n";
	}
    }
$print->("\n") if -t STDIN && !$self->{filter};
}


=item $st->source ($filename);

This convenience method reads the given file, and passes the individual
lines to the shell method. It croaks if the file is not provided or
cannot be read.

=cut

sub source {
my $self = shift if UNIVERSAL::isa $_[0], __PACKAGE__;
$self ||= Astro::SpaceTrack->new ();
$self->shell ($self->_source (@_), 'exit');
}


=item $resp = $st->spaceflight ()

This method downloads current orbital elements from NASA's human
spaceflight site, L<http://spaceflight.nasa.gov/>. As of November 2005
you get the International Space Station. An attempt is made to get the
current Space Shuttle mission if any, but as there is no way to test
this unless there is a mission in progress, whether this works is
anybody's guess.

No Space Track account is needed to access this data, even if the
'direct' attribute is false. But if the 'direct' attribute is true,
the setting of the 'with_name' attribute is ignored.

This method is a web page scraper. any change in the location of the
web pages, or any substantial change in their format, will break this
method.


=cut


# Help editor that does not understand POD '

sub spaceflight {
my $self = shift;
delete $self->{_content_type};
my $content = '';
my $now = time ();
foreach my $url (
	'http://spaceflight.nasa.gov/realdata/sightings/SSapplications/Post/JavaSSOP/orbit/ISS/SVPOST.html',
	'http://spaceflight.nasa.gov/realdata/sightings/SSapplications/Post/JavaSSOP/orbit/SHUTTLE/SVPOST.html',
	) {
    my $resp = $self->{agent}->get ($url);
    return $resp unless $resp->is_success;
    my ($tle, @data, $epoch, $acquire);
    foreach (split '\n', $resp->content) {
	chomp;
	m/TWO LINE MEAN ELEMENT SET/ and do {
	    $acquire = 1;
	    @data = ();
	    next;
	    };
	next unless $acquire;
	s/^\s+//;
	$_ and do {push @data, "$_\n"; next};
	@data and do {
	    $acquire = undef;
	    @data == 2 || @data == 3 or next;
	    shift @data
		if @data == 3 && !$self->{direct} && !$self->{with_name};
	    my $yr = substr ($data[@data - 2], 18, 2);
	    my $da = substr ($data[@data - 2], 20, 12);
	    $yr += 100 if $yr < 57;
	    my $ep = timegm (0, 0, 0, 1, 0, $yr) + ($da - 1) * 86400;
	    next if $ep > $now;
	    next if defined $epoch && $ep < $epoch;
	    $tle = join '', @data;
	    @data = ();
	    $epoch = $ep;
	    };
	}
    $content .= $tle if $tle;
    }

$content or
    return HTTP::Response->new (RC_PRECONDITION_FAILED, NO_CAT_ID);

my $resp = HTTP::Response->new (RC_OK, undef, undef, $content);
$self->{_content_type} = 'orbit';
$resp->push_header (pragma => 'spacetrack-type = orbit');
$self->_dump_headers ($resp) if $self->{dump_headers};
$resp;
}


=item $resp = $st->spacetrack ($name_or_number);

This method downloads the given bulk catalog of orbital elements. If
the argument is an integer, it represents the number of the
catalog to download. Otherwise, it is expected to be the name of
the catalog, and whether you get a two-line or three-line dataset is
specified by the setting of the with_name attribute. The return is
the HTTP::Response object fetched. If an invalid catalog name is
requested, an HTTP::Response object is returned, with an appropriate
message and the error code set to RC_NOTFOUND from HTTP::Status
(a.k.a. 404).

Assuming success, the content of the response is the literal element
set requested. Yes, it comes down gzipped, but we unzip it for you.
See the synopsis for sample code to retrieve and print the 'special'
catalog in three-line format.

This method implicitly calls the login () method if the session cookie
is missing or expired. If login () fails, you will get the
HTTP::Response from login ().

If this method succeeds, a 'Pragma: spacetrack-type = orbit' header is
added to the HTTP::Response object returned.

=cut

sub spacetrack {
my $self = shift;
delete $self->{_content_type};
my $catnum = shift;
$catnum =~ m/\D/ and do {
    my $info = $catalogs{spacetrack}{$catnum} or
	return $self->_no_such_catalog (spacetrack => $catnum);
    $catnum = $info->{number};
    $self->{with_name} && $catnum++ unless $info->{special};
    };
my $resp = $self->_get ('perl/dl.pl', ID => $catnum);
# At this point, assuming we succeeded, we should have headers
# content-disposition: attachment; filename=the_desired_file_name
# content-type: application/force-download
# In the above, the_desired_file_name is (e.g.) something like
#   spec_interest_2l_2005_03_22_am.txt.gz

$resp->is_success and do {
    $catnum and $resp->content (
	Compress::Zlib::memGunzip ($resp->content));
    $resp->remove_header ('content-disposition');
    $resp->header (
	'content-type' => 'text/plain',
##	'content-length' => length ($resp->content),
	);
    $self->_convert_content ($resp);
    $self->{_content_type} = 'orbit';
    $resp->push_header (pragma => 'spacetrack-type = orbit');
    };
$resp;
}


####
#
#	Private methods.
#

#	_check_cookie looks for our session cookie. If it's found, it returns
#	the cookie's expiration time and sets the relevant attributes.
#	Otherwise it returns zero.

sub _check_cookie {
my $self = shift;
my ($cookie, $expir);
$expir = 0;
$self->{agent}->cookie_jar->scan (sub {
    $self->{dump_headers} > 1 and _dump_cookie ("_check_cookie:\n", @_);
    ($cookie, $expir) = @_[2, 8] if $_[4] eq DOMAIN &&
	$_[3] eq SESSION_PATH && $_[1] eq SESSION_KEY;
    });
$self->{dump_headers} and warn $expir ? <<eod : <<eod;
Session cookie: $cookie
Cookie expiration: @{[strftime '%d-%b-%Y %H:%M:%S', localtime $expir]} ($expir)
eod
Session cookie not found
eod
$self->{session_cookie} = $cookie;
$self->{cookie_expires} = $expir;
return $expir || 0;
}


#	_convert_content converts the content of an HTTP::Response
#	from crlf-delimited to lf-delimited.

{	# Begin local symbol block
my $lookfor = $^O eq 'MacOS' ? qr{\012|\015+} : qr{\r\n};
sub _convert_content {
my $self = shift;
local $/;
$/ = undef;	# Slurp mode.
foreach my $resp (@_) {
    my $buffer = $resp->content;
    $buffer =~ s|$lookfor|\n|gms;
    1 while ($buffer =~ s|^\n||ms);
    $buffer =~ s|\s+$||ms;
    $buffer .= "\n";
    $resp->content ($buffer);
    $resp->header (
	'content-length' => length ($buffer),
	);
    }
}
}	# End local symbol block.

#	_dump_cookie is intended to be called from inside the
#	HTTP::Cookie->scan method. The first argument is prefix text
#	for the dump, and the subsequent arguments are the arguments
#	passed to the scan method.
#	It dumps the contents of the cookie to STDERR via a warn ().
#	A typical session cookie looks like this:
#	    version => 0
#	    key => 'spacetrack_session'
#	    val => whatever
#	    path => '/'
#	    domain => 'www.space-track.org'
#	    port => undef
#	    path_spec => 1
#	    secure => undef
#	    expires => undef
#	    discard => 1
#	    hash => {}
#	The response to the login, though, has an actual expiration
#	time, which we take cognisance of.

use Data::Dumper;
{	# begin local symbol block
my @names = qw{version key val path domain port path_spec secure
	expires discard hash};
sub _dump_cookie {
local $Data::Dumper::Terse = 1;
my $prefix = shift;
$prefix and warn $prefix;
for (my $inx = 0; $inx < @names; $inx++) {
    warn "    $names[$inx] => ", Dumper ($_[$inx]);
    }
}
}	# end local symbol block


#	_dump_headers dumps the headers of the passed-in response
#	object.

sub _dump_headers {
my $self = shift;
my $resp = shift;
local $Data::Dumper::Terse = 1;
warn "\nHeaders:\n", $resp->headers->as_string, "\nCookies:\n";
$self->{agent}->cookie_jar->scan (sub {
    _dump_cookie ("\n", @_);
    });
warn "\n";
}

#	_get gets the given path on the domain. Arguments after the
#	first are the CGI parameters. It checks the currency of the
#	session cookie, and executes a login if it deems it necessary.
#	The normal return is the HTTP::Response object from the get (),
#	but if a login was attempted and failed, the HTTP::Response
#	object from the login will be returned.

sub _get {
my $self = shift;
my $path = shift;
my $cgi = '';
while (@_) {
    my $name = shift;
    my $val = shift || '';
    $cgi .= "&$name=$val";
    }
$cgi and substr ($cgi, 0, 1) = '?';
{	# Single-iteration loop
    $self->{cookie_expires} > time () or do {
	my $resp = $self->login ();
	return $resp unless $resp->is_success;
	};
    my $resp = $self->{agent}->get ("http://@{[DOMAIN]}/$path$cgi");
    $self->_dump_headers ($resp) if $self->{dump_headers};
    return $resp unless $resp->is_success;
    local $_ = $resp->content;
    m/login\.pl/i and do {
	$self->{cookie_expires} = 0;
	redo;
	};
    return $resp;
    }	# end of single-iteration loop
}

#	Note: If we have a bad cookie, we get a success status, with
#	the text
# <?xml version="1.0" encoding="iso-8859-1"?>
# <!DOCTYPE html
#         PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
#          "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
# <html xmlns="http://www.w3.org/1999/xhtml" lang="en-US" xml:lang="en-US"><head><title>Space-Track</title>
# </head><body>
# <body bgcolor='#fffacd' text='#191970' link='#3333e6'>
#          <div align='center'><img src='http://www.space-track.org/icons/spacetrack_logo3.jpg' width=640 height=128 align='top' border=0></div>
# <h2>Error, Corrupted session cookie<br>
# Please <A HREF='login.pl'>LOGIN</A> again.<br>
# </h2>
# </body></html>
#	If this happens, it would be good to retry the login.


#	_handle_observing_list takes as input any number of arguments.
#	each is split on newlines, and lines beginning with a five-digit
#	number (with leading spaces allowed) are taken to specify the
#	catalog number (first five characters) and common name (the rest)
#	of an object. The resultant catalog numbers are run through the
#	retrieve () method. If called in scalar context, the return is
#	the resultant HTTP::Response object. In list context, the first
#	return is the HTTP::Response object, and the second is a reference
#	to a list of list references, each lower-level reference containing
#	catalog number and name.

sub _handle_observing_list {
my $self = shift;
my (@catnum, @data);
foreach (map {split '\n', $_} @_) {
    s/\s+$//;
    my ($id) = m/^([\s\d]{5})/ or next;
    $id =~ m/^\s*\d+$/ or next;
    push @catnum, $id;
    push @data, [$id, substr $_, 5];
    }
my $resp = $self->retrieve (sort {$a <=> $b} @catnum);
if ($resp->is_success) {
    unless ($self->{_content_type}) {
	$self->{_content_type} = 'orbit';
	$resp->push_header (pragma => 'spacetrack-type = orbit');
	}
    $self->_dump_headers ($resp) if $self->{dump_headers};
    }
return wantarray ? ($resp, \@data) : $resp;
}

#	_mutate_attrib takes the name of an attribute and the new value
#	for the attribute, and does what its name says.

sub _mutate_attrib {$_[0]{$_[1]} = $_[2]}

#	_mutate_cookie sets the session cookie, in both the object and
#	the user agent's cookie jar.

sub _mutate_cookie {
$_[0]->{agent}->cookie_jar->set_cookie (0, SESSION_KEY, $_[2],
    SESSION_PATH, DOMAIN, undef, 1, undef, undef, 1, {});
goto &_mutate_attrib;
}

#	_mutate_number croaks if the value to be set is not numeric.
#	Otherwise it sets the value. Only unsigned integers pass.

sub _mutate_number {
$_[2] =~ m/\D/ and croak <<eod;
Attribute $_[1] must be set to a numeric value.
eod
goto &_mutate_attrib;
}


#	_no_such_catalog takes as arguments a source and catalog name,
#	and returns the appropriate HTTP::Response object based on the
#	current verbosity setting.

my %no_such_lead = (
    celestrak => "No such CelesTrak catalog as '%s'.",
    spacetrack => "No such Space Track catalog as '%s'.",
    );
sub _no_such_catalog {
my $self = shift;
my $source = lc shift;
my $catalog = shift;
$no_such_lead{$source} or return HTTP::Response->new (RC_NOT_FOUND,
	"No such data source as '$source'.\n");
my $lead = sprintf $no_such_lead{$source}, $catalog;
return HTTP::Response->new (RC_NOT_FOUND, "$lead\n")
    unless $self->{verbose};
my $resp = $self->names ($source);
return HTTP::Response->new (RC_NOT_FOUND,
    join '', "$lead Try one of:\n", $resp->content);
}

#	_parse_retrieve_args parses the retrieve() options off its
#	arguments, prefixes a reference to the resultant options
#	hash to the remaining arguments, and returns the resultant
#	list. If the first argument is a hash reference, it simply
#	returns its argument list, under the assumption that it
#	has already been called.

sub _parse_retrieve_args {
unless (ref ($_[0]) eq 'HASH') {
    my $opt = {};
    local @ARGV = @_;

    GetOptions ($opt, qw{descending end_epoch=s last5
	sort=s start_epoch=s}) or croak <<eod;
Error - Legal options are
  -descending (direction of sort)
  -end_epoch date
  -last5 (ignored if -start_epoch or -end_epoch specified)
  -sort type ('catnum' or 'epoch', with 'catnum' the default)
  -start_epoch date
with dates being either Perl times, or numeric year-month-day, with any
non-numeric character valid as punctuation.
eod
    @_ = ($opt, @ARGV);
    }
@_;
}

#	_post is just like _get, except for the method used. DO NOT use
#	this method in the login () method, or you get a bottomless
#	recursion.

sub _post {
my $self = shift;
my $path = shift;
{	# Single-iteration loop
    $self->{cookie_expires} > time () or do {
	my $resp = $self->login ();
	return $resp unless $resp->is_success;
	};
    my $resp = $self->{agent}->post ("http://@{[DOMAIN]}/$path", [@_]);
    $self->_dump_headers ($resp) if $self->{dump_headers};
    return $resp unless $resp->is_success;
    local $_ = $resp->content;
    m/login\.pl/i and do {
	$self->{cookie_expires} = 0;
	redo;
	};
    return $resp;
    }	# end of single-iteration loop
}

#	_source takes a filename, and returns the contents of the file
#	as a list. It dies if anything goes wrong.

sub _source {
my $self = shift;
wantarray or die <<eod;
Error - _source () called in scalar or no context. This is a bug.
eod
my $fn = shift or die <<eod;
Error - No source file name specified.
eod
my $fh = FileHandle->new ("<$fn") or die <<eod;
Error - Failed to open source file '$fn'.
        $!
eod
return <$fh>;
}

1;

__END__

=back

=head2 Attributes

The following attributes may be modified by the user to affect the
operation of the Astro::SpaceTrack object. The data type of each is
given in parentheses after the attribute name.

Boolean attributes are typically set to 1 for true, and 0 for false.

=over

=item addendum (text)

This attribute specifies text to add to the output of the banner()
method.

The default is an empty string.

=item banner (boolean)

This attribute specifies whether or not the shell() method should emit
the banner text on invocation.

The default is true (i.e. 1).

=item cookie_expires (number)

This attribute specifies the expiration time of the cookie. You should
only set this attribute with a previously-retrieved value, which
matches the cookie.

=item direct (boolean)

This attribute specifies that orbital elements should be fetched
directly from the redistributor if possible. At the moment the only
methods affected by this are celestrak() and spaceflight().

The default is false (i.e. 0).

=item filter (boolean)

If true, this attribute specifies that the shell is being run in filter
mode, and prevents any output to STDOUT except orbital elements -- that
is, if I found all the places that needed modification.

The default is false (i.e. 0).

=item max_range (number)

This attribute specifies the maximum size of a range of NORAD IDs to be
retrieved. Its purpose is to impose a sanity check on the use of the
range functionality.

The default is 500.

=item password (text)

This attribute specifies the Space-Track password.

The default is an empty string.

=item session_cookie (text)

This attribute specifies the session cookie. You should only set it
with a previously-retrieved value.

The default is an empty string.

=item username (text)

This attribute specifies the Space-Track username.

The default is an empty string.

=item verbose (boolean)

This attribute specifies verbose error messages.

The default is false (i.e. 0).

=item webcmd (string)

This attribute specifies a system command that can be used to launch
a URL into a browser. If specified, the 'help' command will append
a space and the search.cpan.org URL for the documentation for this
version of Astro::SpaceTrack, and spawn that command to the operating
system. You can use 'open' under Mac OS X, and 'start' under Windows.
Anyone else will probably need to name an actual browser.

=item with_name (boolean)

This attribute specifies whether the returned element sets should
include the common name of the body (three-line format) or not
(two-line format). It is ignored if the 'direct' attribute is true;
in this case you get whatever the redistributor provides.

The default is false (i.e. 0).

=back

=head1 ENVIRONMENT

The following environment variables are recognized by Astro::SpaceTrack.

=head2 SPACETRACK_OPT

If environment variable SPACETRACK_OPT is defined at the time an
Astro::SpaceTrack object is instantiated, it is broken on spaces,
and the result passed to the set command.

If you specify username or password in SPACETRACK_OPT and you also
specify SPACETRACK_USER, the latter takes precedence, and arguments
passed explicitly to the new () method take precedence over both.

=head2 SPACETRACK_USER

If environment variable SPACETRACK_USER is defined at the time an
Astro::SpaceTrack object is instantiated, the username and password
will be initialized from it. The value of the environment variable
should be the username followed by a slash ("/") and the password.

An explicit username and/or password passed to the new () method
overrides the environment variable, as does any subsequently-set
username or password.

=head1 EXECUTABLES

A couple specimen executables are included in this distribution:

=head2 SpaceTrack

This is just a wrapper for the shell () method.

=head2 SpaceTrackTk

This provides a Perl/Tk interface to Astro::SpaceTrack.

=head1 BUGS

This software is essentially a web page scraper, and relies on the
stability of the user interface to Space Track. The Celestrak
portion of the functionality relies on the presence of .txt files
named after the desired data set residing in the expected location.
The Human Space Flight portion of the functionality relies on the
stability of the layout of the relevant web pages.

This software has not been tested under a HUGE number of operating
systems, Perl versions, and Perl module versions. It is rather likely,
for example, that the module will die horribly if run with an
insufficiently-up-to-date version of LWP or HTML::Parser.

=head1 MODIFICATIONS

 0.003 26-Mar-2005 T. R. Wyant
   Initial release to CPAN.
 0.004 30-Mar-2005 T. R. Wyant
   Added file method, for local observing lists.
   Changed Content-Type header of spacetrack () response
     to text/plain. Used to be text/text.
   Manufactured pristine HTTP::Response for successsful
     login call.
   Added source method, for passing the contents of a file
     to the shell method
   Skip username and password prompts, and login and
     retrieval tests if environment variable
     AUTOMATED_TESTING is true and environment variable
     SPACETRACK_USER is undefined.
 0.005 02-Apr-2005 T. R. Wyant
   Proofread and correct POD.
 0.006 08-Apr-2005 T. R. Wyant
   Added search_id method.
   Made specimen scripts into installable executables.
   Add pseudo-tilde expansion to shell method.
 0.007 15-Apr-2005 T. R. Wyant
   Document attributes (under set() method)
   Have login return actual failure on HTTP error. Used
     to return 401 any time we did not get the cookie.
 0.008 19-Jul-2005 T. R. Wyant
   Consolidate dump code.
   Have file() method take open handle as arg.
   Modify cookie check.
   Add mutator, accessor for cookie_expires,
     session_cookie.
 0.009 17-Sep-2005 T. R. Wyant
   Only require Term::ReadLine and create interface if
   the shell() method actually called.
 0.010 14-Oct-2005 T. R. Wyant
   Added the 'direct' attribute, to fetch elements
   directly from celestrak. And about time, too.
 0.011 30-Oct-2005 T. R. Wyant
   Added 'Pragma: spacetrack-type = orbit' header to
   the response for those methods that return orbital
   elements, if the request in fact succeeded.
   Added content_type() method to check for the above.
   Played the CPANTS game.
   Added "All rights reserved." to copyright statement.
 0.012 04-Nov-2005 T. R. Wyant
   Added support for number ranges in retrieve(), to
   track support for these on www.space-track.org.
   Added max_range attribute for sanity checking.
 0.013 21-Nov-2005 T. R. Wyant
   Added spaceflight() method.
   Added "All rights reserved." to banner() output.
   Spiffed up the documentation.
 0.014 28-Jan-2006 T. R. Wyant
   Added filter attribute.
   Jocky the Term::ReadLine code yet again.
 0.015 01-Feb-2006 T. R. Wyant
   Added webcmd attribute, and use it in help().
 0.016 11-Feb-2006 T. R. Wyant
   Added content types 'help' and 'get', so -filter
   does not supress output.
   Added iridium_status, & content type 'iridium-status'.
 0.017 27-Apr-2006 T. R. Wyant
   Added retrieve() options.

=head1 ACKNOWLEDGMENTS

The author wishes to thank Dr. T. S. Kelso of
L<http://celestrak.com/> and the staff of L<http://www.space-track.org/>
(whose names are unfortunately unknown to me) for their co-operation,
assistance and encouragement.

=head1 AUTHOR

Thomas R. Wyant, III (F<wyant at cpan dot org>)

=head1 COPYRIGHT

Copyright 2005, 2006 by Thomas R. Wyant, III
(F<wyant at cpan dot org>). All rights reserved.

This module is free software; you can use it, redistribute it
and/or modify it under the same terms as Perl itself.

The data obtained by this module is provided subject to the Space
Track user agreement (L<http://www.space-track.org/perl/user_agreement.pl>).

This software is provided without any warranty of any kind, express or
implied. The author will not be liable for any damages of any sort
relating in any way to this software.

=cut
