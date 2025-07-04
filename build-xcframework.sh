#!/bin/sh

PATH=$PATH:/usr/local/bin:/usr/local/opt/gettext/bin:/usr/local/opt/automake/bin:/usr/local/opt/aclocal/bin:/opt/homebrew/bin

XZ_VERSION="v5.8.1"
OPENSSL_VERSION="openssl-3.5.1"
LIBEVENT_VERSION="release-2.1.12-stable"
TOR_VERSION="tor-0.4.8.17"

cd "$(dirname "$0")"
ROOT="$(pwd -P)"

DEBUG=""

while getopts dl flag
do
    case "$flag" in
        d) DEBUG="1";;
    esac
done

if [ -z $DEBUG ]; then
    BUILDDIR="$(mktemp -d)"
else
    BUILDDIR="$ROOT/build"
    mkdir -p "$BUILDDIR"
fi

echo "Build dir: $BUILDDIR"

build_liblzma() {
    SDK=$1
    ARCH=$2
    MIN=$3

    SOURCE="$BUILDDIR/xz"
    LOG="$BUILDDIR/liblzma-$SDK-$ARCH.log"

    if [ ! -d "$SOURCE" ]; then
        echo "- Check out XZ project"

        cd "$BUILDDIR"
        git clone --recursive --shallow-submodules --depth 1 --branch "$XZ_VERSION" https://github.com/tukaani-project/xz.git >> "$LOG" 2>&1
    fi

    echo "- Build liblzma for $ARCH ($SDK)"

    cd "$SOURCE"

    make distclean 2>/dev/null 1>/dev/null

    # Generate the configure script.
    if [ ! -f ./configure ]; then
        LIBTOOLIZE=glibtoolize
        ./autogen.sh >> "$LOG" 2>&1
    fi

    SDKPATH="$(xcrun --sdk ${SDK} --show-sdk-path)"
    CLANG="$(xcrun -f --sdk ${SDK} clang)"

    ./configure \
        --disable-shared \
        --enable-static \
        --disable-doc \
        --disable-scripts \
        --disable-xz \
        --disable-xzdec \
        --disable-lzmadec \
        --disable-lzmainfo \
        --disable-lzma-links \
        --prefix "$BUILDDIR/$SDK/liblzma-$ARCH" \
        CC="$CLANG -arch ${ARCH}" \
        CPP="$CLANG -E -arch ${ARCH}" \
        CFLAGS="-isysroot ${SDKPATH} -m$SDK-version-min=$MIN -fembed-bitcode -Wno-unknown-warning-option" \
        LDFLAGS="-isysroot ${SDKPATH} -fembed-bitcode" \
        cross_compiling="yes" \
        ac_cv_func_clock_gettime="no" \
        >> "$LOG" 2>&1

    make -j$(sysctl -n hw.logicalcpu_max) >> "$LOG" 2>&1
    make install >> "$LOG" 2>&1
}

build_libssl() {
    SDK=$1
    ARCH=$2
    MIN=$3

    SOURCE="$BUILDDIR/openssl"
    LOG="$BUILDDIR/libssl-$SDK-$ARCH.log"

    if [ ! -d "$SOURCE" ]; then
        echo "- Check out OpenSSL project"

        cd "$BUILDDIR"
        git clone --recursive --shallow-submodules --depth 1 --branch "$OPENSSL_VERSION" https://github.com/openssl/openssl.git >> "$LOG" 2>&1
    fi

    echo "- Build OpenSSL for $ARCH ($SDK)"

    cd "$SOURCE"

    make distclean >> "$LOG" 2>&1

    if [ "$SDK" = "iphoneos" ]; then
        if [ "$ARCH" = "arm64" ]; then
            PLATFORM_FLAGS="no-async zlib-dynamic enable-ec_nistp_64_gcc_128"
            CONFIG="ios64-xcrun"
        elif [ "$ARCH" = "armv7" ]; then
            PLATFORM_FLAGS="no-async zlib-dynamic"
            CONFIG="ios-xcrun"
        else
            echo "OpenSSL configuration error: $ARCH on $SDK not supported!"
        fi
    elif [ "$SDK" = "iphonesimulator" ]; then
        if [ "$ARCH" = "arm64" ]; then
            PLATFORM_FLAGS="no-async zlib-dynamic enable-ec_nistp_64_gcc_128"
            CONFIG="iossimulator-xcrun"
        elif [ "$ARCH" = "i386" ]; then
            PLATFORM_FLAGS="no-asm"
            CONFIG="iossimulator-xcrun"
        elif [ "$ARCH" = "x86_64" ]; then
            PLATFORM_FLAGS="no-asm enable-ec_nistp_64_gcc_128"
            CONFIG="iossimulator-xcrun"
        else
            echo "OpenSSL configuration error: $ARCH on $SDK not supported!"
        fi
    elif [ "$SDK" = "macosx" ]; then
        if [ "$ARCH" = "i386" ]; then
            PLATFORM_FLAGS="no-asm"
            CONFIG="darwin-i386-cc"
        elif [ "$ARCH" = "x86_64" ]; then
            PLATFORM_FLAGS="no-asm enable-ec_nistp_64_gcc_128"
            CONFIG="darwin64-x86_64-cc"
        elif [ "$ARCH" = "arm64" ]; then
            PLATFORM_FLAGS="no-asm enable-ec_nistp_64_gcc_128"
            CONFIG="darwin64-arm64-cc"
        else
            echo "OpenSSL configuration error: $ARCH on $SDK not supported!"
        fi
    fi

    if [ -n "$CONFIG" ]; then
        ./Configure \
            no-shared \
            ${PLATFORM_FLAGS} \
            --prefix="$BUILDDIR/$SDK/libssl-$ARCH" \
            ${CONFIG} \
            CC="$(xcrun --sdk $SDK --find clang) -isysroot $(xcrun --sdk $SDK --show-sdk-path) -arch ${ARCH} -m$SDK-version-min=$MIN -fembed-bitcode" \
            >> "$LOG" 2>&1

        make depend >> "$LOG" 2>&1
        make "-j$(sysctl -n hw.logicalcpu_max)" build_libs >> "$LOG" 2>&1
        make install_dev >> "$LOG" 2>&1
    fi
}

