package Astro::Coord::ECI::VSOP87D;

use 5.008;

use strict;
use warnings;

use Astro::Coord::ECI::Utils qw{
    AU PI SECSPERDAY TWOPI
    asin deg2rad jcent2000 julianday
    load_module looks_like_number mod2pi
    rad2deg rad2dms rad2hms tan
};
use Exporter qw{ import };
use Carp;
use POSIX qw{ floor };
use Storable qw{ dclone };

use constant DAYS_PER_JULIAN_MILENNIUM	=> 365250;
use constant CODE_REF	=> ref sub {};
use constant HASH_REF	=> ref {};
use constant SUN_CLASS	=> __PACKAGE__ . '::Sun';

BEGIN {
    __PACKAGE__->can( 'DEBUG' )
	or constant->import( DEBUG => 0 );
}

our $VERSION = '0.000_01';

my @basic_export = qw{
    SUN_CLASS
    cutoff cutoff_definition order period time_set year
    __access_cutoff __get_attr __init __mutate_cutoff
};

our @EXPORT_OK = (
    @basic_export,
    qw{
	geometric_longitude
	nutation_iau1980
	__model
    },
);
our %EXPORT_TAGS = (
    mixin	=> [ @basic_export, qw{ __model } ],
    sun		=> [ @basic_export, qw{ geometric_longitude } ],
);

# We want to ensure SUN_CLASS is loaded because it is our default Sun
# implementation, but we do it at run time to avoid a circular
# dependency.
load_module( SUN_CLASS );

