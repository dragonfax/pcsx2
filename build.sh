#!/bin/sh

# check if gdb support is requested
if [ $1 == "--enable-gdb" ]; then
	GDB="--enable-gdb"
fi
pushd bin
mkdir bios
mkdir frames
mkdir help
mkdir logs
mkdir plugins
mkdir sstates
popd
echo "-------------------"
echo "Building plugins..."
echo "-------------------"
echo "Building CDVDnull..."
pushd ./plugins/CDVDnull
aclocal
autoconf
automake --add-missing
popd
mv ./plugins/CDVDnull/libCDVDnull.so.0.8.0 ./bin/plugins/libCDVDnull.so
echo "Building CDVDiso..."
pushd ./plugins/CDVDiso/src
aclocal
autoconf
automake --add-missing
popd
mv ./plugins/CDVDiso/src/libCDVDiso.so.0.9.0 ./bin/plugins/libCDVDiso.so
echo "Building zzogl 0.17.156"
pushd ./plugins/zzogl
aclocal
autoconf
automake
./configure --enable-devbuild --enable-sse2 $GDB
make
popd
mv ./plugins/zzogl/libZeroGSogl.so.* ./bin/plugins/libZeroGSogl.so
cp ./plugins/zzogl/ps2hw.dat ./bin/plugins
chmod +x ./bin/*
