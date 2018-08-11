package main;

use 5.008;

use strict;
use warnings;

use lib qw{ inc };
use My::Module::Test;	# Must load before Astro::Coord::ECI::VSOP87D

use constant CUTOFF	=> 'Meeus';

use Astro::Coord::ECI::VSOP87D::Sun;
use Test::More 0.88;	# Because of done_testing();
use Time::Local qw{ timegm };

{

    my $time = timegm( 0, 0, 0, 13, 9, 1992 );

    {
	package
	Astro::Coord::ECI::VSOP87D;

	use lib qw{ inc };
	use My::Module::Test;

	use Astro::Coord::ECI::Utils qw{ rad2deg };
	use Test::More 0.88;	# Because of done_testing();

	# UNDOCUMENTED AND SUBJECT TO CHANGE WITHOUT NOTICE
	my $cutoff_def =
	    Astro::Coord::ECI::VSOP87D::Sun->__model_definition(
	    'default_cutoff' )->{ main->CUTOFF() };

	my ( $L, $B, $R ) = __PACKAGE__->__model( $time,
	    cutoff_definition	=> $cutoff_def,
	);
	is_rad_deg $L, 19.907_372, 5, 'Ex 25b Earth L';
	note 'The result differs from Meeus by 0.001 seconds of arc';
	is_rad_deg $B, -0.000_179, 5, 'Ex 25b Earth B';
	note 'The result differs from Meeus by less than 0.001 seconds of arc';
	is_au_au   $R, 0.997_607_75, 6, 'Ex 25b Earth R';
	note 'The result differs from Meeus by 3e-8 AU';
    }

    my $sun = Astro::Coord::ECI::VSOP87D::Sun->new();
    $sun->cutoff( CUTOFF );

    $sun->dynamical( $time );

    my ( $ra, $dec, $rng ) = $sun->equatorial();

    is_rad_deg $ra,  198.378179, 5, 'Ex 25b Sun RA';
    note 'The result differs from Meeus by 0.001 seconds of right ascension';
    is_rad_deg $dec,  -7.783872, 5, 'Ex 25b Sun Decl';
    note 'The result differs from Meeus by 0.007 seconds of arc';
    is_km_au   $rng, 0.997_607_75, 6, 'Ex 25b Sun Rng';
    note 'The result differs from Meeus by 1e-7 AU';
}

done_testing;

1;

# ex: set textwidth=72 :