sub time_set {
    my ( $self ) = @_;
    my $attr = $self->__get_attr();
    my $time = $self->dynamical();
    my $cutoff = $self->cutoff();
    my $cutoff_def = $self->cutoff_definition();
    my $sun = $self->get( 'sun' );

    DEBUG
	and printf <<'EOD', ref $self, ref $sun, julianday( $time );

self = %s
Sun = %s
JDE = %.5f
EOD

    my $T = jcent2000( $time );

    my ( $Lb, $Bb, $Rb ) = $self->__model( $time,
	cutoff_definition	=> $cutoff_def,
    );

    my ( $Le, $Be, $Re );

    if ( $sun->isa( SUN_CLASS ) ) {
	# We call __model as a subroutine because the Earth's model
	# parameters are hung on the Sun, but if we call it as a method
	# we get the Sun's model, which always returns zeroes.
	( $Le, $Be, $Re ) = __model( SUN_CLASS, $time,
	    cutoff_definition	=> $sun->cutoff_definition( $cutoff ),
	);
    } else {
	confess sprintf 'TODO Sun class %s not supported', ref $sun;
    }

    DEBUG
	and printf <<'EOD', rad2deg( $Le ), rad2deg( $Be ), $Re;

Le = %.5f
Be = %.5f
Re = %.6f
EOD

    my ( $lambda, $beta, $Delta, $long_sym );
    if ( $Rb ) {		# Not the Sun

	my $last_tau = 0;

	while ( 1 ) {
	    DEBUG
		and printf <<'EOD', rad2deg( $Lb ), rad2deg( $Bb ), $Rb;

Lb = %.5f
Bb = %.5f
Rb = %.6f
EOD

	    # Meeus 33.1
	    my $cosBb = cos( $Bb );
	    my $cosBe = cos( $Be );
	    my $x = $Rb * $cosBb * cos( $Lb ) - $Re * $cosBe * cos( $Le );
	    my $y = $Rb * $cosBb * sin( $Lb ) - $Re * $cosBe * sin( $Le );
	    my $z = $Rb * sin( $Bb )          - $Re * sin( $Be );

	    $Delta = sqrt( $x * $x + $y * $y + $z * $z );

	    use constant TAU_FACTOR => 0.005_775_518_3 * SECSPERDAY;
	    my $tau = TAU_FACTOR * $Delta;

	    DEBUG
		and printf <<'EOD', $x, $y, $z, $Delta, $tau / SECSPERDAY;

x = %.6f
y = %.6f
z = %.6f
𝚫 = %.6f
𝛕 = %.7f day
EOD
	    if ( ( my $check = sprintf '%.1f', $tau ) ne $last_tau ) {
		$last_tau = $check;

		DEBUG
		    and printf <<'EOD', julianday( $time - $tau );

new JDE = %.5f
EOD
		( $Lb, $Bb, $Rb ) = $self->__model(
		    $time - $tau,
		    cutoff_definition	=> $cutoff_def,
		);
	    } else {

		# Meeus 33.2
		$lambda = mod2pi( atan2( $y, $x ) );
		$beta = atan2( $z, sqrt( $x * $x + $y * $y ) );
		$long_sym = '𝛌';
		last;
	    }
	}

	# Meeus corrects for aberration here for a planet, before
	# conversion to FK5. It makes no real difference to the answer,
	# since everything done to the latitude and longitude before
	# conversion to equatorial is just addition and subtraction, and
	# therefore commutes. But it plays merry Hell with the poor slob
	# who is trying to verify code versus the worked examples,
	# because it changes the intermediate results. Sigh.

	# Aberration per Meeus 23.2
	use constant CONSTANT_OF_ABERRATION	=> deg2rad(
	    20.49552 / 3600 );
	# Longitude of the Sun
	my $Ls = mod2pi( $Le + PI );
	# Eccentricity of the Earth's orbit
	my $e = ( - 0.000_000_126_7 * $T - 0.000_042_037 ) * $T +
	    0.016_708_634;
	# Longitude of perihelion of the Earth's orbit
	my $pi = deg2rad( ( 0.000_46 * $T + 1.71946 ) * $T + 102.93735 );

	my $delta_lambda = ( ( $e * cos( $pi - $lambda ) - cos( $Ls -
		    $lambda ) ) / cos $beta ) * CONSTANT_OF_ABERRATION;
	my $delta_beta = - sin( $beta ) * ( sin( $Ls - $lambda ) - $e *
	    sin( $pi - $lambda ) ) * CONSTANT_OF_ABERRATION;
	$lambda += $delta_lambda;
	$beta += $delta_beta;

	DEBUG
	    and printf <<'EOD',

Planetary aberration:
𝚫𝛌 = %s
𝛌 = %.5f
  = %s
𝚫𝛃 = %s
𝛃 = %.5f
  = %s
EOD
	rad2dms( $delta_lambda), rad2deg( $lambda ), rad2dms( $lambda ),
	rad2dms( $delta_beta), rad2deg( $beta ), rad2dms( $beta );


    } else {			# The Sun
	( $lambda, $beta, $Delta ) = ( mod2pi( $Le + PI ), - $Be, $Re );
	$long_sym = '☉';
    }

    DEBUG
	and printf <<'EOD',

%s = %.6f
𝛃 = %.6f
  = %s
𝚫 = %.6f
EOD
	$long_sym, rad2deg( $lambda ),
	rad2deg( $beta ), rad2dms( $beta ), $Delta;


    # Convert to FK5. Meeus says (ch. 25 pg 166) this is necessary for
    # high accuracy (though not if using his cutoff VSOP87D), though
    # Bretagnon & Francou seem to say it is needed only for VSOP87 and
    # VSOP87E.

    # Meeus 32.3
    {
	use constant DYN_TO_FK5_LINEAR	=> deg2rad( 1.397 );
	use constant DYN_TO_FK5_QUADRATIC	=> deg2rad( 0.00031 );
	use constant DYN_TO_FK5_DELTA_LON	=> - deg2rad( 0.09033 / 3600 );
	use constant DYN_TO_FK5_FACTOR	=> deg2rad( 0.03916 / 3600 );
	my $lambda_prime = $lambda - ( DYN_TO_FK5_LINEAR +
	    DYN_TO_FK5_QUADRATIC * $T ) * $T;
	my $factor = DYN_TO_FK5_FACTOR * ( cos( $lambda_prime ) - sin(
		$lambda_prime ) );
	my $delta_lambda = DYN_TO_FK5_DELTA_LON + $factor * tan( $beta );
	my $delta_beta = $factor;

	DEBUG and printf <<'EOD',

Conversion to FK5
𝛌' = %.2f
𝚫%s = %s
𝚫𝛃 = %s
EOD
	    rad2deg( $lambda_prime ), $long_sym,
	    rad2dms( $delta_lambda, 5 ), rad2dms( $delta_beta );

	$lambda += $delta_lambda;
	$beta += $delta_beta;

	DEBUG and printf <<'EOD',

%s = %.5f
  = %s
𝛃 = %.5f
  = %s
EOD
	    $long_sym, rad2deg( $lambda ), rad2dms( $lambda ),
	    rad2deg( $beta ), rad2dms( $beta ),
	    ;

	$attr->{geometric_longitude} = $lambda;
    }

    # Nutation
    my ( $delta_psi, $delta_eps ) = nutation_iau1980( $time, 3 );
    $lambda += $delta_psi;

    DEBUG
	and printf <<"EOD", rad2dms( $delta_psi ), rad2dms( $delta_eps );

Nutation:
𝚫𝛙 = %s
𝚫𝛆 = %s
EOD

    # Obliquity per Meeus 22.3
    my $U = $T / 100;
    my $epsilon_0 = 0;
    $epsilon_0 = $epsilon_0 * $U + $_ for qw{ 2.45 5.79 27.87 7.12
    -39.05 -249.67 -51.38 1999.25 -1.55 -4680.93 84381.448 };
    $epsilon_0 = deg2rad( $epsilon_0 / 3600 );
    my $epsilon = $epsilon_0 + $delta_eps;

    DEBUG
	and printf <<"EOD",

Obliquity:
𝛆₀ = %.7f
𝛆 = %.7f
  = %s
EOD
	rad2deg( $epsilon_0 ), rad2deg( $epsilon ), rad2dms( $epsilon );

    # Meeus 25.10

    unless ( $Rb ) {	# The Sun.
	# Aberration
	use constant SOLAR_ABERRATION_FACTOR => - deg2rad( 20.4898 / 3600 );
	my $delta_lambda = SOLAR_ABERRATION_FACTOR / $Delta;
	$lambda += $delta_lambda;

	DEBUG
	    and printf <<'EOD',

Solar aberration:
𝚫𝛌 = %s
𝛌 = %.5f
  = %s
EOD
	rad2dms( $delta_lambda), rad2deg( $lambda ), rad2dms( $lambda );
    }

    DEBUG
	and printf <<'EOD', $long_sym,

Final ecliptic coordinates:
%s = %.5f
  = %s
𝛃 = %.5f
  = %s
EOD
	rad2deg( $lambda ), rad2dms( $lambda ),
	rad2deg( $beta ), rad2dms( $beta );

    my $sin_eps = sin $epsilon;
    my $cos_eps = cos $epsilon;
    my $sin_lam = sin $lambda;
    my $sin_bet = sin $beta;
    my $cos_bet = cos $beta;
    my $alpha = mod2pi( atan2(
	    $sin_lam * $cos_eps - $sin_bet / $cos_bet * $sin_eps,
	    cos $lambda ) );	# Meeus 13.3
    my $delta = asin( $sin_bet * $cos_eps + $cos_bet * $sin_eps *
	$sin_lam );	# Meeus 13.4

    DEBUG
	and printf <<'EOD',

Equatorial coordinates:
𝛂 = %.6f
  = %s
𝛅 = %.6f
  = %s
EOD
	rad2deg( $alpha ), rad2hms( $alpha ),
	rad2deg( $delta ), rad2dms( $delta, 2 );

    $self->equatorial( $alpha, $delta, $Delta * AU );
    $self->equinox_dynamical( $time );

    if ( DEBUG ) {
	my ( $lat, $lon ) = $self->ecliptic();
	printf <<'EOD', $long_sym,

Check -- recovered ecliptic coordinates:
%s = %.5f
  = %s
𝛃 = %.5f
  = %s
EOD
	    rad2deg( $lon ), rad2dms( $lon ),
	    rad2deg( $lat ), rad2dms( $lat );
    }

    return $self;
}

