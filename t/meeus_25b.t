package main;

use 5.008;

use strict;
use warnings;

use constant CUTOFF	=> 'Meeus';

BEGIN {
    constant->import(
	'Astro::Coord::ECI::VSOP87D::DEBUG' => $ENV{VSOP87D_DEBUG} );
}

use Astro::Coord::ECI::VSOP87D::Sun;
use Astro::Coord::ECI::VSOP87D::Venus;
use Astro::Coord::ECI::Utils qw{ AU deg2rad rad2deg };
use POSIX qw{ floor };
use Test::More 0.88;	# Because of done_testing();
use Time::Local qw{ timegm };

{

    my $time = timegm( 0, 0, 0, 13, 9, 1992 );

    {
	package
	Astro::Coord::ECI::VSOP87D;

	use Astro::Coord::ECI::Utils qw{ AU rad2deg };
	use Test::More 0.88;	# Because of done_testing();

	my ( $L, $B, $R ) = __PACKAGE__->__model( $time,
	    cutoff	=> main->CUTOFF,
	);
	is sprintf( '%.4f', rad2deg( $L ) ), '19.9074', 'Ex 25b Earth L';
	is sprintf( '%.4f', rad2deg( $B ) ), '-0.0002', 'Ex 25b Earth B';
	is sprintf( '%.5f', $R ), '0.99761', 'Ec 25b Earth R';
    }

    my $sun = Astro::Coord::ECI::VSOP87D::Sun->new();
    $sun->cutoff( CUTOFF );

    $sun->dynamical( $time );

    my ( $ra, $dec, $rng ) = $sun->equatorial();

    is sprintf( '%.4f', rad2deg( $ra ) ), '198.3782', 'Ex 25b Sun RA';
    is sprintf( '%.4f', rad2deg( $dec ) ), '-7.7839', 'Ex 25b Sun Decl';
    is sprintf( '%.5f', $rng / AU ), '0.99761', 'Ex 25b Sun Rng';
}

done_testing;

1;

# ex: set textwidth=72 :
