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

require_ok 'Astro::Coord::ECI::VSOP87D::Sun'
    or BAIL_OUT $@;

$body = eval { Astro::Coord::ECI::VSOP87D::Sun->new() };
isa_ok $body, 'Astro::Coord::ECI::VSOP87D::Sun'
    or BAIL_OUT $@;

is $body->get( 'name' ), 'Sun', q<Body name is 'Sun'>;

is $body->get( 'cutoff' ), 'Meeus', q<Default Sun cutoff is 'Meeus'>;

require_ok 'Astro::Coord::ECI::VSOP87D::Venus'
    or BAIL_OUT $@;

$body = eval { Astro::Coord::ECI::VSOP87D::Venus->new() };
isa_ok $body, 'Astro::Coord::ECI::VSOP87D::Venus'
    or BAIL_OUT $@;

is $body->get( 'name' ), 'Venus', q<Body name is 'Venus'>;

is $body->get( 'cutoff' ), 'Meeus', q<Default Venus cutoff is 'Meeus'>;

done_testing;

1;