sub geometric_longitude {
    my ( $self ) = @_;
    my $attr = $self->__get_attr();
    defined $attr->{geometric_longitude}
	and return $attr->{geometric_longitude};
    croak 'Geometric longitude undefined -- time not set';
}

BEGIN {
    my @model = (

	# The following are from the IAU SOFA module src/nut80.c, from
	# http://www.iausofa.org/2018_0130_C/sofa_c-20180130.tar.gz
	# The only edit is the change from curly to square brackets and
	# the brute-force conversion of C comments to Perl comments. The
	# columns are:
	#   IAU:  nl nlp  nf  nd nom  sp spt  ce cet
	# Meeus:  M'   M   F   D   𝛀
   # /* 1-10 */
      [  0,  0,  0,  0,  1, -171996.0, -174.2,  92025.0,    8.9 ],
      [  0,  0,  0,  0,  2,    2062.0,    0.2,   -895.0,    0.5 ],
      [ -2,  0,  2,  0,  1,      46.0,    0.0,    -24.0,    0.0 ],
      [  2,  0, -2,  0,  0,      11.0,    0.0,      0.0,    0.0 ],
      [ -2,  0,  2,  0,  2,      -3.0,    0.0,      1.0,    0.0 ],
      [  1, -1,  0, -1,  0,      -3.0,    0.0,      0.0,    0.0 ],
      [  0, -2,  2, -2,  1,      -2.0,    0.0,      1.0,    0.0 ],
      [  2,  0, -2,  0,  1,       1.0,    0.0,      0.0,    0.0 ],
      [  0,  0,  2, -2,  2,  -13187.0,   -1.6,   5736.0,   -3.1 ],
      [  0,  1,  0,  0,  0,    1426.0,   -3.4,     54.0,   -0.1 ],

   # /* 11-20 */
      [  0,  1,  2, -2,  2,    -517.0,    1.2,    224.0,   -0.6 ],
      [  0, -1,  2, -2,  2,     217.0,   -0.5,    -95.0,    0.3 ],
      [  0,  0,  2, -2,  1,     129.0,    0.1,    -70.0,    0.0 ],
      [  2,  0,  0, -2,  0,      48.0,    0.0,      1.0,    0.0 ],
      [  0,  0,  2, -2,  0,     -22.0,    0.0,      0.0,    0.0 ],
      [  0,  2,  0,  0,  0,      17.0,   -0.1,      0.0,    0.0 ],
      [  0,  1,  0,  0,  1,     -15.0,    0.0,      9.0,    0.0 ],
      [  0,  2,  2, -2,  2,     -16.0,    0.1,      7.0,    0.0 ],
      [  0, -1,  0,  0,  1,     -12.0,    0.0,      6.0,    0.0 ],
      [ -2,  0,  0,  2,  1,      -6.0,    0.0,      3.0,    0.0 ],

   # /* 21-30 */
      [  0, -1,  2, -2,  1,      -5.0,    0.0,      3.0,    0.0 ],
      [  2,  0,  0, -2,  1,       4.0,    0.0,     -2.0,    0.0 ],
      [  0,  1,  2, -2,  1,       4.0,    0.0,     -2.0,    0.0 ],
      [  1,  0,  0, -1,  0,      -4.0,    0.0,      0.0,    0.0 ],
      [  2,  1,  0, -2,  0,       1.0,    0.0,      0.0,    0.0 ],
      [  0,  0, -2,  2,  1,       1.0,    0.0,      0.0,    0.0 ],
      [  0,  1, -2,  2,  0,      -1.0,    0.0,      0.0,    0.0 ],
      [  0,  1,  0,  0,  2,       1.0,    0.0,      0.0,    0.0 ],
      [ -1,  0,  0,  1,  1,       1.0,    0.0,      0.0,    0.0 ],
      [  0,  1,  2, -2,  0,      -1.0,    0.0,      0.0,    0.0 ],

   # /* 31-40 */
      [  0,  0,  2,  0,  2,   -2274.0,   -0.2,    977.0,   -0.5 ],
      [  1,  0,  0,  0,  0,     712.0,    0.1,     -7.0,    0.0 ],
      [  0,  0,  2,  0,  1,    -386.0,   -0.4,    200.0,    0.0 ],
      [  1,  0,  2,  0,  2,    -301.0,    0.0,    129.0,   -0.1 ],
      [  1,  0,  0, -2,  0,    -158.0,    0.0,     -1.0,    0.0 ],
      [ -1,  0,  2,  0,  2,     123.0,    0.0,    -53.0,    0.0 ],
      [  0,  0,  0,  2,  0,      63.0,    0.0,     -2.0,    0.0 ],
      [  1,  0,  0,  0,  1,      63.0,    0.1,    -33.0,    0.0 ],
      [ -1,  0,  0,  0,  1,     -58.0,   -0.1,     32.0,    0.0 ],
      [ -1,  0,  2,  2,  2,     -59.0,    0.0,     26.0,    0.0 ],

   # /* 41-50 */
      [  1,  0,  2,  0,  1,     -51.0,    0.0,     27.0,    0.0 ],
      [  0,  0,  2,  2,  2,     -38.0,    0.0,     16.0,    0.0 ],
      [  2,  0,  0,  0,  0,      29.0,    0.0,     -1.0,    0.0 ],
      [  1,  0,  2, -2,  2,      29.0,    0.0,    -12.0,    0.0 ],
      [  2,  0,  2,  0,  2,     -31.0,    0.0,     13.0,    0.0 ],
      [  0,  0,  2,  0,  0,      26.0,    0.0,     -1.0,    0.0 ],
      [ -1,  0,  2,  0,  1,      21.0,    0.0,    -10.0,    0.0 ],
      [ -1,  0,  0,  2,  1,      16.0,    0.0,     -8.0,    0.0 ],
      [  1,  0,  0, -2,  1,     -13.0,    0.0,      7.0,    0.0 ],
      [ -1,  0,  2,  2,  1,     -10.0,    0.0,      5.0,    0.0 ],

   # /* 51-60 */
      [  1,  1,  0, -2,  0,      -7.0,    0.0,      0.0,    0.0 ],
      [  0,  1,  2,  0,  2,       7.0,    0.0,     -3.0,    0.0 ],
      [  0, -1,  2,  0,  2,      -7.0,    0.0,      3.0,    0.0 ],
      [  1,  0,  2,  2,  2,      -8.0,    0.0,      3.0,    0.0 ],
      [  1,  0,  0,  2,  0,       6.0,    0.0,      0.0,    0.0 ],
      [  2,  0,  2, -2,  2,       6.0,    0.0,     -3.0,    0.0 ],
      [  0,  0,  0,  2,  1,      -6.0,    0.0,      3.0,    0.0 ],
      [  0,  0,  2,  2,  1,      -7.0,    0.0,      3.0,    0.0 ],
      [  1,  0,  2, -2,  1,       6.0,    0.0,     -3.0,    0.0 ],
      [  0,  0,  0, -2,  1,      -5.0,    0.0,      3.0,    0.0 ],

   # /* 61-70 */
      [  1, -1,  0,  0,  0,       5.0,    0.0,      0.0,    0.0 ],
      [  2,  0,  2,  0,  1,      -5.0,    0.0,      3.0,    0.0 ],
      [  0,  1,  0, -2,  0,      -4.0,    0.0,      0.0,    0.0 ],
      [  1,  0, -2,  0,  0,       4.0,    0.0,      0.0,    0.0 ],
      [  0,  0,  0,  1,  0,      -4.0,    0.0,      0.0,    0.0 ],
      [  1,  1,  0,  0,  0,      -3.0,    0.0,      0.0,    0.0 ],
      [  1,  0,  2,  0,  0,       3.0,    0.0,      0.0,    0.0 ],
      [  1, -1,  2,  0,  2,      -3.0,    0.0,      1.0,    0.0 ],
      [ -1, -1,  2,  2,  2,      -3.0,    0.0,      1.0,    0.0 ],
      [ -2,  0,  0,  0,  1,      -2.0,    0.0,      1.0,    0.0 ],

   # /* 71-80 */
      [  3,  0,  2,  0,  2,      -3.0,    0.0,      1.0,    0.0 ],
      [  0, -1,  2,  2,  2,      -3.0,    0.0,      1.0,    0.0 ],
      [  1,  1,  2,  0,  2,       2.0,    0.0,     -1.0,    0.0 ],
      [ -1,  0,  2, -2,  1,      -2.0,    0.0,      1.0,    0.0 ],
      [  2,  0,  0,  0,  1,       2.0,    0.0,     -1.0,    0.0 ],
      [  1,  0,  0,  0,  2,      -2.0,    0.0,      1.0,    0.0 ],
      [  3,  0,  0,  0,  0,       2.0,    0.0,      0.0,    0.0 ],
      [  0,  0,  2,  1,  2,       2.0,    0.0,     -1.0,    0.0 ],
      [ -1,  0,  0,  0,  2,       1.0,    0.0,     -1.0,    0.0 ],
      [  1,  0,  0, -4,  0,      -1.0,    0.0,      0.0,    0.0 ],

   # /* 81-90 */
      [ -2,  0,  2,  2,  2,       1.0,    0.0,     -1.0,    0.0 ],
      [ -1,  0,  2,  4,  2,      -2.0,    0.0,      1.0,    0.0 ],
      [  2,  0,  0, -4,  0,      -1.0,    0.0,      0.0,    0.0 ],
      [  1,  1,  2, -2,  2,       1.0,    0.0,     -1.0,    0.0 ],
      [  1,  0,  2,  2,  1,      -1.0,    0.0,      1.0,    0.0 ],
      [ -2,  0,  2,  4,  2,      -1.0,    0.0,      1.0,    0.0 ],
      [ -1,  0,  4,  0,  2,       1.0,    0.0,      0.0,    0.0 ],
      [  1, -1,  0, -2,  0,       1.0,    0.0,      0.0,    0.0 ],
      [  2,  0,  2, -2,  1,       1.0,    0.0,     -1.0,    0.0 ],
      [  2,  0,  2,  2,  2,      -1.0,    0.0,      0.0,    0.0 ],

   # /* 91-100 */
      [  1,  0,  0,  2,  1,      -1.0,    0.0,      0.0,    0.0 ],
      [  0,  0,  4, -2,  2,       1.0,    0.0,      0.0,    0.0 ],
      [  3,  0,  2, -2,  2,       1.0,    0.0,      0.0,    0.0 ],
      [  1,  0,  2, -2,  0,      -1.0,    0.0,      0.0,    0.0 ],
      [  0,  1,  2,  0,  1,       1.0,    0.0,      0.0,    0.0 ],
      [ -1, -1,  0,  2,  1,       1.0,    0.0,      0.0,    0.0 ],
      [  0,  0, -2,  0,  1,      -1.0,    0.0,      0.0,    0.0 ],
      [  0,  0,  2, -1,  2,      -1.0,    0.0,      0.0,    0.0 ],
      [  0,  1,  0,  2,  0,      -1.0,    0.0,      0.0,    0.0 ],
      [  1,  0, -2, -2,  0,      -1.0,    0.0,      0.0,    0.0 ],

   # /* 101-106 */
      [  0, -1,  2,  0,  1,      -1.0,    0.0,      0.0,    0.0 ],
      [  1,  1,  0, -2,  1,      -1.0,    0.0,      0.0,    0.0 ],
      [  1,  0, -2,  2,  0,      -1.0,    0.0,      0.0,    0.0 ],
      [  2,  0,  0,  2,  0,       1.0,    0.0,      0.0,    0.0 ],
      [  0,  0,  2,  4,  2,      -1.0,    0.0,      0.0,    0.0 ],
      [  0,  1,  0,  1,  0,       1.0,    0.0,      0.0,    0.0 ]
    );

    # UNDOCUMENTED AND UNSUPPORTED -- MAY BE CHANGED OR REVOKED WITHOUT
    # WARNING
    # Return the IAU 1980 nutation model, as array references. Each
    # reference contains one term of the model, in the following order
    # in Meeus' terminology:
    # M' M F D Omega delta psi( const, T ), delta # epsilon( const, T ).
    sub __iau1980_nutation_model {
	return @model;
    }

    sub nutation_iau1980 {
	my ( $time, $cutoff ) = @_;
	$cutoff ||= 0;	# milli arc seconds. Meeus is 3
	my $T = jcent2000( $time );	# Meeus 22.1

	# All this from Meeus Ch 22 pp 143ff, expressed in degrees

	# Mean elongation of Moon from Sun
	my $D = ( ( $T / 189_474 - 0.001_914_2 ) * $T + 445_267.111_480
	    ) * $T + 297.850_36;

	# Mean anomaly of the Sun (Earth)
	my $M = ( ( - $T / 300_000 - 0.000_160_3 ) * $T + 35_999.050_340
	    ) * $T + 357.527_72;

	# Mean anomaly of the Moon
	my $M_prime = ( ( $T / 56_250 + 0.008_697_2 ) * $T + 477_198.867_398
	    ) * $T + 134.962_98;

	# Moon's argument of latitude
	my $F = ( ( $T / 327_270 - 0.003_682_5 ) * $T + 483_202.017_538
	    ) * $T + 93.271_91;

	# Logitude of the ascending node of the Moon's mean orbit on the
	# ecliptic, measured from the equinox of the date
	my $Omega = ( ( $T / 450_000 + 0.002_070_8 ) * $T - 1_934.136_261
	    ) * $T + 125.044_52;

	# Convert to radians, and store in same order as model source
	my @arg = map { deg2rad( $_ ) } ( $M_prime, $M, $F, $D, $Omega );

	my ( $delta_psi, $delta_eps ) = ( 0, 0 );
	foreach my $row ( @model ) {
	    my $a = $arg[0] * $row->[0] + $arg[1] * $row->[1] +
	    $arg[2] * $row->[2] + $arg[3] * $row->[3] +
	    $arg[4] * $row->[4];
	    if ( $row->[5] && $cutoff <= abs $row->[5] ) {
		$delta_psi += ( $row->[6] * $T + $row->[5] ) * sin $a;
	    }
	    if ( $row->[7] && $cutoff <= abs $row->[7] ) {
		$delta_eps += ( $row->[8] * $T + $row->[7] ) * cos $a;
	    }

	}

	# The model computes nutations in milli arc seconds, but we
	# return them in radians
	return ( map { deg2rad( $_ / 3600_0000 ) } $delta_psi,
	    $delta_eps );
    }

}

