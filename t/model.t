package main;

use 5.008;

use strict;
use warnings;

use Astro::Coord::ECI::Utils qw{ date2epoch };
use File::Basename qw{ basename };
use File::Glob qw{ bsd_glob };
use Test::More 0.88;	# Because of done_testing();

foreach my $fn ( bsd_glob( 't/data/vsop87*.???' ) ) {
    my $body = basename( $fn );
    my @parts = split qr< [.] >smx, $body, 2;
    $parts[0] = uc $parts[0];
    if ( $parts[1] =~ m/ \A ear \z /smxi ) {
	pop @parts;
    } else {
	$parts[1] = ucfirst lc $parts[1];
    }
    my $class = join '::', qw{ Astro Coord ECI }, @parts;

    require_ok $class
	or BAIL_OUT $@;

    open my $fh, '<', $fn
	or BAIL_OUT "Failed to open $fn: $!";

    while ( <$fh> ) {
	my ( $dt, @want ) = unpack 'A15(A14)6', $_;
	$dt =~ s/ \s /0/smxg;
	s/ \s+ //smxg for @want;
	$dt =~ m/ \A ( [0-9]{4} ) ( [0-9]{2} ) ( [0-9]{2} ) .
	( [0-9]{2} ) ( [0-9]{2} ) ( [0-9]{2} ) \z /smx
	    or next;
	my $time = date2epoch( $6, $5, $4, $3, $2 - 1, $1 - 1900 );
	my @got = map { sprintf '%.10f', $_ } $class->__model( $time );
	foreach my $inx ( 0 .. $#got ) {
	    cmp_ok abs( $got[$inx] - $want[$inx] ), '<', 2e-10,
	    "$body $dt [$inx]";
	}
    }

    close $fh;
}

done_testing;

1;

# ex: set textwidth=72 :
