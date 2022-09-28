#!/usr/bin/env bash

echo
echo "Fetch and install all updates"
sudo apt update && sudo apt upgrade -y

echo
echo "Install cmake, git, wget and nano"
sudo apt install -y cmake git wget nano

export WORK_ROOT=${HOME}/AzureSdkIotCBuilds

echo
echo "Setting WORK_ROOT as ${WORK_ROOT}"
mkdir -p ${WORK_ROOT}

echo
echo "Entering directory ${WORK_ROOT}"
cd ${WORK_ROOT}

export DOWNLOAD_CACHE=${WORK_ROOT}/cache
mkdir -p ${DOWNLOAD_CACHE}
cd ${DOWNLOAD_CACHE}

echo
echo "Downloading toolchain and expanding it"
wget -c https://releases.linaro.org/components/toolchain/binaries/7.5-2019.12/arm-linux-gnueabi/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabi.tar.xz
tar -xvf gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabi.tar.xz -C ${WORK_ROOT}/

echo
echo "Downloading sysroot and expanding it"
wget -c https://releases.linaro.org/components/toolchain/binaries/latest-7/arm-linux-gnueabi/sysroot-glibc-linaro-2.25-2019.12-arm-linux-gnueabi.tar.xz
tar -xvf sysroot-glibc-linaro-2.25-2019.12-arm-linux-gnueabi.tar.xz -C ${WORK_ROOT}/

echo
echo "Downloading OpenSSL source and expanding it"
wget -c https://www.openssl.org/source/openssl-1.0.2o.tar.gz
rm -Rfv ${WORK_ROOT}/openssl-1.0.2o
tar -xvf openssl-1.0.2o.tar.gz -C ${WORK_ROOT}/

echo
echo "Downloading cURL source and expanding it"
wget -c http://curl.haxx.se/download/curl-7.60.0.tar.gz
rm -Rfv ${WORK_ROOT}/curl-7.60.0
tar -xvf curl-7.60.0.tar.gz -C ${WORK_ROOT}/

echo
echo "Downloading the Linux utilities for libuuid and expanding it"
wget -c https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v2.32/util-linux-2.32-rc2.tar.gz
rm -Rfv ${WORK_ROOT}/util-linux-2.32-rc2
tar -xvf util-linux-2.32-rc2.tar.gz -C ${WORK_ROOT}/

# go out from cache directory
cd ${WORK_ROOT}

echo
echo "Downloading Azure IoT Sdk C"
rm -Rf ${WORK_ROOT}/azure-iot-sdk-c
git clone https://github.com/azure/azure-iot-sdk-c.git
cd ${WORK_ROOT}/azure-iot-sdk-c
git submodule update --init
cd ${WORK_ROOT}

echo
echo "Setting up environment variables in preparation for the builds to follow... please wait."
sleep 3
export TOOLCHAIN_ROOT=${WORK_ROOT}/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabi/arm-linux-gnueabi
export TOOLCHAIN_SYSROOT=${WORK_ROOT}/sysroot-glibc-linaro-2.25-2019.12-arm-linux-gnueabi
export TOOLCHAIN_EXES=${WORK_ROOT}/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabi/bin
export TOOLCHAIN_NAME=arm-linux-gnueabi
export AR=${TOOLCHAIN_EXES}/${TOOLCHAIN_NAME}-ar
export AS=${TOOLCHAIN_EXES}/${TOOLCHAIN_NAME}-as
export CC=${TOOLCHAIN_EXES}/${TOOLCHAIN_NAME}-gcc
export LD=${TOOLCHAIN_EXES}/${TOOLCHAIN_NAME}-ld
export NM=${TOOLCHAIN_EXES}/${TOOLCHAIN_NAME}-nm
export RANLIB=${TOOLCHAIN_EXES}/${TOOLCHAIN_NAME}-ranlib

export LDFLAGS="-L${TOOLCHAIN_SYSROOT}/usr/lib"
export LIBS="-lssl -lcrypto -ldl -lpthread"
export TOOLCHAIN_PREFIX=${TOOLCHAIN_SYSROOT}/usr

