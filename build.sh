#!/bin/sh
mkdir bin
echo "-------------------"
echo "Building plugins..."
echo "-------------------"
echo "Building CDVDiso..."
pushd ./plugins/CDVDiso/Linux
make 
popd
mv ./plugins/CDVDiso/Linux/libCDVDiso.so ./bin/
echo "Building CDVDnull..."
pushd ./plugins/CDVDnull
make
popd
mv ./plugins/CDVDnull/libCDVDnull.so ./bin/
echo "Building zeropad"
pushd ./plugins/zeropad
aclocal
autoconf
automake
chmod +x ./configure
./configure
make
popd
mv ./plugins/zeropad/libZeroPAD.so.0.2.0 ./bin/libZeroPad.so
echo "Building Peopsspu2"
pushd ./plugins/PeopsSPU2_SDL
make
popd
mv ./plugins/PeopsSPU2_SDL/libspu2PeopsSDL.so ./bin/
echo "Building spu2null"
pushd ./plugins/SPU2null
aclocal
autoconf
automake
chmod +x ./configure
./configure
make
popd
mv ./plugins/spu2null/libSPU2null.so.0.7.1 ./bin/libSPU2null.so
echo "--------------"
echo "Building pcsx2"
echo "--------------"
aclocal
autoconf
automake
./configure --enable-devbuild --enable-sse3
make
mv ./Linux/pcsx2 ./bin/
