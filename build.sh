#!/bin/sh
if [ !-d bin ]; then
mkdir bin
fi
echo "-------------------"
echo "Building plugins..."
echo "-------------------"
echo "Building CDVDiso..."
pushd ./plugins/CDVDiso/Linux
make 
popd
mv ./plugins/CDVDiso/Linux/libCDVDiso.so ./bin
echo "Building CDVDnull..."
pushd ./plugins/CDVDnull
make
popd
mv ./plugins/CDVDnull/libCDVDnull.so ./bin
echo "--------------"
echo "Building pcsx2"
echo "--------------"
aclocal
autoconf
automake
./configure --enable-devbuild --enable-sse3
make
mv ./Linux/pcsx2 ./bin