build_libevent() {
    SDK=$1
    ARCH=$2
    MIN=$3

    SOURCE="$BUILDDIR/libevent"
    LOG="$BUILDDIR/libevent-$SDK-$ARCH.log"

    if [ ! -d "$SOURCE" ]; then
        echo "- Check out libevent project"

        cd "$BUILDDIR"
        git clone --recursive --shallow-submodules --depth 1 --branch "$LIBEVENT_VERSION" https://github.com/libevent/libevent.git >> "$LOG" 2>&1
    fi

    echo "- Build libevent for $ARCH ($SDK)"

    cd "$SOURCE"

    make distclean 2>/dev/null 1>/dev/null

    # Generate the configure script.
    if [ ! -f ./configure ]; then
        ./autogen.sh >> "$LOG" 2>&1
    fi

    CLANG="$(xcrun -f --sdk ${SDK} clang)"
    SDKPATH="$(xcrun --sdk ${SDK} --show-sdk-path)"
    DEST="$BUILDDIR/$SDK/libevent-$ARCH"

    ./configure \
        --disable-shared \
        --disable-openssl \
        --disable-libevent-regress \
        --disable-samples \
        --disable-doxygen-html \
        --enable-static \
        --enable-gcc-hardening \
        --disable-debug-mode \
        --prefix="$DEST" \
        CC="$CLANG -arch ${ARCH}" \
        CPP="$CLANG -E -arch ${ARCH}" \
        CFLAGS="-isysroot ${SDKPATH} -m$SDK-version-min=$MIN -fembed-bitcode" \
        LDFLAGS="-isysroot ${SDKPATH} -L$DEST -fembed-bitcode" \
        cross_compiling="yes" \
        ac_cv_func_clock_gettime="no" \
        >> "$LOG" 2>&1

    make -j$(sysctl -n hw.logicalcpu_max) >> "$LOG" 2>&1
    make install >> "$LOG" 2>&1
}

