package Astro::Coord::ECI::VSOP87D::_Inferior;

use 5.008;

use strict;
use warnings;

use base qw{ Astro::Coord::ECI };

use Astro::Coord::ECI::Mixin qw{
    almanac almanac_hash
    next_quarter_hash
};
use Astro::Coord::ECI::Utils qw{ PI find_first_true mod2pi };
use Astro::Coord::ECI::VSOP87D qw{ :mixin };
use Carp;

our $VERSION = '0.000_01';

sub __almanac_event_type_iterator {
    my ( $self, $station ) = @_;

    my $inx = 0;

    my $horizon = $station->__get_almanac_horizon();

    my @events = (
	[ $station, next_elevation => [ $self, $horizon, 1 ],
	    horizon	=> '__horizon_name' ],
	[ $station, next_meridian => [ $self ],
	    transit	=> '__transit_name' ],
	[ $self, next_quarter => [], 'quarter', '__quarter_name' ],
    );

    return sub {
	$inx < @events
	    and return @{ $events[$inx++] };
	return;
    };
}

# TODO this probably gets promoted to VSOP87D, exported by :mixin
{
    my $earth;

    sub __angle_subtended_from_earth {
	my ( $self, $time ) = @_;
	$earth ||= Astro::Coord::ECI->new()->eci( 0, 0, 0 );
	$self->universal( $time );
	my $sun = $self->get( 'sun' )->universal( $time );
	$earth->universal( $time );
	return $earth->angle( $self, $sun );
    }
}

{
    my $get = sub {
	my ( $self, $name ) = @_;
	return $self->__get_attr()->{$name};
    };

    my %accessor = (
	elongation_in_longitude	=> $get,
	model_cutoff		=> $get,
	nutation_cutoff		=> $get,
    );

    sub attribute {
	my ( $self, $name ) = @_;
	exists $accessor{$name}
	    and return __PACKAGE__;
	return $self->SUPER::attribute( $name );
    }

    sub get {
	my ( $self, @arg ) = @_;
	my @rslt;
	foreach my $name ( @arg ) {
	    if ( my $code = $accessor{$name} ) {
		push @rslt, $code->( $self, $name );
	    } else {
		push @rslt, $self->SUPER::get( $name );
	    }
	    wantarray
		or return $rslt[0];
	}
	return @rslt;
    }
}

# TODO this probably gets promoted to VSOP87D, exported by :mixin
{
    my @default_name = (
	'%s set',
	'%s rise',
    );

    sub __horizon_name {
	my ( $self, $event, $name ) = @_;
	$name ||= \@default_name;
	return sprintf $name->[$event], $self->get( 'name' );
    }
}

# TODO this probably gets promoted to VSOP87D, exported by :mixin
sub __longitude_from_sun {
    my ( $self, $time ) = @_;

    if ( defined $time ) {
	$self->universal( $time );
    } else {
	$time = $self->universal();
    }

    my $sun = $self->get( 'sun' )->universal( $time );

    my ( undef, $lon_b ) = $self->ecliptic();
    my ( undef, $lon_s ) = $sun->ecliptic();

    return mod2pi( $lon_b - $lon_s + PI ) - PI;
}

sub next_quarter {
    my ( $self, $quarter ) = @_;

    my $time = $self->universal();

    my $elong_method = $self->get( 'elongation_in_longitude' ) ?
	'__longitude_from_sun' :
	'__angle_subtended_from_earth';

    my $increment = $self->period() / 16;

    my @checker = (
	sub {	# 0 = superior conjunction
	    my ( $time ) = @_;
	    $self->__longitude_from_sun( $time ) > 0 ? 4 : 0;
	},
	sub {	# 1 = elongaton east
	    my ( $time ) = @_;
	    return $self->$elong_method( $time ) <
		$self->$elong_method( $time - 1 ) ? 1 : 0;
	},
	sub {	# 2 = inferior conjunction
	    my ( $time ) = @_;
	    $self->__longitude_from_sun( $time ) < 0 ? 2 : 0;
	},
	sub {	# 3 = elongaton west
	    my ( $time ) = @_;
	    return $self->$elong_method( $time ) >
		$self->$elong_method( $time - 1 ) ? 3 : 0;
	},
    );

    my $test;
    if ( defined $quarter ) {
	$test = $checker[$quarter];
	while ( $test->( $time ) ) {
	    $time += $increment;
	}
	while ( ! $test->( $time ) ) {
	    $time += $increment;
	}
    } else {
	my @chk = grep { ! $_->( $time ) } @checker
	    or confess 'Programming error - no false checks';
	my $rslt;
	while ( ! $rslt ) {
	    $time += $increment;
	    foreach my $c ( @chk ) {
		$rslt = $c->( $time )
		    and last;
	    }
	}
	$quarter = $rslt % 4;
	$test = $checker[$quarter];
    }

    my $rslt = find_first_true( $time - $increment, $time, $test );

    $self->universal( $rslt );

    wantarray
	or return $rslt;
    return( $rslt, $quarter, $self->__quarter_name( $quarter ) );
}