sub __get_attr {
    my ( $self ) = @_;
    my $ref = ref $self
	or confess 'Can not call as static method';
    return $self->{$ref} ||= {
	cutoff	=> 'Meeus',
	cutoff_definition	=> dclone( $self->__model_definition(
		'default_cutoff' ) ),
    };
}

sub __init {
    my ( $self ) = @_;
    my $name = $self->__model_definition( 'body' );
    $self->set(
	name	=> $name,
	id	=> $name,
    );
    return;
}

# To hook into the Astro::Coord::ECI get()/set() machinery
sub __access_cutoff {
    my ( $self ) = @_;
    return $self->cutoff();
}

sub __mutate_cutoff {
    my ( $self, undef, $val ) = @_;
    $self->cutoff( $val );
    return $self;
}

sub cutoff {
    my ( $self, @arg ) = @_;
    my $attr = $self->__get_attr();
    if ( @arg ) {
	defined $arg[0]
	    or croak "cutoff must be defined";
	$self->cutoff_definition( $arg[0] )
	    or croak "cutoff '$arg[0]' is unknown";
	$attr->{cutoff} = $arg[0];
	return $self;
    } else {
	return $attr->{cutoff};
    }
}

sub cutoff_definition {
    my ( $self, $name, @arg ) = @_;
    defined $name
	or $name = $self->cutoff();
    my $attr = $self->__get_attr();
    if ( @arg ) {
	if ( defined( my $val = $arg[0] ) ) {
	    unless ( ref $val ) {
		looks_like_number( $val )
		    and $val !~ m/ \A Inf (?: inity )? | NaN \z /smx
		    or croak 'Scalar cutoff definition must be a number';
		my $num = $val;
		$val = sub {
		    my ( @model ) = @_;
		    my %cutoff;
		    foreach my $series ( @model ) {
			my $count = 0;
			foreach my $term ( @{ $series->{terms} } ) {
			    last if $term->[0] < $num;
			    $count++;
			}
			$count
			    and $cutoff{$series->{series}} = $count;
		    }
		    return \%cutoff;
		};
	    }
	    if ( CODE_REF eq ref $val ) {
		$val = $val->(
		    map { @{ $_ } } @{
			$self->__model_definition( 'model' ) }
		);
		$val->{name} = $name;
	    }
	    HASH_REF eq ref $val
		or croak 'The cutoff definition value must be a hash ref';
	    my $terms = $self->__model_definition(
		'default_cutoff')->{none};
	    foreach my $name ( keys %{ $val } ) {
		'name' eq $name
		    and next;
		exists $terms->{$name}
		    or croak "Series '$name' not in this model";
		$val->{$name} > $terms->{$name}
		    and croak "Series '$name' has only $terms->{$name} terms";
	    }
	    $attr->{cutoff_definition}{$name} = $val;
	} else {
	    $self->__model_definition( 'default_cutoff' )->{$name}
		and croak "You may not delete cutoff definition '$name'";
	    delete $attr->{cutoff_definition}{$name};
	}
	return $self;
    } else {
	return $attr->{cutoff_definition}{$name};
    }
}

