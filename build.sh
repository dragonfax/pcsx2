#!/bin/sh
echo "Building plugins..."
echo "Building CDVDiso..."
pushd ./plugins/CDVDiso/Linux
make
popd
echo "Building CDVDnull..."
pushd ./plugins/CDVDnull
make
popd
echo "Building pcsx2"
aclocal
autoconf
automake
./configure --enable-devbuild --enable-sse3
make
