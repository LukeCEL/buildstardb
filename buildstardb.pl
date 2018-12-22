#!/usr/bin/perl

# buildstardb.pl
#
# Builds the stars.dat and revised.stc files for Celestia
#
# Version 1.3 - LukeCEL (2018-12-18)

use Math::Trig;
use strict;

# default file paths
my $HIP_PATH  = 'hip_main.dat';
my $HIP2_PATH = 'hip2.dat';
my $SIMBAD_PATH = 'simbad.txt';
my $DAT_PATH  = 'stars.dat';
my $TXT_PATH  = 'stars.txt';

# by default turn spectral type guesser on
my $GUESS_TYPES = 1;

# some physical/astronomical constants
my $LY_PER_PARSEC = 3.26167; # taken from astro.h
my $J2000Obliquity = deg2rad(23.4392911);
my $cc = cos($J2000Obliquity);
my $ss = sin($J2000Obliquity);
my @eqToCel = (
	[1,   0,    0],
	[0, $cc, -$ss],
	[0, $ss,  $cc]
);

# B-V magnitudes and spectral types
# from Lang, K.  "Astrophysical Data: Planets and Stars"(1991)
my %SpBV = (
	'O5' => -0.33,
	'O8' => -0.32,
	'O9' => -0.31,
	'B0' => -0.30,
	'B1' => -0.265,
	'B2' => -0.24,
	'B3' => -0.205,
	'B5' => -0.17,
	'B6' => -0.15,
	'B7' => -0.135,
	'B8' => -0.11,
	'B9' => -0.075,
	'A0' => -0.02,
	'A1' => 0.01,
	'A2' => 0.05,
	'A3' => 0.08,
	'A5' => 0.15,
	'A7' => 0.20,
	'A8' => 0.25,
	'F0' => 0.30,
	'F2' => 0.35,
	'F5' => 0.44,
	'F8' => 0.52,
	'G0' => 0.58,
	'G2' => 0.63,
	'G5' => 0.68,
	'G8' => 0.74,
	'K0' => 0.81,
	'K1' => 0.86,
	'K2' => 0.91,
	'K3' => 0.96,
	'K5' => 1.15,
	'K7' => 1.33,
	'M0' => 1.40,
	'M1' => 1.46,
	'M2' => 1.49,
	'M3' => 1.51,
	'M4' => 1.54,
	'M5' => 1.64,
	'M6' => 1.73,
	'M7' => 1.80,
	'M8' => 1.93
);

# digit meanings for SpectralClass data type
my %SC_StarType = (
	'NormalStar' => 0x0000,
	'WhiteDwarf' => 0x1000,
	'NeutronStar' => 0x2000,
	'BlackHole' => 0x3000,
	'Mask' => 0xf000
);
my %SC_SpecClass = (
	'O' => 0x0000,
	'B' => 0x0100,
	'A' => 0x0200,
	'F' => 0x0300,
	'G' => 0x0400,
	'K' => 0x0500,
	'M' => 0x0600,
	'R' => 0x0700,
	'S' => 0x0800,
	'N' => 0x0900,
	'WC' => 0x0a00,
	'WN' => 0x0b00,
	'?' => 0x0c00,
	'L' => 0x0d00,
	'T' => 0x0e00,
	'C' => 0x0f00,
	'DA' => 0x0000,
	'DB' => 0x0100,
	'DC' => 0x0200,
	'DO' => 0x0300,
	'DQ' => 0x0400,
	'DZ' => 0x0500,
	'D' => 0x0600,
	'DX' => 0x0700,
	'Mask' => 0x0f00
);
my %SC_Subclass = (
	'0' => 0x0000,
	'1' => 0x0010,
	'2' => 0x0020,
	'3' => 0x0030,
	'4' => 0x0040,
	'5' => 0x0050,
	'6' => 0x0060,
	'7' => 0x0070,
	'8' => 0x0080,
	'9' => 0x0090,
	'?' => 0x00a0,
	'Mask' => 0x00f0
);
my %SC_LumClass = (
	'Ia0' => 0x0000,
	'Ia' => 0x0001,
	'Ib' => 0x0002,
	'II' => 0x0003,
	'III' => 0x0004,
	'IV' => 0x0005,
	'V' => 0x0006,
	'VI' => 0x0007,
	'?' => 0x0008,
	'Mask' => 0x000f
);

