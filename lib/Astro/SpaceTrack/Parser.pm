package Astro::SpaceTrack::Parser;

use strict;
use warnings;

# Author: Thomas R. Wyant, III (F<wyant at cpan dot org>)

# Copyright 2005, 2007, 2008, 2010 by Thomas R. Wyant, III

# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl 5.10.0. For more details, see the full
# text of the licenses in the directory LICENSES.

# This program is distributed in the hope that it will be useful, but
# without any warranty; without even the implied warranty of
# merchantability or fitness for a particular purpose.

# This entire package is private to the Astro::SpaceTrack module.
# In addition to the restrictions and disclaimers in that module,
# the author reserves the right to make any changes whatsoever
# to this module, up to and including deleting it altogether,
# without telling anyone.

use base qw{HTML::Parser};

use Carp;

our $VERSION = '0.045';

my %target = (
    table => {
	reset => sub {
	    my $self = shift;
	    $self->report_tags (qw{table tr th td});
	    $self->{_spacetrack_tables} = [];
	    return;
	},
	start_action => {
	    table => sub {
		my ($self, $tbl) = (shift, []);
		push @{$self->{_spacetrack_tables}}, $tbl;
		$self->{_spacetrack_this_table} = $tbl;
		return;
	    },
	    tr => sub {
		my ($self, $row) = (shift, []);
		push @{$self->{_spacetrack_this_table}}, $row;
		$self->{_spacetrack_this_row} = $row;
		return;
	    },
	    td => sub {
		my ($self, $cell) = (shift, []);
		push @{$self->{_spacetrack_this_row}}, $cell;
		$self->{_spacetrack_this_cell} = $cell;
		return;
	    },
	},
	end_action => {
	    table => sub {
		$_[0]{_spacetrack_this_table} = [];
		$_[0]{_spacetrack_this_row} = [];
		$_[0]{_spacetrack_this_cell} = [];
		return;
	    },
	    tr => sub {
		$_[0]{_spacetrack_this_row} = [];
		$_[0]{_spacetrack_this_cell} = [];
		return;
	    },
	    td => sub {
		$_[0]{_spacetrack_this_cell} = [];
		return;
	    },
	},
	text_action => sub {
	    push @{$_[0]{_spacetrack_this_cell}}, $_[1];
	    return;
	},
	post_process => sub {
	    my $self = shift;
	    foreach my $table (@{$self->{_spacetrack_tables}}) {
		foreach my $row (@$table) {
		    @$row = map {join ' ', @$_} @$row;
		}
	    }
	    return $self->{_spacetrack_tables};
	},
    }
);

$target{table}{start_action}{th} = $target{table}{start_action}{td};
$target{table}{end_action}{th} = $target{table}{end_action}{td};

sub new {
    my $class = shift;
    my $self = HTML::Parser->new (api_version => 3);
    bless $self, $class;
    $self->unbroken_text (1);
    $self->handler (start => \&_spacetrack_html_start, 'self,tagname,@attr');
    $self->handler (end => \&_spacetrack_html_end, 'self,tagname');
    $self->handler (text => \&_spacetrack_html_text, 'self,dtext');
    return $self;
}

# We're just a wrapper for the superclass' parse method.
sub parse_string {
    my ($self, $type, @args) = @_;
    $self->_spacetrack_reset ($type);
    $self->parse (@args);
    return $target{$type}{post_process}->($self);
}

####	sub parse_file {
####	my $self = shift;
####	my $type = shift;
####	$self->_spacetrack_reset ($type);
####	$self->SUPER::parse_file (@_);
####	$target{$type}{post_process}->($self);
####	}

sub _spacetrack_html_start {
    my $self = shift;
    ###print "<@_>\n";
    my $tag = shift;
    $self->{_spacetrack_start_action} and
	$self->{_spacetrack_start_action}{$tag}->($self);
    return;
}

sub _spacetrack_html_end {
    my $self = shift;
    my $tag = shift;
    ###print "</$tag>\n";
    $self->{_spacetrack_end_action} and
	$self->{_spacetrack_end_action}{$tag}->($self);
    return;
}

sub _spacetrack_html_text {
    my $self = shift;
    my $text = shift;
    $text =~ s/\s+$//sm;
    $text =~ s/^\s+//sm;
    ###print qq{"$text"\n};
    $text ne '' and $self->{_spacetrack_text_action}->($self, $text);
    return;
}

sub _spacetrack_reset {
    my $self = shift;
    my $type = shift;
    $target{$type} or croak "Parse type '$type' not implemented.";
    $self->{_spacetrack_start_action} = $target{$type}{start_action};
    $self->{_spacetrack_end_action} = $target{$type}{end_action};
    $self->{_spacetrack_text_action} = $target{$type}{text_action};
    $target{$type}{reset}->($self);
    return;
}

1;

# ex: set textwidth=72 :
