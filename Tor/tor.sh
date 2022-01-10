#!/bin/bash

ARCHS=($ARCHS)

# We need gettext to build Tor.
# This extends the path to look in some common locations (for example, if installed via Homebrew).
PATH=$PATH:/usr/local/bin:/usr/local/opt/gettext/bin:/usr/local/opt/automake/bin:/usr/local/opt/aclocal/bin:/opt/homebrew/bin

# Disable PT_DENY_ATTACH because it is private API.
PSEUDO_SYS_INCLUDE_DIR="${CONFIGURATION_TEMP_DIR}/tor-sys"
mkdir -p "${PSEUDO_SYS_INCLUDE_DIR}/sys"
touch "${PSEUDO_SYS_INCLUDE_DIR}/sys/ptrace.h"

if [[ "${BITCODE_GENERATION_MODE}" = "bitcode" ]]; then
    BITCODE_CFLAGS="-fembed-bitcode"
elif [[ "${BITCODE_GENERATION_MODE}" = "marker" ]]; then
    BITCODE_CFLAGS="-fembed-bitcode-marker"
fi

if [[ "${CONFIGURATION}" = "Debug" ]]; then
    DEBUG_CFLAGS="-g -O0"
fi

mkdir -p "${BUILT_PRODUCTS_DIR}"

LAST_CONFIGURED_ARCH=

function configure {
    ARCH=$1

    # Don't re-run, if we already configured this architecture recently.
    if [[ $LAST_CONFIGURED_ARCH = $ARCH ]]; then
        return
    fi

    # FIXME: Compiling Tor 0.4.4.7 and higher breaks for an unknown reason, when
    # OpenSSL engine support is switched on (default). Therefore, we switch it
    # off with `-DOPENSSL_NO_ENGINE`. Remove that, when the underlying problem
    # is fixed!

    ./configure --enable-silent-rules --enable-pic --disable-module-relay --disable-tool-name-check --disable-unittests --enable-static-openssl --enable-static-libevent --disable-asciidoc --disable-system-torrc --disable-linker-hardening --disable-dependency-tracking --disable-manpage --disable-html-manual --prefix="${CONFIGURATION_TEMP_DIR}/tor-${ARCH}" --with-libevent-dir="${BUILT_PRODUCTS_DIR}" --with-openssl-dir="${BUILT_PRODUCTS_DIR}" --enable-lzma --enable-zstd=no CC="$(xcrun -f --sdk ${PLATFORM_NAME} clang) -arch ${ARCH} -isysroot ${SDKROOT}" CPP="$(xcrun -f --sdk ${PLATFORM_NAME} clang) -E -arch ${ARCH} -isysroot ${SDKROOT}" CPPFLAGS="${DEBUG_CFLAGS} ${BITCODE_CFLAGS} -I${SRCROOT}/Tor/tor/src/core -I${SRCROOT}/Tor/include -I${SRCROOT}/Tor/openssl/include -I${BUILT_PRODUCTS_DIR}/openssl-${ARCH} -I${SRCROOT}/Tor/libevent/include -I${BUILT_PRODUCTS_DIR}/libevent-${ARCH} -I${BUILT_PRODUCTS_DIR}/liblzma-${ARCH} -I${PSEUDO_SYS_INCLUDE_DIR} -isysroot ${SDKROOT} -DOPENSSL_NO_ENGINE" cross_compiling="yes" ac_cv_func__NSGetEnviron="no" ac_cv_func_clock_gettime="no" ac_cv_func_getentropy="no" LDFLAGS="-lz ${BITCODE_CFLAGS}"

    LAST_CONFIGURED_ARCH=$ARCH
}

REBUILD=0

# Generate the configure script (necessary for version control distributions)
if [[ ! -f ./configure ]]; then
    # FIXME: This fixes `Tor/tor/autogen.sh`. Check if that was changed and remove this patch.
    sed -i'.backup' -e 's/all,error/no-obsolete,error/' autogen.sh

    ./autogen.sh

    # FIXME: Undoes the patch. Remove, when it becomes unnecessary.
    rm autogen.sh && mv autogen.sh.backup autogen.sh

    # make show-libs needs a full configure, otherwise it will trigger that and return a lot of garbage.
    configure ${ARCHS[0]}

    REBUILD=1
fi

declare -a LIBS=$(make show-libs)
echo "LIBRARIES: ${LIBS[@]}"

# If the built binaries include a different set of architectures, then rebuild the target.
if [[ ${ACTION:-build} = "build" ]] || [[ $ACTION = "install" ]]; then
    for LIB in ${LIBS[@]}
    do
        for ARCH in ${ARCHS[@]}
        do
            if [[ $(lipo -info "${BUILT_PRODUCTS_DIR}/$(basename $LIB)" 2>&1) != *"${ARCH}"* ]]; then
                REBUILD=1;
            fi
        done
    done
fi

# If rebuilding or cleaning then delete the built products.
if [[ ${ACTION:-build} = "clean" ]] || [[ $REBUILD = 1 ]]; then
    make clean 2> /dev/null
    for LIB in ${LIBS[@]}
    do
        rm "${BUILT_PRODUCTS_DIR}/$(basename $LIB)" 2> /dev/null
    done
fi

# If cleaning or no rebuild, we're done.
if [[ ${ACTION:-build} = "clean" ]] || [[ $REBUILD = 0 ]]; then
    exit;
fi


# Build each architecture one by one using clang.
for ARCH in ${ARCHS[@]}
do
    make clean

    configure $ARCH

    # There seems to be a race condition with the above configure and the later cp.
    # Just sleep a little so the correct file is copied and delete the old one before.
    sleep 2s
    rm src/lib/cc/orconfig.h
    cp orconfig.h "src/lib/cc/"

    make -j$(sysctl hw.ncpu | awk '{print $2}')

    cp micro-revision.i "${BUILT_PRODUCTS_DIR}/micro-revision.i"

    for LIB in ${LIBS[@]}
    do
        cp $LIB "${BUILT_PRODUCTS_DIR}/$(basename $LIB).${ARCH}.a"
    done

    make clean
done

# Combine the built products into a fat binary.
for LIB in ${LIBS[@]}
do
    FILENAME=$(basename $LIB)

    xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/$FILENAME."*.a -output "${BUILT_PRODUCTS_DIR}/$FILENAME"
    rm "${BUILT_PRODUCTS_DIR}/$FILENAME."*.a
done