{
    my @default_name = (
	'%s superior conjunction',
	'%s elongation east',
	'%s inferior conjunction',
	'%s elongation west',
    );

    sub __quarter_name {
	my ( $self, $event, $name ) = @_;
	$name ||= \@default_name;
	return sprintf $name->[$event], $self->get( 'name' );
    }
}

{
    my $set = sub {
	my ( $self, $name, $value ) = @_;
	$self->__get_attr()->{$name} = $value;
	return $self;
    };

    my %mutator = (
	elongation_in_longitude	=> $set,
	model_cutoff		=> \&__mutate_model_cutoff,
	nutation_cutoff		=> \&__mutate_nutation_cutoff,
    );

    sub set {
	my ( $self, @arg ) = @_;
	while ( @arg ) {
	    my ( $name, $value ) = splice @arg, 0, 2;
	    if ( my $code = $mutator{$name} ) {
		$code->( $self, $name, $value );
	    } else {
		$self->SUPER::set( $name, $value );
	    }
	}
	return $self;
    }
}

# TODO this probably gets promoted to VSOP87D, exported by :mixin
{
    my @default_name = (
	undef,
	'%s transits meridian',
    );

    sub __transit_name {
	my ( $self, $event, $name ) = @_;
	$name ||= \@default_name;
	defined $name->[$event]
	    or return undef;	## no critic (ProhibitExplicitReturnUndef)
	return sprintf $name->[$event], $self->get( 'name' );
    }
}

1;

__END__

=head1 NAME

Astro::Coord::ECI::VSOP87D::_Inferior - VSOP87D inferior planets

=head1 SYNOPSIS

This abstract Perl class is not intended to be invoked directly by the
user.

=head1 DESCRIPTION

This abstract Perl class represents the VSOP87D model of an inferior
planet. It is a subclass of L<Astro::Coord::ECI|Astro::Coord::ECI>.

=head1 METHODS

This class supports the following public methods in addition to those
inherited from the superclass.

=head2 next_quarter

 my ( $time, $quarter, $desc ) = $body->next_quarter( $want );

This method calculates the time of the next quarter event after the
current time setting of the $body object. The return is the time, which
event it is as a number from 0 to 3, and a string describing the event.
If called in scalar context, you just get the time.

Quarters are defined as positions in the orbit, not phases. This is the
usage throughout the L<Astro::Coord::ECI|Astro::Coord::ECI> hierarchy,
even the Moon. The name C<'quarter'> seems ill-chosen, but it is
probably too late to do anything about it now.

Specifically, for inferior planets the quarters are:

 0 - superior conjunction
 1 - elongation east
 2 - inferior conjunction
 3 - elongation west

The optional $want argument says which event you want.

As a side effect, the time of the $body object ends up set to the
returned time.

The method of calculation is successive approximation, and actually
returns the second B<after> the calculated event.

This mixin makes use of the following methods:

=head1 ATTRIBUTES

This class has the following attributes in addition to those of its
superclass:

=head2 elongation_in_longitude

If this Boolean attribute is true, elongations are calculated in
ecliptic longitude. If it is false, elongations are in angle from the
Sun as seen from the Earth, regardless of direction.

The default is false.

=head2 model_cutoff

This attribute specifies how to truncate the calculation. Valid values
are:

=over

=item C<'none'> specifies no model cutoff (i.e. the full series);

=item C<'Meeus'> specifies the Meeus Appendix III series.

=back

The default is C<'Meeus'>.

=head2 nutation_cutoff

The nutation_cutoff value specifies how to truncate the nutation
calculation. All terms whose magnitudes are less than the nutation
cutoff are ignored. The value is in terms of 0.0001 seconds of arc, and
must be a non-negative number.

The default is C<3>, which is the value Meeus uses.

=head1 SEE ALSO

L<Astro::Coord::ECI|Astro::Coord::ECI>

L<Astro::Coord::ECI::VSOP87D|Astro::Coord::ECI::VSOP87D>

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