build_libtor() {
    SDK=$1
    ARCH=$2
    MIN=$3
    NO_LZMA=$4

    SOURCE="$BUILDDIR/tor"

    if [ -z "$NO_LZMA" ]; then
        LOG="$BUILDDIR/libtor-$SDK-$ARCH.log"
        LZMA="yes"
        DEST="$BUILDDIR/$SDK/libtor-$ARCH"
    else
        LOG="$BUILDDIR/libtor-nolzma-$SDK-$ARCH.log"
        LZMA="no"
        DEST="$BUILDDIR/$SDK/libtor-nolzma-$ARCH"
    fi

    if [ ! -d "$SOURCE" ]; then
        echo "- Check out Tor project"

        cd "$BUILDDIR"
        git clone --recursive --shallow-submodules --depth 1 --branch "$TOR_VERSION" https://gitlab.torproject.org/tpo/core/tor.git >> "$LOG" 2>&1
    fi

    if [ -z "$NO_LZMA" ]; then
        echo "- Build libtor for $ARCH ($SDK)"
    else
        echo "- Build libtor-nolzma for $ARCH ($SDK)"
    fi

    cd "$SOURCE"

    make distclean 2>/dev/null 1>/dev/null

    ## Apply patches:
    git apply --quiet "$ROOT/Tor/mmap-cache.patch"

    # Generate the configure script.
    if [ ! -f ./configure ]; then
        # FIXME: This fixes `Tor/tor/autogen.sh`. Check if that was changed and remove this patch.
        sed -i'.backup' -e 's/all,error/no-obsolete,error/' autogen.sh

        ./autogen.sh >> "$LOG" 2>&1

        # FIXME: Undoes the patch. Remove, when it becomes unnecessary.
        rm autogen.sh && mv autogen.sh.backup autogen.sh
    fi

    CLANG="$(xcrun -f --sdk ${SDK} clang)"
    SDKPATH="$(xcrun --sdk ${SDK} --show-sdk-path)"

    ./configure \
        --enable-silent-rules \
        --enable-pic \
        --disable-module-relay \
        --disable-module-dirauth \
        --disable-tool-name-check \
        --disable-unittests \
        --enable-static-openssl \
        --enable-static-libevent \
        --disable-asciidoc \
        --disable-system-torrc \
        --disable-linker-hardening \
        --disable-dependency-tracking \
        --disable-manpage \
        --disable-html-manual \
        --disable-gcc-warnings-advisory \
        --enable-lzma="$LZMA" \
        --disable-zstd \
        --with-libevent-dir="$BUILDDIR/$SDK/libevent-$ARCH" \
        --with-openssl-dir="$BUILDDIR/$SDK/libssl-$ARCH" \
        --prefix="$DEST" \
        CC="$CLANG -arch ${ARCH} -isysroot ${SDKPATH}" \
        CPP="$CLANG -E -arch ${ARCH} -isysroot ${SDKPATH}" \
        CPPFLAGS="-fembed-bitcode -Isrc/core -I$BUILDDIR/$SDK/libssl-$ARCH/include -I$BUILDDIR/$SDK/libevent-$ARCH/include -m$SDK-version-min=$MIN" \
        LDFLAGS="-lz -fembed-bitcode" \
        LZMA_CFLAGS="-I$BUILDDIR/$SDK/liblzma-$ARCH/include" \
        LZMA_LIBS="$BUILDDIR/$SDK/liblzma-$ARCH/lib/liblzma.a" \
        cross_compiling="yes" \
        ac_cv_func__NSGetEnviron="no" \
        ac_cv_func_clock_gettime="no" \
        ac_cv_func_getentropy="no" \
        >> "$LOG" 2>&1

    # There seems to be a race condition with the above configure and the later cp.
    # Just sleep a little so the correct file is copied and delete the old one before.
    sleep 2
    rm -f src/lib/cc/orconfig.h >> "$LOG" 2>&1
    cp orconfig.h "src/lib/cc/" >> "$LOG" 2>&1

    make libtor.a -j$(sysctl -n hw.logicalcpu_max) V=1 >> "$LOG" 2>&1

    mkdir -p "$DEST/lib" >> "$LOG" 2>&1
    mkdir -p "$DEST/include" >> "$LOG" 2>&1
    mv libtor.a "$DEST/lib" >> "$LOG" 2>&1
    rsync --archive --include='*.h' -f 'hide,! */' --prune-empty-dirs src/* "$DEST/include" >> "$LOG" 2>&1
    cp orconfig.h "$DEST/include/" >> "$LOG" 2>&1

    mv micro-revision.i "$DEST" >> "$LOG" 2>&1
}

fatten() {
    NAME=$1
    SDK=$2
    LIB=${3:-$NAME}

    echo "- Fatten $LIB in $NAME ($SDK)"

    mkdir -p "$BUILDDIR/$SDK/$NAME/lib"

    lipo \
        -arch arm64 "$BUILDDIR/$SDK/$NAME-arm64/lib/$LIB.a" \
        -arch x86_64 "$BUILDDIR/$SDK/$NAME-x86_64/lib/$LIB.a" \
        -create -output "$BUILDDIR/$SDK/$NAME/lib/$LIB.a"
}

create_framework() {
    SDK=$1
    IS_FAT=$2
    NO_LZMA=$3

    if [ -z "$NO_LZMA" ]; then
        NAME="tor"
    else
        NAME="tor-nolzma"
    fi

    rm -rf "$BUILDDIR/$SDK/$NAME.framework"
    mkdir -p "$BUILDDIR/$SDK/$NAME.framework/Headers"

    if [ -z "$IS_FAT" ]; then
        echo "- Create framework for $SDK"

        POSTFIX="-arm64"
    else
        echo "- Create framework for fat $SDK"

        POSTFIX=""
    fi

    if [ -z "$NO_LZMA" ]; then
        LIBS=("$BUILDDIR/$SDK/libssl$POSTFIX/lib/libssl.a" \
            "$BUILDDIR/$SDK/libssl$POSTFIX/lib/libcrypto.a" \
            "$BUILDDIR/$SDK/libevent$POSTFIX/lib/libevent.a" \
            "$BUILDDIR/$SDK/liblzma$POSTFIX/lib/liblzma.a" \
            "$BUILDDIR/$SDK/libtor$POSTFIX/lib/libtor.a")
    else
        LIBS=("$BUILDDIR/$SDK/libssl$POSTFIX/lib/libssl.a" \
            "$BUILDDIR/$SDK/libssl$POSTFIX/lib/libcrypto.a" \
            "$BUILDDIR/$SDK/libevent$POSTFIX/lib/libevent.a" \
            "$BUILDDIR/$SDK/libtor-nolzma$POSTFIX/lib/libtor.a")
    fi

    libtool -static -o "$BUILDDIR/$SDK/$NAME.framework/$NAME" "${LIBS[@]}"

    HEADERS=("$BUILDDIR/$SDK/libssl-arm64/include"/* \
        "$BUILDDIR/$SDK/libevent-arm64/include"/* \
        "$BUILDDIR/$SDK/libtor-arm64/include"/*)

    if [ ! -z "$NO_LZMA" ]; then
        HEADERS=("$BUILDDIR/$SDK/liblzma-arm64/include"/* "${HEADERS[@]}")
    fi

    cp -r "${HEADERS[@]}" "$BUILDDIR/$SDK/$NAME.framework/Headers"
}

build_liblzma       iphoneos            arm64           12.0
build_libssl        iphoneos            arm64           12.0
build_libevent      iphoneos            arm64           12.0
build_libtor        iphoneos            arm64           12.0
build_libtor        iphoneos            arm64           12.0    nolzma
create_framework    iphoneos
create_framework    iphoneos            ""              nolzma

build_liblzma       iphonesimulator     arm64           12.0
build_liblzma       iphonesimulator     x86_64          12.0
fatten              liblzma             iphonesimulator
build_libssl        iphonesimulator     arm64           12.0
build_libssl        iphonesimulator     x86_64          12.0
fatten              libssl              iphonesimulator
fatten              libssl              iphonesimulator libcrypto
build_libevent      iphonesimulator     arm64           12.0
build_libevent      iphonesimulator     x86_64          12.0
fatten              libevent            iphonesimulator
build_libtor        iphonesimulator     arm64           12.0
build_libtor        iphonesimulator     x86_64          12.0
fatten              libtor              iphonesimulator
build_libtor        iphonesimulator     arm64           12.0    nolzma
build_libtor        iphonesimulator     x86_64          12.0    nolzma
fatten              libtor-nolzma       iphonesimulator libtor
create_framework    iphonesimulator     fat
create_framework    iphonesimulator     fat             nolzma

build_liblzma       macosx              arm64           10.13
build_liblzma       macosx              x86_64          10.13
fatten              liblzma             macosx
build_libssl        macosx              arm64           10.13
build_libssl        macosx              x86_64          10.13
fatten              libssl              macosx
fatten              libssl              macosx          libcrypto
build_libevent      macosx              arm64           10.13
build_libevent      macosx              x86_64          10.13
fatten              libevent            macosx
build_libtor        macosx              arm64           10.13
build_libtor        macosx              x86_64          10.13
fatten              libtor              macosx
build_libtor        macosx              arm64           10.13    nolzma
build_libtor        macosx              x86_64          10.13    nolzma
fatten              libtor-nolzma       macosx          libtor
create_framework    macosx              fat
create_framework    macosx              fat             nolzma

echo "- Create xcframework"

rm -rf "$ROOT/tor.xcframework" "$ROOT/tor-nolzma.xcframework"

xcodebuild -create-xcframework \
    -framework "$BUILDDIR/iphoneos/tor.framework" \
    -framework "$BUILDDIR/iphonesimulator/tor.framework" \
    -framework "$BUILDDIR/macosx/tor.framework" \
    -output "$ROOT/tor.xcframework"

xcodebuild -create-xcframework \
    -framework "$BUILDDIR/iphoneos/tor-nolzma.framework" \
    -framework "$BUILDDIR/iphonesimulator/tor-nolzma.framework" \
    -framework "$BUILDDIR/macosx/tor-nolzma.framework" \
    -output "$ROOT/tor-nolzma.xcframework"

if [ -z $DEBUG ]; then
    rm -rf "$BUILDDIR"
fi