# Static method
# Given dynamical time in seconds, return Ecliptic position in Ecliptic
# longitude (radians), Ecliptic latitude (radians), Range (AU) and 
# AU and velocity in AU/day
sub __model {
    my ( $self, $time, %arg ) = @_;

    DEBUG
	and printf <<'EOD',

__model:
    invocant: %s
    cutoff: %s
EOD
    $self,
    ( $arg{cutoff_definition} ?
	( $arg{cutoff_definition}{name} || '<anonymous>' ) :
	'<unspecified>' ),
    ;

    my $jm = jcent2000( $time ) / 10;	# Meeus 32.1
    my @p_vec;
    my @v_vec;
    foreach my $coord ( @{ $self->__model_definition( 'model' ) } ) {
	my $dT = my $exponent = 0;
	my $T = 1;
	my $pos = my $vel = 0;
	foreach my $series ( @{ $coord } ) {
	    my $limit = $arg{cutoff_definition} ?
		( $arg{cutoff_definition}{$series->{series}} || 0 ) :
		@{ $series->{terms} }
		or next;
	    --$limit;
	    foreach my $inx ( 0 .. $limit ) {
		my $term = $series->{terms}[$inx];
		my $u = $term->[1] + $term->[2] * $jm;
		my $cos_u = cos $u;
		$pos += $term->[0] * $cos_u * $T;
		my $sin_u = sin $u;
		$vel += $dT * $exponent * $term->[0] * $cos_u -
		    $T * $term->[0] * $term->[2] * $sin_u;
	    }
	    $dT = $T;
	    $exponent++;
	    $T *= $jm;
	}
	$vel /= DAYS_PER_JULIAN_MILENNIUM;	# units/millennium -> units/day
	push @p_vec, $pos;
	push @v_vec, $vel;
    }
    $p_vec[0] = mod2pi( $p_vec[0] );
    return ( @p_vec, @v_vec );
}

