package main;

use strict;
use warnings;

# We have to load Astro::Coord::ECI::Sun explicitly so we can turn off
# Singleton.
use Astro::Coord::ECI::Sun;
use Test::More 0.88;

# TODO remove this once we have the updated singleton logic.
local $Astro::Coord::ECI::Sun::Singleton = 0;

my $body;

require_ok 'Astro::Coord::ECI::VSOP87D'
    or BAIL_OUT $@;

foreach my $name ( qw{ Sun Venus } ) {
    my $class = "Astro::Coord::ECI::VSOP87D::$name";

    require_ok $class
	or BAIL_OUT $@;

    my $body = eval { $class->new() };
    isa_ok $body, $class
	or BAIL_OUT $@;

    is $body->get( 'name' ), $name, qq<Body name is '$name'>;

    is $body->get( 'cutoff' ), 'Meeus', qq<Default $name cutoff is 'Meeus'>;

}

done_testing;

1;
