#!/bin/sh

ncpu=2
blddir="/data/build"
bindir="/data/fwbin"
scriptdir="/data/fff-builder"
lockfile="$scriptdir/fffbuilder.lock"
hashfile="$scriptdir/used.hashes"
nukebuild=1 # delete entire build directory
noprepare=0 # do not run ./buildscript prepare
force=0 # overwrite hash check

bspnodeoff="ath79-generic ath79-tiny ar71xx-generic ipq806x-generic mpc85xx-generic ramips-mt76x8 ramips-mt7621"
bsplayer3off="ath79-generic ipq806x-generic mpc85xx-generic ramips-mt76x8 ramips-mt7621"
bspnodeadsc="ath79 ath79-tiny ar71xx ipq40xx ipq806x mpc85xx mt76x8 mt7621"
bsplayer3adsc="ath79 ipq40xx ipq806x mpc85xx mt76x8 mt7621"

buildone() {
	local vrnt=$1
	local bsp=$2

	echo "-> Build $vrnt $bsp ..."
        ./buildscript selectbsp "bsp/${bsp}.bsp"

	local logfile=$logfilebase/build-$vrnt-$bsp.out
        ./buildscript build > "$logfile" 2>&1
	
	mkdir -p $fwfilebase/targets
	mv bin/* $fwfilebase/targets/$vrnt-$bsp
	mkdir -p $fwfilebase/packages/$vrnt-$bsp
	mv build/bin/packages/* $fwfilebase/packages/$vrnt-$bsp/
}

repo="$1"
chkout="$2"

case "$repo" in
	official)
		giturl="https://git.freifunk-franken.de/freifunk-franken/firmware.git"
		[ -n "$chkout" ] || chkout=master
		bspnode="$bspnodeoff"
		bsplayer3="$bsplayer3off"
		;;
	staging)
		giturl="https://git.freifunk-franken.de/adschm/firmware.git"
		[ -n "$chkout" ] || chkout=staging
		bspnode="$bspnodeoff"
		bsplayer3="$bsplayer3off"
		;;
	*)
		echo "No valid firmware identifier given. Exiting."
		exit 0
esac

remotehash=$(git ls-remote "$giturl" "$chkout" | awk '{print $1}')
if grep -q "$remotehash" "$hashfile"; then
	if [ "$force" = "1" ]; then
		echo "Hash has already been built. Continuation forced..."
	else
		echo "Hash has already been built. Exiting."
		exit 0
	fi
fi

if [ -f "$lockfile" ]; then
	echo "Script is already running."
	exit 0
fi
touch "$lockfile"

echo "$remotehash" >> "$hashfile"

# Do something
if [ "$nukebuild" = "1" ]; then
	echo "-> Remove old build directory..."
	rm -rf "$blddir"

	echo "-> Clone Git repo..."
	sleep 1
	git clone "$giturl" "$blddir"
fi

cd "$blddir"
git checkout "$chkout"

shorthash=$(git rev-parse HEAD | cut -c 1-12)
fwfilebase="$bindir/$(date "+%Y-%m-%d_%H%M")_${repo}_$shorthash"
logfilebase=$fwfilebase/logs
mkdir -p "$logfilebase"

echo "-> Select node and prepare..."
./buildscript selectvariant node
# prepare won't work without having bsp set
./buildscript selectbsp bsp/ath79-generic.bsp
if [ "$noprepare" = "1" ]; then
	echo "prepare skipped" > "$logfilebase/prepare.out"
else
	./buildscript prepare > "$logfilebase/prepare.out" 2>&1
fi

for b in $bspnode; do
	buildone node "$b"
done

echo "-> Select layer3..."
./buildscript selectvariant layer3

for b in $bsplayer3; do
        buildone layer3 "$b"
done

rm "$lockfile"