sub order {
    my ( $self ) = @_;
    return $self->__model_definition( 'order' );
}

# Calculate the period of the orbit. The orbital velocity in radians per
# Julian centutu is just the inverse of the coefficient of the constant
# L1 term -- that is, the A value of the one with B and C both zero,
# since that computes as A * cos( B + C * tau ) = A * cos( 0 ) = A
#
# So the tropical year is just TWOPI divided by this. But we want the
# Siderial year, so we have to add in the precession. I found no
# reference for this, but to a first approximation the additional angle
# to travel is the solar year times the rate of precession, and the
# siderial year is the solar year plus the additional distance divided
# by the orbital velocity.
#
# But this calculation is done when the model parameters are built, and
# period() just returns the resultant value.
#
# The rate of pecession is the IAU 2003 value, taken from fapa03.c.

sub period {
    my ( $self ) = @_;
    return $self->__model_definition( 'sidereal_period' );
}

sub year {
    my ( $self ) = @_;
    return $self->__model_definition( 'tropical_period' );
}

1;

__END__

=head1 NAME

Astro::Coord::ECI::VSOP87D - Implement the VSOP87D position model.

=head1 SYNOPSIS

 package My_Object;

 use base qw{ Astro::Coord::ECI };
 use Astro::Coord::ECI::VSOP87D qw{ :mixin };

 sub __model_definition {
     return [
         # VSOP87D coefficients as digested from the distro by
	 # tools/decode
     ];
 }

