package Astro::Coord::ECI::VSOP87D::Sun;

use 5.008;

use strict;
use warnings;

use base qw{ Astro::Coord::ECI::Sun };

use Astro::Coord::ECI::Mixin qw{ next_quarter };

use Astro::Coord::ECI::VSOP87D qw{ :sun };

use Carp;

our $VERSION = '0.000_01';

sub __model {
    return ( ( 0 ) x 6 );
}

sub __model_definition {
    my ( undef, $key ) = @_;
    return {
          'default_cutoff' => {
                                'Meeus' => {
                                             'B0' => 5,
                                             'B1' => 1,
                                             'L0' => 64,
                                             'L1' => 34,
                                             'L2' => 20,
                                             'L3' => 7,
                                             'L4' => 3,
                                             'L5' => 1,
                                             'R0' => 40,
                                             'R1' => 10,
                                             'R2' => 6,
                                             'R3' => 3,
                                             'R4' => 1,
                                             'name' => 'Meeus',
                                           },
                                'none' => {
                                            'B0' => '184',
                                            'B1' => '99',
                                            'B2' => '49',
                                            'B3' => '11',
                                            'B4' => '5',
                                            'L0' => '559',
                                            'L1' => '341',
                                            'L2' => '142',
                                            'L3' => '22',
                                            'L4' => '11',
                                            'L5' => '5',
                                            'R0' => '526',
                                            'R1' => '292',
                                            'R2' => '139',
                                            'R3' => '27',
                                            'R4' => '10',
                                            'R5' => '3',
                                            'name' => 'none',
                                          },
                              },
          'name' => 'VSOP87D',
          'sidereal_period' => '31558149.764',
          'tropical_period' => '31556925.183',
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
 $self->cutoff( 'Meeus' );

When called with an argument, this method is a mutator, changing the
cutoff value. When called without an argument, this method is an
accessor, returning the current cutoff value.

The cutoff value specifies how to truncate the calculation. Valid values
are:

=over

=item C<'none'> specifies no cutoff (i.e. the full series);

=item C<'Meeus'> specifies the Meeus Appendix III series.

=back

The default is C<'Meeus'>.

=head2 cutoff_definition

This method reports, creates, and deletes cutoff definitions.

The first argument is the name of the cutoff. If this is the only
argument, a reference to a hash defining the named cutoff is returned.
This return is a deep clone of the actual definition.

If the second argument is C<undef>, the named cutoff is deleted. If the
cutoff does not exist, the call does nothing. It is an error to try to
delete built-in cutoffs C<'none'> and C<'Meeus'>.

If the second argument is a reference to a hash, this defines or
redefines a cutoff. The keys to the hash are the names of VSOP87D series
(C<'L0'> through C<'L5'>, C<'B0'> through C<'B5'>, and C<'R0'> through
C<'R5'>), and the value of each key is the number of terms of that
series to use. If one of the keys is omitted or has a false value, that
series is not used.

=head2 next_quarter

This override of the superclass' method ignores the value of the
C<'iterate_for_quarters'> attribute, and always iterates. The superclass
uses an algorithm from Meeus if this attribute is false.

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
