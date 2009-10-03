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
echo "--------------"
echo "Building pcsx2"
echo "--------------"
aclocal
autoconf
automake
./configure --enable-devbuild --enable-sse3
make
mv ./Linux/pcsx2 ./bin/