# Copy pthread lib. For a unknown reason a symbolic link it is not working.
cp -v ${TOOLCHAIN_SYSROOT}/lib/*thread* ${TOOLCHAIN_SYSROOT}/usr/lib

# Fix .so scripts
sed -i "s+/lib/libpthread.so.0+libpthread.so.0+" ${TOOLCHAIN_SYSROOT}/usr/lib/libpthread.so
sed -i 's+/usr/lib/libpthread_nonshared.a+libpthread_nonshared.a+g' ${TOOLCHAIN_SYSROOT}/usr/lib/libpthread.so
sed -i 's+/lib/libc.so.6+libc.so.6+g' ${TOOLCHAIN_SYSROOT}/usr/lib/libc.so
sed -i 's+/usr/lib/libc_nonshared.a+libc_nonshared.a+g' ${TOOLCHAIN_SYSROOT}/usr/lib/libc.so
sed -i 's+/lib/ld-linux.so.3+ld-linux.so.3+g' ${TOOLCHAIN_SYSROOT}/usr/lib/libc.so

echo
echo "Building OpenSSL"
sleep 3
cd ${WORK_ROOT}/openssl-1.0.2o
./Configure linux-generic32 shared --prefix=${TOOLCHAIN_PREFIX} --openssldir=${TOOLCHAIN_PREFIX}
make
make install
cd ${WORK_ROOT}

echo
echo "Building cURL"
sleep 3
cd ${WORK_ROOT}/curl-7.60.0
./configure --with-sysroot=${TOOLCHAIN_SYSROOT} --prefix=${TOOLCHAIN_PREFIX} --target=${TOOLCHAIN_NAME} --host=${TOOLCHAIN_NAME} --with-ssl=${TOOLCHAIN_PREFIX} --with-zlib  --build=x86_64-pc-linux
make
make install
cd ${WORK_ROOT}

echo
echo "Building uuid"
sleep 3
cd ${WORK_ROOT}/util-linux-2.32-rc2
./configure --prefix=${TOOLCHAIN_PREFIX} --with-sysroot=${TOOLCHAIN_SYSROOT} --target=${TOOLCHAIN_NAME} --host=${TOOLCHAIN_NAME} --disable-all-programs  --disable-bash-completion --enable-libuuid
make
make install
cd ${WORK_ROOT}

# To build the SDK we need to create a cmake toolchain file. This tells cmake to use the tools in the
# toolchain rather than those on the host
cd ${WORK_ROOT}/azure-iot-sdk-c

echo
echo "Creating a working directory for the cmake operations"
mkdir -p cmake
cd cmake

echo
echo "Creating a cmake toolchain file..."
sleep 3
echo "SET(CMAKE_SYSTEM_NAME Linux)     # this one is important" > toolchain.cmake
echo "SET(CMAKE_SYSTEM_VERSION 1)      # this one not so much" >> toolchain.cmake
echo "SET(CMAKE_SYSROOT ${TOOLCHAIN_SYSROOT})" >> toolchain.cmake
echo "SET(CMAKE_C_COMPILER ${TOOLCHAIN_EXES}/${TOOLCHAIN_NAME}-gcc)" >> toolchain.cmake
echo "SET(CMAKE_CXX_COMPILER ${TOOLCHAIN_EXES}/${TOOLCHAIN_NAME}-g++)" >> toolchain.cmake
echo "SET(CMAKE_FIND_ROOT_PATH $ENV{TOOLCHAIN_SYSROOT})" >> toolchain.cmake
echo "SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)" >> toolchain.cmake
echo "SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)" >> toolchain.cmake
echo "SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)" >> toolchain.cmake
echo "SET(set_trusted_cert_in_samples true CACHE BOOL \"Force use of TrustedCerts option\" FORCE)" >> toolchain.cmake

echo
echo "Building the Azure SDK... This will use the OpenSSL, cURL and uuid binaries."
sleep 3
cmake -DCMAKE_TOOLCHAIN_FILE=toolchain.cmake -DCMAKE_INSTALL_PREFIX=${WORK_ROOT}/azure-sdk-binaries ..
make
make install

sleep 1

# echo
# echo "Finally a sanity check to make sure the files are there..."
ls -al ${WORK_ROOT}/azure-sdk-binaries/lib
ls -al ${WORK_ROOT}/azure-sdk-binaries/include

# Go to project root
cd ${WORK_ROOT}

sleep 1

echo
echo "Azure SDK IoT Libs have been installed in ${WORK_ROOT}/azure-sdk-binaries"
echo "Azure SDK IoT Includes have been installed in ${WORK_ROOT}/azure-sdk-binaries"

sleep 1

echo 
echo "DONE!"

sleep 1

echo "(╯°□°）╯ ︵ ┻━┻"