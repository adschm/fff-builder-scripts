#!/bin/sh

ncpu=2
chkout="master"
blddir="/data/build"
bindir="/data/fwbin"
giturl="https://git.freifunk-franken.de/freifunk-franken/firmware.git"

bspnode="ath79-generic ath79-tiny ar71xx-generic ipq806x-generic mpc85xx-generic ramips-mt76x8 ramips-mt7621"
bsplayer3="ath79-generic ipq806x-generic mpc85xx-generic ramips-mt76x8 ramips-mt7621"

buildone() {
	local vrnt=$1
	local bsp=$2

	echo "-> Build $vrnt $bsp ..."
        ./buildscript selectbsp "bsp/${bsp}.bsp"

	local logfile=$bindir/$remotehash/logs/$vrnt-$bsp.stdout
	mkdir -p $bindir/$remotehash/logs/
        ./buildscript build 2> "$logfile" > "$logfile"
	
	mkdir -p $bindir/$remotehash/targets
	mv bin/* $bindir/$remotehash/targets/
	mkdir -p $bindir/$remotehash/packages/$vrnt-$bsp
	mv build/bin/packages/* $bindir/$remotehash/packages/$vrnt-$bsp/
}

if [ -d "$blddir" ]; then
	cd "$blddir"
	localhash=$(git rev-parse "$chkout")
	cd ..
fi
remotehash=$(git ls-remote "$giturl" "$chkout" | awk '{print $1}')
if [ "$localhash" = "$remotehash" ] && [ "$1" != "-f" ]; then
	echo "Hash has not changed. Exiting."
	exit 0
fi

# Do something
echo "-> Remove old build directory..."
rm -rf "$blddir"

echo "-> Clone Git repo..."
sleep 1
git clone "$giturl" "$blddir"
sleep 1
cd "$blddir"
git checkout "$chkout"

echo "-> Select node and prepare..."
./buildscript selectvariant node
# prepare won't work without having bsp set
./buildscript selectbsp bsp/ath79-generic.bsp
./buildscript prepare

for b in $bspnode; do
	buildone node "$b"
done

echo "-> Select layer3..."
./buildscript selectvariant layer3

for b in $bsplayer3; do
        buildone layer3 "$b"
done