# data stored in these arrays
my %stars = (); # star details

ReadHipparcos();
ReadOldHipparcos();
ReadSimbad();
FixData();
CheckStars();
WriteDat();

# ---------------------------- END OF MAIN PROGRAM --------------------------- #

# --------------------------- INPUT/OUTPUT FUNCTIONS ------------------------- #

# Read the Astrometric Catalogue into associative array
sub ReadHipparcos
{
	print "Reading Astrometric Catalog...\n";

	local(*HIPFILE);
	if(!open(HIPFILE, '<', $HIP2_PATH))
	{
		print "  ERROR: Could not open $HIP2_PATH\n";
		return;
	}

	my $numStars = 0;
	while (my $curLine = <HIPFILE>)
	{
		chomp $curLine;

		my $HIP = Trim(substr($curLine, 0, 6));
		# note all entries are inserted into list in case subsequent
		# processing inserts missing properties.
		my %star = (
			'RAdeg'    => rad2deg(substr($curLine,  15, 13)),
			'DEdeg'    => rad2deg(substr($curLine,  29, 13)),
			'Plx'      => substr($curLine,  43,  7),
			'e_RAdeg'  => rad2deg(substr($curLine,  69,  6)),
			'e_DEdeg'  => rad2deg(substr($curLine,  76,  6)),
			'e_Plx'    => substr($curLine,  83,  6),
			'Hpmag'    => substr($curLine, 129,  7),
			'B-V'      => substr($curLine, 152,  6)
		);

		# strip whitespace from values
		foreach my $key (keys %{$stars{$HIP}})
		{
			$stars{$HIP}{$key} =~ s/\s//g;
		}
		
		# add data
		$stars{$HIP} = {
			'RAdeg'     => $star{'RAdeg'},
			'DEdeg'     => $star{'DEdeg'},
			'Plx'       => $star{'Plx'},
			'e_RAdeg'   => $star{'e_RAdeg'},
			'e_DEdeg'   => $star{'e_DEdeg'},
			'e_Plx'     => $star{'e_Plx'},
			'BTmag'     => '',
			'VTmag'     => '',
			'Hpmag'     => $star{'Hpmag'},
			'B-V'       => $star{'B-V'},
			'coordRef'  => '2007A&A...474..653V',
			'PlxRef'    => '2007A&A...474..653V',
			'VmagRef'   => '',
			'SpTypeRef' => ''
		};

		$numStars++;
	}
	close(HIPFILE);
	
	print "  Read a total of $numStars records.\n";
}

# Read Hipparcos Main Catalog to get Vmag, BTmag, VTmag, SpType
# which are not present in the new revision
sub ReadOldHipparcos
{
	print "Reading Hipparcos Main Catalog...\n";

	local(*HIPFILE);
	if(!open(HIPFILE, '<', $HIP_PATH))
	{
		print "  ERROR: Could not open $HIP_PATH\n";
		return;
	}

	my $numStars = 0;
	while (my $curLine = <HIPFILE>)
	{
		chomp $curLine;

		# check that this is hip_main.dat
		die "ERROR: Bad catalog format in $HIP_PATH\n" if(substr($curLine, 0, 2) ne 'H|');

		my $HIP = Trim(substr($curLine, 8, 6));
		if (exists $stars{$HIP})
		{
			# add values into entry
			$stars{$HIP}{'Vmag'}      = Trim(substr($curLine,  41,  5));
			$stars{$HIP}{'BTmag'}     = Trim(substr($curLine, 217,  6));
			$stars{$HIP}{'VTmag'}     = Trim(substr($curLine, 230,  6));
			$stars{$HIP}{'SpType'}    = Trim(substr($curLine, 435, 12));
			# terminate SpType at first space
			$stars{$HIP}{'SpType'}    =~ m/^([^\s]*)/;
			$stars{$HIP}{'SpType'}    = $1;
			$stars{$HIP}{'VmagRef'}   = '1997A&A...323L..49P'; # so it matches with SIMBAD
			$stars{$HIP}{'SpTypeRef'} = '1997A&A...323L..49P';
		}

		# increment tally
		$numStars++;
	}
	close(HIPFILE);
	
	print "  Read a total of $numStars records.\n";
}

