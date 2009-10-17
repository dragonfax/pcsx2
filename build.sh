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
done
pushd bin >/dev/null
mkdir bios &>/dev/null
mkdir frames &>/dev/null
mkdir help &>/dev/null
mkdir logs &>/dev/null
mkdir sstates &>/dev/null
popd >/dev/null
echo "-------------------"
echo "Building plugins..."
echo "-------------------"
echo "Building CDVDnull..."
pushd ./plugins/CDVDnull >/dev/null
aclocal
autoconf
automake --add-missing
rm -rf autom4te.cache >/dev/null &>/dev/null
rm -rf build >/dev/null &>/dev/null
mkdir build &>/dev/null
pushd build >/dev/null
../configure $GDB
make
popd >/dev/null
popd >/dev/null
mv ./plugins/CDVDnull/build/libCDVDnull.so.0.8.0 ./bin/plugins/libCDVDnull.so
echo "Building CDVDiso..."
pushd ./plugins/CDVDiso/src >/dev/null
aclocal
autoconf
automake --add-missing
rm -rf autom4te.cache >/dev/null &>/dev/null
cd ..
rm -rf build >/dev/null &>/dev/null
mkdir build &>/dev/null
pushd build >/dev/null
../src/configure $GDB
make
popd >/dev/null
popd >/dev/null
mv ./plugins/CDVDiso/build/libCDVDiso.so.0.9.0 ./bin/plugins/libCDVDiso.so
echo "Building DEV9null..."
pushd ./plugins/dev9null >/dev/null
aclocal
autoconf
automake --add-missing
rm -rf autom4te.cache >/dev/null &>/dev/null
rm -rf build >/dev/null &>/dev/null
mkdir build &>/dev/null
pushd build >/dev/null
../configure $GDB
make
popd >/dev/null
popd >/dev/null
mv ./plugins/dev9null/build/libDEV9null.so.0.4.0 ./bin/plugins/libDEV9null.so
echo "Building FWnull..."
pushd ./plugins/FWnull >/dev/null
aclocal
autoconf
automake --add-missing
rm -rf autom4te.cache >/dev/null &>/dev/null
rm -rf build >/dev/null &>/dev/null
mkdir build &>/dev/null
pushd build >/dev/null
../configure $GDB
make
popd >/dev/null
popd >/dev/null
mv ./plugins/FWnull/build/libFWnull.so.0.5.0 ./bin/plugins/libFWnull.so
echo "Building SPU2null..."
pushd ./plugins/SPU2null
aclocal
autoconf
automake --add-missing
rm -rf autom4te.cache >/dev/null &>/dev/null
rm -rf build >/dev/null &>/dev/null
mkdir build &>/dev/null
pushd build >/dev/null
../configure $GDB
make
popd >/dev/null
popd >/dev/null
mv ./plugins/SPU2null/build/libSPU2null.so.0.7.1 ./bin/plugins/libSPU2null.so
echo "Building USBnull..."
pushd ./plugins/USBnull >/dev/null
aclocal
autoconf
automake --add-missing
rm -rf autom4te.cache >/dev/null &>/dev/null
rm -rf build >/dev/null &>/dev/null
mkdir build &>/dev/null
pushd build >/dev/null
../configure $GDB
make
popd >/dev/null
popd >/dev/null
mv ./plugins/USBnull/build/libUSBnull.so.0.6.0 ./bin/plugins/libUSBnull.so
echo "Building zeropad..."
pushd ./plugins/zeropad >/dev/null
aclocal
autoconf
automake --add-missing
rm -rf autom4te.cache >/dev/null &>/dev/null
rm -rf build >/dev/null &>/dev/null
mkdir build &>/dev/null
pushd build >/dev/null
../configure $GDB
make
popd >/dev/null
popd >/dev/null
mv ./plugins/zeropad/build/libZeroPad.so.0.3.0 ./bin/plugins/libZeroPad.so
echo "Building zzogl 0.17.156"
pushd ./plugins/zzogl >/dev/null
aclocal
autoconf
automake --add-missing
rm -rf autom4te.cache >/dev/null &>/dev/null
rm -rf build >/dev/null &>/dev/null
mkdir build &>/dev/null
pushd build >/dev/null
../configure --enable-devbuild --enable-sse2 $GDB
make
popd >/dev/null
popd >/dev/null
mv ./plugins/zzogl/build/libZeroGSogl.so.* ./bin/plugins/libZeroGSogl.so
cp ./plugins/zzogl/ps2hw.dat ./bin/plugins

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
../configure --enable-devbuild --enable-sse3 $GDB $DEBUG
make
popd >/dev/null
mv ./build/Linux/pcsx2 ../bin/
popd >/dev/null
chmod +x ./bin/*
