package main;

use 5.008;

use strict;
use warnings;

use constant CUTOFF	=> 'Meeus';

BEGIN {
    constant->import(
	'Astro::Coord::ECI::VSOP87D::DEBUG' => $ENV{VSOP87D_DEBUG} );
}

use Astro::Coord::ECI::VSOP87D::Venus;
use Astro::Coord::ECI::Utils qw{ AU deg2rad rad2deg };
use POSIX qw{ floor };
use Test::More 0.88;	# Because of done_testing();
use Time::Local qw{ timegm };

{
    my $time = timegm( 0, 0, 0, 20, 11, 1992 );
    my $venus = Astro::Coord::ECI::VSOP87D::Venus->new();
    $venus->cutoff( CUTOFF );

    my ( $L, $B, $R ) = $venus->__model(
	$time,
	cutoff	=> CUTOFF,
    );
    is sprintf( '%.4f', rad2deg( $L ) ), '26.1143', 'Ex 33a Venus L';
    is sprintf( '%.4f', rad2deg( $B ) ), '-2.6207', 'Ex 33a Venus B';
    is sprintf( '%.5f', $R ), '0.72460', 'Ec 32a Venus R';

    $venus->dynamical( $time );
    my ( $ra, $dec, $rng ) = $venus->equatorial();
}

done_testing;

1;

# ex: set textwidth=72 :
