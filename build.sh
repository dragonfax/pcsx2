#!/bin/sh
mkdir bin
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
echo "Building CDVDiso..."
pushd ./plugins/CDVDiso/Linux
make
popd
mv ./plugins/CDVDiso/Linux/libCDVDiso.so ./bin/plugins
mv ./plugins/CDVDiso/Linux/cfgCDVDiso ./bin/plugins
echo "Building CDVDnull..."
pushd ./plugins/CDVDnull
make
popd
mv ./plugins/CDVDnull/libCDVDnull.so ./bin/plugins
echo "Building zeropad"
pushd ./plugins/zeropad
aclocal
autoconf
automake
chmod +x ./configure
./configure
make
popd
mv ./plugins/zeropad/libZeroPAD.so.0.2.0 ./bin/plugins/libZeroPad.so
echo "Building Peopsspu2"
pushd ./plugins/PeopsSPU2_SDL
make
popd
mv ./plugins/PeopsSPU2_SDL/libspu2PeopsSDL.so ./bin/plugins
echo "Building spu2null"
pushd ./plugins/SPU2null
aclocal
autoconf
automake
chmod +x ./configure
./configure
make
popd
mv ./plugins/spu2null/libSPU2null.so.0.7.1 ./bin/plugins/libSPU2null.so
mv ./plugins/cfg* ./bin/plugins
chmod +x ./bin/*
mv ./plugins/lib* ./bin/plugins
echo "--------------"
echo "Building pcsx2"
echo "--------------"
aclocal
autoconf
automake
./configure --enable-devbuild --enable-sse3
make
mv ./Linux/pcsx2 ./bin/
