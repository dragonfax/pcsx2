#!/bin/sh
export PKG_CONFIG_PATH=/usr/X11/lib/pkgconfig
for i in "$@"; do
#check if gdb support is requested
	if [ "$i" == "--enable-gdb" ]; then
		GDB="--enable-gdb "
	fi
#check if debug build enabled
	if [ "$i" == "--enable-debug" ]; then
		DEBUG="--enable-debug"
	fi
#check if devbuild requested
	if [ "$i" == "--enable-devbuild" ]; then
		DEVBUILD="--enable-devbuild"
	fi
done
pushd bin >/dev/null
mkdir bios &>/dev/null
mkdir frames &>/dev/null
mkdir help &>/dev/null
mkdir logs &>/dev/null
mkdir sstates &>/dev/null
popd >/dev/null
echo "--------------"
echo "Building pcsx2"
echo "--------------"
pushd ./pcsx2 >/dev/null
aclocal
autoconf
automake --add-missing
rm -rf autom4te.cache >/dev/null &>/dev/null
rm -rf build >/dev/null &>/dev/null
mkdir build &>/dev/null
pushd build >/dev/null
../configure $DEVBUILD --enable-sse3 $GDB $DEBUG
make
popd >/dev/null
mv ./build/Linux/pcsx2 ../bin/
popd >/dev/null
chmod +x ./bin/*
