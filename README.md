# build-env
This project aims at providing a deployment environment for Qt Applications on Linux. If you follow the steps below you should end up with the ability to build:
* 32-/64-bit Qt Applications for Linux
* 32-/64-bit Qt Applications for Windows
* 64-bit Qt Applications for Mac
* Installers for the platforms above with statically linked Qt

## prerequisites
* system with rather old glibc version

## tl;dr
If you just want to jump start you may want to execute the auto.sh script. Ignore the comments, they are just a hint for the parsing going on in the script.

    ./auto.sh # _DONT_EXECUTE_

You may override default paths and versions.

    GCC_VERSION=5.4.0 # _DONT_EXECUTE_
    GCC_PREFIX=/opt/gcc-$GCC_VERSION # _DONT_EXECUTE_

    LLVM_VERSION=4.0.1 # _DONT_EXECUTE_
    LLVM_PREFIX=/opt/llvm-$LLVM_VERSION # _DONT_EXECUTE_

    QT_LINUX_64_PREFIX=/opt/qt-5.6.0-linux-x86_64 # _DONT_EXECUTE_
    QT_LINUX_64_STATIC_PREFIX=/opt/qt-5.6.0-linux-x86_64-static # _DONT_EXECUTE_

    ./auto.sh # _DONT_EXECUTE_

You may disable optional tools.

    BUILD_GCC=no # _DONT_EXECUTE_
    BUILD_LLVM=no # _DONT_EXECUTE_
    BUILD_GIT=no # _DONT_EXECUTE_
    BUILD_CMAKE=no # _DONT_EXECUTE_

    ./auto.sh # _DONT_EXECUTE_

### debian wheezy
Install the following packages:

    su -c "
      # libxcb-xkb-dev is found in wheezy-backports repository
      echo 'deb http://ftp.debian.org/debian wheezy-backports main' >> /etc/apt/sources.list

      apt-get update
      apt-get install \
        tar bzip2 zip debootstrap \
        build-essential make bison gettext texinfo gcc-multilib g++-multilib \
        gtk2.0-dev libglib2.0-dev \
        libcups2-dev \
        libdbus-1-dev \
        libproxy-dev \
        libicu-dev \
        libglu1-mesa-dev libegl1-mesa-dev \
        '^libxcb.*-dev' libx11-xcb-dev libxrender-dev libxi-dev libxcb-xkb-dev \
        libssl-dev \
        libfontconfig1-dev
    "

