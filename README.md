# buildstardb.pl
Updated version of buildstardb.pl for use with SIMBAD.

## License
This is a modified version of the buildstardb.pl file that is included in Celestia. The original file can be accessed at https://github.com/CelestiaProject/Celestia/blob/master/src/tools/stardb/buildstardb.pl. The original file is licensed under the GNU General Public License. Per section 5 of the GNU General Public License (v3), this version is also being released under that license.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <https://www.gnu.org/licenses/>.

## About
The official development of Celestia stopped in 2011, and most of the catalogs of astronomical objects have not been updated, even though much has happened. In particular, stars.dat, a database of stars for Celestia, still uses the Hipparcos catalogue, but the newer Gaia data releases (Gaia DR1 and DR2) contain much more precise astronomical data for a larger sample of stars.

This is where this program comes in. Originally based on buildstardb.pl, a perl script that converts Hipparcos to a stars.dat file, and adds data from the SIMBAD Astronomical Database. Downloading data directly from SIMBAD has a few advantages. Firstly, SIMBAD standardizes its data, which means that we don't have to convert the J2015.5 epoch from Gaia to the J2000 used in Celestia. Second, it allows us to download whatever objects we want, a distinctly good thing since Gaia contains over a billion point sources.

You should know that I'm not a very good coder and it my code may have bugs in it, especially the spectral class parser. So please do give feedback!

## Usage
To use this file, you need a copy of hip_main.dat (downloadable [here](http://cdsarc.u-strasbg.fr/viz-bin/cat/I/239)) from the original Hipparcos catalogue (Perryman et al. 1997), and hip2.dat (downloadable [here](http://cdsarc.u-strasbg.fr/viz-bin/cat/I/311)) from the new reduction (van Leeuwen et al. 2007).

You also need a data file from SIMBAD, named simbad.txt. This file can be obtained using SIMBAD's [script execution interface](http://simbad.u-strasbg.fr/simbad/sim-fscript), but each file can only have up to 20000 entries. So, you'll have to query SIMBAD in groups of 20000. For example, to get all HIP stars between 20000 and 39999, paste the following code into the text window:

```
format object "%IDLIST(HIP)|%COO(d;A)|%COO(d;D)|%COO(E)|%COO(B)|%PLX(V)|%PLX(E)|%PLX(B)|%FLUXLIST(V;F)|&%FLUXLIST(V;B)|%SP(S)|%SP(B)"
set limit 20000
query id wildcard HIP [23]????
```

Then, remove the headers from each of the files and concatenate them into one big file.

## Changes
* Changed script so it deals with data from SIMBAD.
* Added a "statistics" section that counts which sources contributed which coordinates, parallaxes, magnitudes, etc.
* Updated the spectral class parser. In particular, it can now extract luminosity classes in parentheses (e.g. `K0(III)` becomes `K0III` instead of just `K0`). It also extracts subclasses and luminosity classes that were previously blocked by slashes, dashes, or colons. So, `B0-0.5V` becomes `B0V` instead of just `B0`, and `M1-M2Ia-Iab` becomes `M1Ia` instead of just `M1`.

## Acknowledgements
Thanks to Chris Laurel and everyone who helped create Celestia in the first place. Also, I must give thanks to Andrew Tribick (ajtribick) for creating the original file.
