#!/bin/sh
aclocal
autoconf
automake
./configure --enable-devbuild --enable-sse3
make