#### 32-bit Linux environment

    # change path to you liking, this is where the 32-bit debian system is going to be installed
    [ "$CHROOT" == "" ] && CHROOT=/chroot-32

    su -c "
      [ -d \"$CHROOT\" ] || mkdir $CHROOT

      # delete .done file to rebuild
      [ -f \"$CHROOT/.done\" ] || {
        debootstrap --arch i386 wheezy \"$CHROOT\" http://httpredir.debian.org/debian/
        mount --bind /dev \"$CHROOT/dev\"
        mount --bind /dev/pts \"$CHROOT/dev/pts\"
        chroot \"$CHROOT\"
        mount -t proc proc /proc
        mount -t sys sysfs /sys

        # libxcb-xkb-dev is found in wheezy-backports repository
        echo 'deb http://ftp.debian.org/debian wheezy-backports main' >> /etc/apt/sources.list

        apt-get update
        apt-get install \
          tar bzip2 zip debootstrap \
          build-essential make bison gettext texinfo gcc-multilib g++-multilib \
          gtk2.0-dev libglib2.0-dev \
          libcups2-dev \
          libdbus-1-dev \
          libproxy-dev \
          libicu-dev \
          libglu1-mesa-dev libegl1-mesa-dev \
          '^libxcb.*-dev' libx11-xcb-dev libxrender-dev libxi-dev libxcb-xkb-dev \
          libssl-dev \
          libfontconfig1-dev

        touch /.done
        exit
      }
    "

#### libxkbcommon
Since this library is not present on debian wheezy we have to build it ourselves.

    [ -f "libxkbcommon-0.4.1.tar.xz" ] || {
      wget --no-check-certificate http://xkbcommon.org/download/libxkbcommon-0.4.1.tar.xz
      tar xf libxkbcommon-0.4.1.tar.xz
    }

    # delete .done file to rebuild
    [ -f "libxkbcommon-0.4.1/.done" ] || {
      cd libxkbcommon-0.4.1
      ./configure
      make
      su -c "make install"
      touch .done
      cd ..
    }

### GCC 5.4.0 (optional)
If you want to build your application with recent C++ features a recent GCC is mandatory.

    # change version to your liking
    [ "$GCC_VERSION" == "" ] && GCC_VERSION=5.4.0
    # change prefix to you liking, this is where the new gcc is going to be installed
    [ "$GCC_PREFIX" == "" ] && GCC_PREFIX=/opt/gcc-$GCC_VERSION

    # delete installation folder of previous build to rebuild
    [ "$BUILD_GCC" == "no" ] || [ -d "$GCC_PREFIX" ] || {
      [ -f "gcc-$GCC_VERSION.tar.bz2" ] || {
        wget --no-check-certificate https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.bz2
        tar xf gcc-$GCC_VERSION.tar.bz2
        cd gcc-$GCC_VERSION/contrib
        ./download_prerequisites
        cd ../../
      }

      mkdir build-gcc
      cd build-gcc

      ../gcc-$GCC_VERSION/configure --prefix="$GCC_PREFIX" --enable-languages=c,c++
      make
      su -c "
        make install
        ln -sf "$GCC_PREFIX/bin/gcc" "$GCC_PREFIX/bin/cc"
      "
      cd ..

      # configure ld to find our newly built libraries
      su -c "
        echo \"$GCC_PREFIX/lib\" > /etc/ld.so.conf.d/gcc-$GCC_VERSION.conf
        echo \"$GCC_PREFIX/lib32\" >> /etc/ld.so.conf.d/gcc-$GCC_VERSION.conf
        echo \"$GCC_PREFIX/lib64\" >> /etc/ld.so.conf.d/gcc-$GCC_VERSION.conf
        ldconfig
      "

      # Update PATH so our newly built gcc is used instead of the system provided one. You might want to make this sticky in your bash startup scripts (~/.bashrc and the like).
      export PATH=$GCC_PREFIX/bin:$PATH
    }

### CMake 3.9.0 (optional)
Follow these steps if you want to build LLVM/Clang or just need a more recent CMake.

    [ -f "cmake-3.9.0.tar.gz" ] || {
      wget https://cmake.org/files/v3.9/cmake-3.9.0.tar.gz
      tar xf cmake-3.9.0.tar.gz
    }

    # delete .done file to rebuild
    [ "$BUILD_CMAKE" == "no" ] || [ -f "cmake-3.9.0/.done" ] || {
      cd cmake-3.9.0
      ./configure
      make
      su -c "make install"
      touch .done
      cd ..
    }

### LLVM/Clang 4.0.1 (optional)
Make sure to install at least GCC 4.8.

    # change version to your liking
    [ "$LLVM_VERSION" == "" ] && LLVM_VERSION=4.0.1
    # change prefix to you liking, this is where the new gcc is going to be installed
    [ "$LLVM_PREFIX" == "" ] && LLVM_PREFIX=/opt/llvm-$LLVM_VERSION

    # delete installation folder of previous build to rebuild
    [ "$BUILD_LLVM" == "no" ] || [ -d "$LLVM_PREFIX" ] || {
      [ "$BUILD_GCC" == "no" ] && {
        echo building LLVM requires a recent gcc
        exit 1
      }
      [ "$BUILD_CMAKE" == "no" ] && {
        echo building LLVM requires a recent CMake
        exit 1
      }
      [ -f "llvm-$LLVM_VERSION.src.tar.xz" ] || {
        wget http://releases.llvm.org/$LLVM_VERSION/llvm-$LLVM_VERSION.src.tar.xz
        tar xf llvm-$LLVM_VERSION.src.tar.xz
      }
      [ -f "llvm-$LLVM_VERSION.src/tools/cfe-$LLVM_VERSION.src.tar.xz"] || {
        cd llvm-$LLVM_VERSION.src/tools
        wget http://releases.llvm.org/$LLVM_VERSION/cfe-$LLVM_VERSION.src.tar.xz
        tar xf cfe-$LLVM_VERSION.src.tar.xz
        mv cfe-$LLVM_VERSION.src clang
        cd ../../
      }

      [ -d "build-llvm" ] || mkdir build-llvm
      cd build-llvm

      rm -rf ./* && \
        cmake -G "Unix Makefiles" \
            -DCMAKE_INSTALL_PREFIX:PATH="$LLVM_PREFIX" \
            -DCMAKE_C_COMPILER="$GCC_PREFIX/bin/gcc" \
            -DCMAKE_CXX_COMPILER="$GCC_PREFIX/bin/g++"" \
            -DGCC_INSTALL_PREFIX:PATH="$GCC_PREFIX" \
            -DCMAKE_CXX_LINK_FLAGS="-L$GCC_PREFIX/lib -Wl,-rpath,$GCC_PREFIX/lib -L$GCC_PREFIX/lib32 -Wl,-rpath,$GCC_PREFIX/lib32 -L$GCC_PREFIX/lib64 -Wl,-rpath,$GCC_PREFIX/lib64" \
            -DCMAKE_BUILD_TYPE:STRING="RelWithDebInfo" \
            -DLLVM_TARGETS_TO_BUILD:STRING="X86" \
            -DLLVM_INCLUDE_EXAMPLES:BOOL=OFF \
            -DLLVM_INCLUDE_TESTS:BOOL=OFF \
            -DLLVM_USE_LINKER:STRING=gold \
        ../llvm-$LLVM_VERSION.src

      make
      su -c "make install"
      cd ..
    }

### git 2.9.4 (optional)
Wheezy comes with a pretty old git version, follow these steps to build a more recent one.

    # delete .done file to rebuild
    [ "$BUILD_GIT" == "no" ] || [ -f "git-2.9.4/.done" ] || {
      [ -f "git-2.9.4.tar.xz" ] || {
        wget https://www.kernel.org/pub/software/scm/git/git-2.9.4.tar.xz
        tar xf git-2.9.4.tar.xz
      }
      cd git-2.9.4
      ./configure
      make
      su -c "make install"
      touch .done
      cd ..
    }

### Qt 5.6.0
In the following steps we will build 32-/64-bit dynamic/static Qt libraries and tools for Linux and setup a cross build environment for Windows and Mac. The static libraries are used to build the application installers using the [Qt Installer Framework](https://wiki.qt.io/Qt-Installer-Framework). Keep in mind that whatever you ship with statically linked Qt libraries you have to provide the user means to exchange them, this means either provide the source code or object files, or buy a commercial Qt license.

    # get the qt source
    git submodule update --init --recursive

#### Linux 64-bit

    # change prefix to you liking, this is where Qt is going to be installed
    [ "$QT_LINUX_64_PREFIX" == "" ] && QT_LINUX_64_PREFIX=/opt/qt-5.6.0-linux-x86_64

    # delete installation folder of previous build to rebuild
    [ -d "$QT_LINUX_64_PREFIX" ] || {
      [ -d "build-qt" ] || mkdir build-qt
      cd build-qt

      # please add/remove flags to accomodate your requirements
      rm -rf ./* && ../qt-5.6.0/configure \
          --prefix="$QT_LINUX_64_PREFIX" \
          -release -force-debug-info -separate-debug-info -pch -strip -no-ltcg -use-gold-linker \
          -opensource -confirm-license \
          -system-proxies -system-freetype -system-xcb -dbus-linked -gtkstyle -xkb-config-root /usr/share/X11/xkb \
          -nomake examples -nomake tests \
          -accessibility -cups -gui -widgets -iconv -icu -libinput -qml-debug -openssl -xcb-xlib -xrender -xcursor -xfixes -xinput  -xshape -xsync -xrandr -libproxy -fontconfig \
          -qpa xcb -eglfs -opengl desktop \
          -qt-zlib -qt-libpng -qt-libjpeg -qt-harfbuzz -qt-pcre -qt-xkbcommon -qt-xkbcommon-x11 \
          -no-mtdev -no-journald -no-syslog -no-pulseaudio -no-alsa -no-evdev -no-tslib -no-kms -no-gbm -no-linuxfb -no-directfb -no-mirclient -no-gstreamer -no-sql-sqlite -no-xinput2 -no-xvideo -no-xkb -no-xkbcommon-evdev -no-xinerama \
          -skip qt3d -skip qtcanvas3d -skip qtenginio -skip qtserialport -skip qtserialbus -skip qtwebchannel -skip qtwebengine -skip qtwebsockets -skip qtwebview -skip qtdoc -skip qtconnectivity -skip qtlocation -skip qtmultimedia -skip qttranslations

      make
      su -c "make install"
      cd ..
    }


#### Linux 64-bit static
The static version of Qt is used to build the installer. If you modified flags in the previous step just add the -static flag to your configuration options. Also you might want to disable OpenGL, EGL and whatever you think you might not need for the installer application.

    # change prefix to you liking, this is where Qt is going to be installed
    [ "$QT_LINUX_64_STATIC_PREFIX" == "" ] && QT_LINUX_64_STATIC_PREFIX=/opt/qt-5.6.0-linux-x86_64-static

    # delete installation folder of previous build to rebuild
    [ -d "$QT_LINUX_64_STATIC_PREFIX" ] || {
      [ -d "build-qt" ] || mkdir build-qt
      cd build-qt

      # please add/remove flags to accomodate your requirements
      rm -rf ./* && ../qt-5.6.0/configure \
          -static --prefix=$QT_LINUX_64_STATIC_PREFIX \
          -release -force-debug-info -separate-debug-info -pch -strip -no-ltcg -use-gold-linker \
          -opensource -confirm-license \
          -system-proxies -system-freetype -dbus-linked -gtkstyle -xkb-config-root /usr/share/X11/xkb \
          -nomake examples -nomake tests \
          -accessibility -gui -widgets -libinput -openssl -xcb-xlib -xrender -xcursor -xfixes -xinput -xsync -xrandr -libproxy -fontconfig \
          -qpa xcb \
          -qt-zlib -qt-libpng -qt-libjpeg -qt-harfbuzz -qt-pcre -qt-xkbcommon -qt-xkbcommon-x11 -qt-xcb \
          -no-cups -no-eglfs -no-opengl -no-mtdev -no-journald -no-syslog -no-pulseaudio -no-alsa -no-evdev -no-tslib -no-kms -no-gbm -no-linuxfb -no-directfb -no-mirclient -no-gstreamer -no-sql-sqlite -no-xinput2 -no-xvideo -no-xkb -no-xkbcommon-evdev -no-xinerama -no-qml-debug -no-xshape -no-iconv -no-icu \
          -skip qt3d -skip qtcanvas3d -skip qtenginio -skip qtserialport -skip qtserialbus -skip qtwebchannel -skip qtwebengine -skip qtwebsockets -skip qtwebview -skip qtdoc -skip qtconnectivity -skip qtlocation -skip qtmultimedia -skip qttranslations

      make
      su -c "make install"
      cd ..
    }