sub ReadSimbad
{
	print "Reading SIMBAD output...\n";

	local(*HIPFILE);
	if(!open(HIPFILE, '<', $SIMBAD_PATH))
	{
		print "  ERROR: Could not open $SIMBAD_PATH\n";
		return;
	}

	my $numStars = 0;
	while (my $curLine = <HIPFILE>)
	{
		chomp $curLine;

		# check that this is simbad.txt
		# die "ERROR: Bad catalog format in $HIP_PATH\n" if(substr($curLine, 0, 3) ne 'HIP');

		# split into separate fields using '|'
		my @fields = split('\|', $curLine);
		# split right ascension and declination errors 
		my @coorderrors = split(' ', $fields[3]);

		# replace " " or "~" with empty string
		$coorderrors[0] =~ s/~//g;
		$coorderrors[1] =~ s/~//g;
		$fields[5] =~ Trim(s/~ //g);
		$fields[6] =~ s/~//g;
		$fields[8] =~ s/ //g;
		$fields[10] =~ s/~/g/;

		# remove leading "&" from bibcodes for Vmag reference
		$fields[9] =~ s/^&//;

		my $HIP = Trim(substr($curLine, 4, 6));
		if (exists $stars{$HIP})
		{
			# add values into entry - if they're not blank
			($fields[1] ne '') ? ($stars{$HIP}{'RAdeg'} = $fields[1]) : ($stars{$HIP}{'RAdeg'}),
			($fields[2] ne '') ? ($stars{$HIP}{'DEdeg'} = $fields[2]) : ($stars{$HIP}{'DEdeg'}),
			($fields[5] ne '') ? ($stars{$HIP}{'Plx'} = $fields[5]) : ($stars{$HIP}{'Plx'}),
			($coorderrors[0] ne '') ? ($stars{$HIP}{'e_RAdeg'} = $coorderrors[0]) : ($stars{$HIP}{'e_RAdeg'}),
			($coorderrors[1] ne '') ? ($stars{$HIP}{'e_DEdeg'} = $coorderrors[1]) : ($stars{$HIP}{'e_DEdeg'}),
			($fields[6] ne '') ? ($stars{$HIP}{'e_Plx'} = $fields[6]) : ($stars{$HIP}{'e_Plx'}),
			($fields[8] ne '') ? ($stars{$HIP}{'Vmag'} = $fields[8]) : ($stars{$HIP}{'Vmag'}),
			($fields[10] ne '') ? ($stars{$HIP}{'SpType'} = $fields[10]) : ($stars{$HIP}{'SpType'}),
			($fields[4] ne '') ? ($stars{$HIP}{'coordRef'} = $fields[4]) : ($stars{$HIP}{'coordRef'}),
			($fields[7] ne '') ? ($stars{$HIP}{'PlxRef'} = $fields[7]) : ($stars{$HIP}{'PlxRef'}),
			($fields[9] ne '') ? ($stars{$HIP}{'VmagRef'} = $fields[9]) : ($stars{$HIP}{'VmagRef'}),
			($fields[11] ne '') ? ($stars{$HIP}{'SpTypeRef'} = $fields[11]) : ($stars{$HIP}{'SpTypeRef'}),
		}

		# increment tally
		$numStars++;
	}
	close(HIPFILE);
	
	print "  Read a total of $numStars records.\n";
}

sub WriteDat
{
	my $numStars = keys %stars;
	print "Writing databases...\n";

	print "  Writing binary database to $DAT_PATH\n";
	local(*DATFILE);
	open(DATFILE, '>', $DAT_PATH) or die "ERROR: Could not write to $DAT_PATH\n";
	binmode(DATFILE);
	
	print "  Writing text database to $TXT_PATH\n";
	local(*TXTFILE);
	open(TXTFILE, '>', $TXT_PATH) or die "ERROR: Could not write to $TXT_PATH\n";
	
	# write file header
	print DATFILE pack('a8ccL', 'CELSTARS', 0, 1, $numStars);
	print TXTFILE sprintf("%u\n", $numStars);
	
	# write each star
	foreach my $HIP (sort { $a <=> $b } keys %stars)
	{
		my $dist = PlxToDistance($stars{$HIP}{'Plx'});
		my $theta = deg2rad($stars{$HIP}{'RAdeg'}) + pi;
		my $phi = deg2rad($stars{$HIP}{'DEdeg'}) - pi / 2;
		my @xyz = (
			 $dist * cos($theta) * sin($phi),
			 $dist * cos($phi),
			-$dist * sin($theta) * sin($phi)
		);
		my $xc = $eqToCel[0][0] * $xyz[0] + $eqToCel[1][0] * $xyz[1] + $eqToCel[2][0] * $xyz[2];
		my $yc = $eqToCel[0][1] * $xyz[0] + $eqToCel[1][1] * $xyz[1] + $eqToCel[2][1] * $xyz[2];
		my $zc = $eqToCel[0][2] * $xyz[0] + $eqToCel[1][2] * $xyz[1] + $eqToCel[2][2] * $xyz[2];
		my $absMag = AppMagToAbsMag($stars{$HIP}{'Vmag'}, $stars{$HIP}{'Plx'});
		my $spType = ParseSpType($stars{$HIP}{'SpType'});
		print DATFILE pack('LfffsS', $HIP, $xc, $yc, $zc, $absMag * 256, $spType);
		print TXTFILE sprintf("%u  %.9f %+.9f %.6f %.2f %s\n", $HIP,
		                      $stars{$HIP}{'RAdeg'}, $stars{$HIP}{'DEdeg'},
							  $dist, $stars{$HIP}{'Vmag'}, $stars{$HIP}{'SpType'});
	}
	
	close(DATFILE);
	close(TXTFILE);
	
	print "  Wrote a total of $numStars stars.\n";

	# counter for commonly used references, including ones from SIMBAD
	my $Perrymancoords = 0; # counters for common reference and where they're being used
	my $vanLeeuwencoords = 0;
	my $gaiaDR1coords = 0;
	my $gaiaDR2coords = 0;

	my $PerrymanPlx = 0;
	my $vanLeeuwenPlx = 0;
	my $gaiaDR1Plx = 0;
	my $gaiaDR2Plx = 0;

	my $PerrymanVmag = 0;
	my $TYC2Vmag = 0;
	my $YossVmag = 0;

	my $PerrymanSpType = 0;
	my $HDSpType = 0;
	my $YossSpType = 0;
	my $KeenanSpType = 0;

	foreach my $HIP (keys %stars)
	{
		if ($stars{$HIP}{'coordRef'} eq '1997A&A...323L..49P') {
			$Perrymancoords++;
		} elsif ($stars{$HIP}{'coordRef'} eq '2007A&A...474..653V') {
			$vanLeeuwencoords++;
		} elsif ($stars{$HIP}{'coordRef'} eq '2016A&A...595A...2G') {
			$gaiaDR1coords++;
		} elsif ($stars{$HIP}{'coordRef'} eq '2018yCat.1345....0G') {
			$gaiaDR2coords++;
		}

		if ($stars{$HIP}{'PlxRef'} eq '1997A&A...323L..49P') {
			$PerrymanPlx++;
		} elsif ($stars{$HIP}{'PlxRef'} eq '2007A&A...474..653V') {
			$vanLeeuwenPlx++;
		} elsif ($stars{$HIP}{'PlxRef'} eq '2016A&A...595A...2G') {
			$gaiaDR1Plx++;
		} elsif ($stars{$HIP}{'PlxRef'} eq '2018yCat.1345....0G') {
			$gaiaDR2Plx++;
		}

		if ($stars{$HIP}{'VmagRef'} eq '1997A&A...323L..49P') {
			$PerrymanVmag++;
		} elsif (index($stars{$HIP}{'VmagRef'}, '2000A&A...355L..27H') != -1) {
			$TYC2Vmag++;
		} elsif (index($stars{$HIP}{'VmagRef'}, '1997JApA...18..161Y') != -1) {
			$YossVmag++;
		}

		if ($stars{$HIP}{'SpTypeRef'} eq '1997A&A...323L..49P') {
			$PerrymanSpType++;
		} elsif (index($stars{$HIP}{'SpTypeRef'}, 'MSS') != -1) {
			$HDSpType++;
		} elsif (index($stars{$HIP}{'SpTypeRef'}, '1997JApA...18..161Y') != -1) {
			$YossSpType++;
		} elsif (index($stars{$HIP}{'SpTypeRef'}, '1989ApJS...71..245K') != -1) {
			$KeenanSpType++;
		}
	}

	print "Statistics: Hipparcos Catalogue supplied $Perrymancoords coordinates, $PerrymanPlx parallaxes, $PerrymanVmag magnitudes, and $PerrymanSpType spectral types;\n";
	print "  Hipparcos New Reduction supplied $vanLeeuwencoords coordinates and $vanLeeuwenPlx parallaxes;\n";
	print "  Gaia DR1 supplied $gaiaDR1coords coordinates and $gaiaDR1Plx parallaxes;\n";
	print "  Gaia DR2 supplied $gaiaDR2coords coordinates and $gaiaDR2Plx parallaxes;\n";
	print "  Tycho-2 Catalogue supplied $TYC2Vmag magnitudes;\n";
	print "  HD Catalogue supplied $HDSpType spectral types;\n";
	print "  Yoss et al. (1997) supplied $YossVmag magnitudes and $YossSpType spectral types;\n";
	print "  Keenan & McNeil (1989) supplied $KeenanSpType spectral types\n  (NOTE: minor sources from SIMBAD not included).\n";

}

# -------------------------- DATA HANDLING ROUTINES -------------------------- #

# fix missing data
sub FixData
{
	print "Fixing data...\n";
	foreach my $HIP (keys %stars)
	{
		my $Bt = $stars{$HIP}{'BTmag'};
		my $Vt = $stars{$HIP}{'VTmag'};
		my $Hpmag = $stars{$HIP}{'Hpmag'};
		my $BtVt = '';
		my $BtVt = $Bt - $Vt if(($Bt ne '') && ($Vt ne ''));

		# if Vmag missing, calculate from Bt and Vt magnitudes or Hpmag
		if (($stars{$HIP}{'Vmag'} eq '') && ($Vt ne ''))
		{
			if ($BtVt eq '')
			{
				$stars{$HIP}{'Vmag'} = VtToVmag($Vt, 0);
			}
			else
			{
				$stars{$HIP}{'Vmag'} = VtToVmag($Vt, $BtVt);
			}
		}
		elsif (($stars{$HIP}{'Vmag'} eq '') && ($Hpmag ne ''))
		{
			$stars{$HIP}{'Vmag'} = HpToVmag($Hpmag, 0);
		}

		# if B-V missing, calculate from Bt and Vt magnitudes
		$stars{$HIP}{'B-V'} = BtVtToBV($BtVt) if(($stars{$HIP}{'B-V'} eq '') && ($BtVt ne ''));
		
		# if star has unknown spectral type, attempt to guess from B-V
		if ((SpTypeToString(ParseSpType($stars{$HIP}{'SpType'})) eq '?') && ($GUESS_TYPES == 1))
		{
			$stars{$HIP}{'SpType'} = GuessSpType($stars{$HIP}{'B-V'}) if($stars{$HIP}{'B-V'} ne '');
		}
	}
	print "  Fixed.\n";
}

# drop stars with bad data
sub CheckStars
{
	print "Checking data...\n";
	my $good = 0;
	my $dubious = 0;
	my $dropped = 0;
	my $brightdrop = 0;
	foreach my $HIP (keys %stars)
	{
		my $badness = TestDubious($stars{$HIP});
		if ($badness == 0)
		{
			# good stars are fine
			$good++;
		}
		else
		{
			# drop star
			$brightdrop++ if(($stars{$HIP}{'Vmag'} ne '') && ($stars{$HIP}{'Vmag'} <= 6));
			delete $stars{$HIP};
			$dropped++;
		}
	}
	print "  $good stars with good data included.\n";
	print "  $dropped stars dropped, of which $brightdrop are bright stars.\n";
}

# reject stars 
sub TestDubious
{
	my $star = shift;
	my $dubious = 0;

	# if there is no magnitude information, we can't use this star
	$dubious = 1 if($star->{'Vmag'} eq '');
	
	# if low, negative or missing parallax, reject
	$dubious = 1 if(($star->{'Plx'} eq '') || ($star->{'Plx'} < 0.2));

	# if parallax error >= parallax, reject
	$dubious = 1 if($star->{'Plx'} <= $star->{'e_Plx'});
	
	# if no position information, reject
	$dubious = 1 if(($star->{'RAdeg'} eq '') || ($star->{'DEdeg'} eq ''));

	# if large error in position, reject
	my $e_RADec = sqrt(deg2rad($star->{'e_RAdeg'}) ** 2 + deg2rad($star->{'e_DEdeg'}) ** 2);
	$dubious = 1 if($e_RADec > 25);
	
	# otherwise the star is fine
	return $dubious;
}

# ------------------------ ASTROPHYSICAL CALCULATIONS ------------------------ #

# convert apparent magnitude to absolute magnitude using parallax
sub AppMagToAbsMag
{
	my $appMag = shift;
	my $plx = shift;
	return $appMag - 5 * Log10(100 / $plx);
}

# convert parallax to distance in light years
sub PlxToDistance
{
	my $plx = shift;
	return 1000/$plx * $LY_PER_PARSEC;
}

# --------------------- MAGNITUDE SYSTEM TRANSFORMATIONS --------------------- #

# convert Vt magnitude to Vmag
# from Mamajek, Meyer & Liebert (2002), AJ 124 (3), 1670-1694
sub VtToVmag
{
	my $Vt = shift;
	my $BtVt = shift;
	return $Vt + 9.7e-04 - 1.334e-01 * $BtVt + 5.486e-02 * $BtVt * $BtVt - 1.998e-02 * $BtVt * $BtVt * $BtVt;
}

# convert Hp magnitude to Vmag
# based on cubic polynomial fit to data in Bessel, M.S (2000), PASP 112, 961-965
sub HpToVmag
{
	my $Hp = shift;
	my $BtVt = shift;
	return $Hp - 7.967e-03 - 2.537e-01 * $BtVt + 1.073e-01 * $BtVt * $BtVt - 2.678e-03 * $BtVt * $BtVt * $BtVt;
}

# convert Bt-Vt to B-V
# from Mamajek, Meyer & Liebert (2002), AJ 124 (3), 1670-1694
sub BtVtToBV
{
	my $BtVt = shift;
	my $BV = $BtVt - 7.813e-03 * $BtVt - 1.489e-01 * $BtVt * $BtVt + 3.384e-02 * $BtVt * $BtVt * $BtVt;
	return $BV;
}

# ------------------------- SPECTRAL CLASS HANDLING -------------------------- #

# Implements the stellar class parser from stellarclass.cpp
sub ParseSpType
{
	my $st = shift;
	$st =~ s/\s//g;
	
	# remove parentheses
	$st =~ s/[\(\)]//g;
	
	$st = '?' if($st eq '');

	my $i = 0;
	my $state = 'BeginState';

	my $starType = $SC_StarType{'NormalStar'};
	my $specClass = $SC_SpecClass{'?'};
	my $subclass = $SC_Subclass{'?'};
	my $lumClass = $SC_LumClass{'?'};

	while ($state ne 'EndState')
	{
		my $c = ($i < length($st)) ? substr($st, $i, 1) : '';
		if ($state eq 'BeginState')
		{
			if ($c eq 'Q')
			{
				$starType = $SC_StarType{'NeutronStar'};
				$state = 'EndState';
			}
			elsif ($c eq 'X')
			{
				$starType = $SC_StarType{'BlackHole'};
				$state = 'EndState';
			}
			elsif ($c eq 'D')
			{
				$starType = $SC_StarType{'WhiteDwarf'};
				$specClass = $SC_SpecClass{'D'};
				$state = 'WDTypeState';
				$i++;
			}
			elsif ($c eq 's')
			{
				$state = 'SubdwarfPrefixState';
				$i++;
			}
			elsif ($c eq '?')
			{
				$state = 'EndState';
			}
			else
			{
				$state = 'NormalStarClassState';
			}
		}
		elsif ($state eq 'WolfRayetTypeState')
		{
			if ($c =~ m/[CN]/)
			{
				$specClass = $SC_SpecClass{'W'.$c};
				$state = 'NormalStarSubclassState';
				$i++;
			}
			else
			{
				$specClass = $SC_SpecClass{'WC'};
				$state = 'NormalStarSubclassState';
				$i++;
			}
		}
		elsif ($state eq 'SubdwarfPrefixState')
		{
			if ($c eq 'd')
			{
				$lumClass = $SC_LumClass{'VI'};
				$state = 'NormalStarClassState';
				$i++;
			}
			else
			{
				$state = 'EndState';
			}
		}
		elsif ($state eq 'NormalStarClassState')
		{
			if ($c eq 'W')
			{
				$state = 'WolfRayetTypeState';
			}
			elsif ($c =~ m/[OBAFGKMRSNLTC]/)
			{
				$specClass = $SC_SpecClass{$c};
				$state = 'NormalStarSubclassState';
			}
			else
			{
				$state = 'EndState';
			}
			$i++;
		}
		elsif ($state eq 'NormalStarSubclassState')
		{
			if ($c =~ m/[0-9]/)
			{
				$subclass = $SC_Subclass{$c};
				$state = 'NormalStarSubclassDecimalState';
				$i++;
			}
			elsif ($c =~ m/[\/\-:]/)
			{
				$state = 'NormalStarSubclassExtraState';
			}
			else
			{
				$state = 'LumClassBeginState';
			}
		}
		elsif ($state eq 'NormalStarSubclassDecimalState')
		{
			if ($c eq '.')
			{
				$state = 'NormalStarSubclassFinalState';
				$i++;
			}
			else
			{
				$state = 'LumClassBeginState';
			}
		}
		elsif ($state eq 'NormalStarSubclassFinalState')
		{
			if ($c =~ m/[0-9]/)
			{
				$state = 'LumClassBeginState';
			}
			else
			{
				$state = 'EndState';
			}
			$i++;
		}
		elsif ($state eq 'NormalStarSubclassExtraState')
		{
			if ($c =~ m/[IV]/)
			{
				$state = 'LumClassBeginState';
			}
			elsif ($c eq '+')
			{
				$state = 'EndState';
			}
			elsif ($i >= length($st))
			{
				$state = 'EndState';
			}
			else
			{
				$i++;
			}
		}
		elsif ($state eq 'LumClassBeginState')
		{
			if ($c eq 'I')
			{
				$state = 'LumClassIState';
			}
			elsif ($c eq 'V')
			{
				$state = 'LumClassVState';
			}
			elsif ($c =~ m/[\/\-:]/)
			{
				$state = 'NormalStarSubclassExtraState';
			}
			else
			{
				$state = 'EndState';
			}
			$i++;
		}
		elsif ($state eq 'LumClassIState')
		{
			if ($c eq 'I')
			{
				$state = 'LumClassIIState';
			}
			elsif ($c eq 'V')
			{
				$lumClass = $SC_LumClass{'IV'};
				$state = 'EndState';
			}
			elsif ($c eq 'a')
			{
				$state = 'LumClassIaState';
			}
			elsif ($c eq 'b')
			{
				$lumClass = $SC_LumClass{'Ib'};
				$state = 'EndState';
			}
			elsif ($c eq '-')
			{
				$state = 'LumClassIdashState';
			}
			else
			{
				$lumClass = $SC_LumClass{'Ib'};
				$state = 'EndState';
			}
			$i++;
		}
		elsif ($state eq 'LumClassIIState')
		{
			if ($c eq 'I')
			{
				$lumClass = $SC_LumClass{'III'};
				$state = 'EndState';
			}
			else
			{
				$lumClass = $SC_LumClass{'II'};
				$state = 'EndState';
			}
		}
		elsif ($state eq 'LumClassIdashState')
		{
			if ($c eq 'a')
			{
				$state = 'LumClassIaState';
			}
			elsif ($c eq 'b')
			{
				$lumClass = $SC_LumClass{'Ib'};
				$state = 'EndState';
			}
			else
			{
				$lumClass = $SC_LumClass{'Ia'};
				$state = 'EndState';
			}
		}
		elsif ($state eq 'LumClassIaState')
		{
			if ($c eq '0')
			{
				$lumClass = $SC_LumClass{'Ia0'};
				$state = 'EndState';
			}
			else
			{
				$lumClass = $SC_LumClass{'Ia'};
				$state = 'EndState';
			}
		}
		elsif ($state eq 'LumClassVState')
		{
			if ($c eq 'I')
			{
				$lumClass = $SC_LumClass{'VI'};
				$state = 'EndState';
			}
			else
			{
				$lumClass = $SC_LumClass{'V'};
				$state = 'EndState';
			}
		}
		elsif ($state eq 'WDTypeState')
		{
			if ($c =~ m/[ABCOQXZ]/)
			{
				$specClass = $SC_SpecClass{'D'.$c};
				$i++;
			}
			else
			{
				$specClass = $SC_SpecClass{'D'};
			}
			$state = 'WDExtendedTypeState';
		}
		elsif ($state eq 'WDExtendedTypeState')
		{
			if ($c =~ m/[ABCOQZXVPHE]/)
			{
				$i++;
			}
			else
			{
				$state = 'WDSubclassState';
			}
		}
		elsif ($state eq 'WDSubclassState')
		{
			if ($c =~ m/[0-9]/)
			{
				$subclass = $SC_Subclass{$c};
				$i++;
			}
			$state = 'EndState';
		}
		else
		{
			die "ERROR: Unknown state in spectral class parser\n";
		}
	}
	return $starType + $specClass + $subclass + $lumClass;
}

# Convert spectral class code to string
sub SpTypeToString
{
	my $spType = shift;
	my $st = '?';
	if (($spType & $SC_StarType{'Mask'}) == $SC_StarType{'NormalStar'})
	{
		foreach my $sp (keys %SC_SpecClass)
		{
			if (($sp !~ /^D/) && ($sp ne 'Mask'))
			{
				$st = $sp if(($spType & $SC_SpecClass{'Mask'}) == $SC_SpecClass{$sp});
			}
		}
		if ($st ne '?')
		{
			foreach my $sc (keys %SC_Subclass)
			{
				if ($sc ne 'Mask')
				{
					if (($spType & $SC_Subclass{'Mask'}) == $SC_Subclass{$sc})
					{
						$st .= $sc if($sc ne '?');
					}
				}
			}
			foreach my $lc (keys %SC_LumClass)
			{
				if ($lc ne 'Mask')
				{
					if (($spType & $SC_LumClass{'Mask'}) == $SC_LumClass{$lc})
					{
						$st .= $lc if($lc ne '?');
					}
				}
			}
		}
	}
	elsif (($spType & $SC_StarType{'Mask'}) == $SC_StarType{'WhiteDwarf'})
	{
		foreach my $wt (keys %SC_SpecClass)
		{
			if ($wt =~ m/^D/)
			{
				$st = $wt if(($spType & $SC_SpecClass{'Mask'}) == $SC_SpecClass{$wt});
			}
		}
		if ($st ne '?')
		{
			foreach my $sc (keys %SC_Subclass)
			{
				if ($sc ne 'Mask')
				{
					if(($spType & $SC_Subclass{'Mask'}) == $SC_Subclass{$sc})
					{
						$st .= $sc if($sc ne '?');
					}
				}
			}
		}
	}
	elsif (($spType & $SC_StarType{'Mask'}) == $SC_StarType{'NeutronStar'})
	{
		$st = 'Q';
	}
	elsif (($spType & $SC_StarType{'Mask'}) == $SC_StarType{'BlackHole'})
	{
		$st = 'X';
	}
	return $st;
}

# Guess the spectral type from the B-V colour index - use closest match to table
sub GuessSpType
{
	my $BV = shift;
	my $st = '?';
	my $minDelta = 9999;
	foreach my $trial_st (keys %SpBV)
	{
		if (abs($BV - $SpBV{$trial_st}) < $minDelta)
		{
			$st = $trial_st;
			$minDelta = abs($BV - $SpBV{$trial_st});
		}
	}
	return $st;
}

# ---------------- STRING HANDLING AND MATHEMATICAL FUNCTIONS ---------------- #

# remove leading and trailing spaces from a string
sub Trim
{
	my $st = shift;
	$st =~ s/(^\s+)|(\s+$)//g;
	return $st;
}

# calculate log base 10 of a number
sub Log10
{
	my $n = shift;
	return log($n)/log(10);
}
