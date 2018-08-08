package Astro::Coord::ECI::VSOP87D::Sun;

use 5.008;

use strict;
use warnings;

use base qw{ Astro::Coord::ECI::Sun };

use Astro::Coord::ECI::VSOP87D qw{ cutoff time_set };

use Carp;

our $VERSION = '0.000_01';

sub __model {
    return ( ( 0 ) x 6 );
}

sub __model_definition {
    my ( undef, $key ) = @_;
    return {
	valid_cutoff	=> {
	    Meeus	=> 1,
	    full	=> 1,
	},
    }->{$key};
}

1;

__END__

=head1 NAME

Astro::Coord::ECI::VSOP87D::Sun - VSOP87D model of the position of the Sun

=head1 SYNOPSIS

 use Astro::Coord::ECI::VSOP87D::Sun;
 use Astro::Coord::ECI::Utils qw{ deg2rad };
 use POSIX qw{ strftime };
 use Time::Local qw{ localtime };
 
 my $station = Astro::Coord::ECI->new(
     name => 'White House',
 )->geodetic(
     deg2rad( 38.899 ),  # radians
     deg2rad( -77.038 ), # radians
     16.68/1000,         # Kilometers
 );
 my $sun = Astro::Coord::ECI::VSOP87D::Sun->new(
     station => $station,
 );
 my $today = timelocal( 0, 0, 0, ( localtime )[ 3 .. 5 ] );
 foreach my $item ( $sun->almanac( $today, $today + 86400 ) ) {
     local $\ = "\n";
     print strftime( '%d-%b-%Y %H:%M:%S', localtime $item->[0] ),
         $item->[3];
 }

=head1 DESCRIPTION

This Perl class computes the position of the Sun using the VSOP87D
model. It is a subclass of
L<Astro::Coord::ECI::Sun|Astro::Coord::ECI::Sun>.

=head1 METHODS

This class supports the following public methods in addition to those of
its superclass:

=head2 cutoff

 say $self->cutoff()
 $self->cutoff( 25e-8 );

When called with an argument, this method is a mutator, changing the
cutoff value. When called without an argument, this method is an
accessor, returning the current cutoff value.

The cutoff value cuts off the calculation when the amplitude of the
terms becomes less than the given number, as suggested by Bretagnon and
Francou.  Meeus' abbreviated version of VSOP87D is roughly equivalent to
a cutoff of C<25e-8>, though he actually uses this cutoff only for the
L0 term.

The default is C<0>, which uses the full theory.

=head1 SEE ALSO

L<Astro::Coord::ECI::Sun|Astro::Coord::ECI::Sun>

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