=head1 DESCRIPTION

This Perl module implements the VSOP87D model in a manner that is
consistent with the L<Astro::Coord::ECI|Astro::Coord::ECI> hierarchy.

To use this module, subclass a member of the
L<Astro::Coord::ECI|Astro::Coord::ECI> hierarchy and import
L<cutoff()|/cutoff> and L<time_set()|/time_set> from this module. You
must also provide a L<__model_definition()|/__model_definition>
method that returns the model parameters you wish to implement.

=head1 METHODS

This module does not implement a class, and is better regarded as a
mixin.  It supports the following methods, which are public and
exportable unless documented otherwise.

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

This method is exportable, either by name or via the C<:mixin> or
C<:sun> tags.

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

If the second argument is a scalar, it is expected to be a number, and a
cutoff is generated consisting of all terms whose coefficient (C<'A'> in
Meeus' terminology) is equal to or greater than the number.

If the second argument is a code reference, this code is expected to
return a reference to a valid cutoff hash as described two paragraphs
previously. Its arguments are the individual series hashes, extracted
from the model. Each hash will have the following keys:

=over

=item series

The name of the series (e.g. 'L0').

=item terms

An array reference containing the terms of the series.
Each term is a reference to an array containing in order, in Meeus'
terms, values C<'A'>, C<'B'>, and C<'C'>.

=back

This method is exportable, either by name or via the C<:mixin> or
C<:sun> tags.

=head2 geometric_longitude

This method returns the geometric longitude of the body. This is after
correction for aberration and light time (for bodies other than the Sun)
and conversion to FK5.

This method is exportable, either by name or via the C<:sun> tag.

=head2 nutation_iau1980

 my ( $delta_psi, $delta_epsilon ) =
     nutation_iau1980( $dynamical_time, $cutoff );

This subroutine (B<not> method) calculates the nutation in ecliptic
longitude (C<$delta_psi>) and latitude (C<$delta_epsilon>) at the given
dynamical time in seconds since the epoch (i.e. Perl time), according to
the IAU 1980 model. The C<$cutoff> argument is optional; if specified as
a number larger than C<0>, terms whose amplitudes are smaller than the
cutoff (in milli arc seconds) are ignored. The Meeus version of the
algorithm is specified by a value of C<3>. The default is C<0>.

The model itself comes from Meeus chapter 22. The model parameters were
not transcribed from that source, however, but were taken from the
source IAU C reference implementation of the algorithm, F<src/nut80.c>,
with the minimum modifications necessary to make the C code into Perl
code. This file is contained in
L<http://www.iausofa.org/2018_0130_C/sofa_c-20180130.tar.gz>.

This method is exportable by name.

=head2 order

 say 'Order from Sun: ', $self->order();

This method returns the order of the body from the Sun, with the Sun
itself being C<0>. The number C<3> is skipped, since that would
represent the Earth.

This method is exportable, either by name or via the C<:mixin> or
C<:sun> tags.

=head2 period

 $self->period()

This method returns the sidereal period of the object, calculated from
the coefficient of its first C<L1> term.

The algorithm is the author's, and is a first approximation. That is. it
is just the tropical period plus however long it takes the object to
cover the amount of precession during the tropical year.

This method is exportable, either by name or via the C<:mixin> or
C<:sun> tags.

=head2 time_set

 $self->time_set()

This method is not normally called by the user. It is called by
L<Astro::Coord::ECI|Astro::Coord::ECI> to compute the position once the
time has been set.

It returns the invocant.

This method is exportable, either by name or via the C<:mixin> or
C<:sun> tags.

=head2 year

 $self->year()

This method returns the tropical year of the object, calculated from
the coefficient of its first C<L1> term.

This method is exportable, either by name or via the C<:mixin> or
C<:sun> tags.

=head2 __get_attr

This static method is B<private> to this package, and may be changed or
revoked without notice at any time. Documentation is for the benefit of
the author.

This method returns the hash containing VSOP87D-specific attributes,
creating it if necessary.

This method is exportable, either by name or via the C<:mixin> or
C<:sun> tags.

=head2 __model

 my @state_vector = $class->__model( $time_dynamical, ... );

This static method is B<private> to this package, and may be changed or
revoked without notice at any time. Documentation is for the benefit of
the author.

This static method executes the VSOP87D model returned by
C<< $class->__model_definition() >>, and returns the computed state
vector. The components of the state vector are Cartesian X, Y, and Z in
kilometers, and the associated velocities in kilometers per second.

Additional optional arguments can be specified as name/value pairs. The
following are defined:

=over

=item cutoff

This is the cutoff value. Terms whose amplitudes are less than this
value are not used. The default is C<0>.

=item debug

If this Boolean argument is true, whatever debug data the author finds
useful at the moment is written to standard error.

=back

This method is exportable, either by name or via the C<:mixin> tag. It
is not exported by the C<:sun> tag.

=head2 __model_definition

 my $model = $class->__model_definition( 'model' )

This static method is B<private> to this package, and may be changed or
revoked without notice at any time. Documentation is for the benefit of
the author.

This static method returns model-related information. The argument
describes the information to return. The following are valid:

=over

=item default_cutoff

This argument returns the default value of C<'cutoff_definition'> for a
new object.

=item model

This argument returns the terms of the VSOP87D model, expressed as
nested array references.

The top level is indexed on the zero-based coordinate index (i.e. one
less than the indices documented in F<vsop87.txt>. The next level is
indexed on the exponent of C<T> represented, and is expected to be in
the range C<0-5>.

The third level is a hash describing the individual series. It contains
the following keys:

=over

=item series

This is the name of the individual series (e.g. C<'L0'>.

=item terms

This is a reference to an array containing the terms of the series.
Each term is a reference to an array containing quantities A, B, and C
to be plugged into the equation C<A * cos( B + C * T) * T ** n>.

C<T> is dynamical time in Julian millennia since J2000.0.

=back

=item sidereal_period

This is the sidereal period in seconds, and is returned by period().
=back

=item tropical_period

This is the tropical period, in seconds. As of this writing it is
unused.

=back

This method is B<not> exportable. It is expected that each derived class
will implement its own version of this method.

=head1 SEE ALSO

L<Astro::Coord::ECI|Astro::Coord::ECI>

L<https://www.caglow.com/info/compute/vsop87>

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

Software Routines from the IAU SOFA Collection were used. Copyright (C)
International Astronomical Union Standards of Fundamental Astronomy
(L<http://www.iausofa.org>)

=cut

# ex: set textwidth=72 :
