# goal
This project aims at providing a deployment environment for Qt Applications on Linux.

## prerequisites
* system with rather old glibc version

## outcome
* GCC 6.4.0 for Linux 32-/64-bit compilation (optional)
* Clang 4.0.1 for Linux 32-/64-bit compilation (optional)
* Clang * for Mac 64-bit cross compilation (optional)
* MinGW * for Windows 32-/64-bit cross compilation
* Qt 5.6.0 for Linux, Mac (optional) and Windows
* Qt Installer Framework for Linux, Mac (optional) and Windows

## tl;dr
If you just want to jump start you may want to execute the auto.sh script. Ignore the comments, they are just a hint for the parsing going on in the script. It will execute any commands from this readme lacking this tag.

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

## foreword
Deployment on Linux can get rather tricky if you don't provide the source code for your application. The ultimate candidates deciding whether your application will start or fail are the kernel and glibc of the target host. As glibc seems to be configured to take kernel versions back to 2.6.* into account mostly (to be verified) the only real enemy left seems to be glibc. One could start reading the LFS books on how to compile your own Linux system for which you can to some or great extent control the versions of your libraries, but as this seems rather overkill just using an older linux distribution as the base should be the preferred option. We chose to use debian wheezy as the build host as its glibc version 2.13 should be old enough to run on most targets. We will install recent compilers so that you can use recent c++ features. We will ship the libraries used by the application as fallback and load them when the target does not have a compatible version of a library or the library itself installed. This way we don't tie the user toughly to our shipped old versions of libraries while still having good chances that our application will start up.

If used, the installer application itself should have as little dependencies as possible. We do not want to ship the dependencies inside the installer package and in the installed application folder. We could theoretically add an installation step to copy over the libraries to the destination folder but this seems rather messy. We are going to build a stripped Qt version which we can statically link into our installer. Note that you have to comply to Qt's licensing terms as in you have to make sure that the user has the ability to exchange the Qt libraries used. Therefore you must provide the source code of your installer application and any modifications you applied to it. This does not apply if you have a commercial license for Qt.

Before using the Mac OSX SDK make sure to be familiar with Apple's EULA. It is pretty clear on where it is allowed to be used, so in case you are approaching this step be sure that you are following this guide inside of a virtual machine on a computer branded by Apple.

### debian wheezy
Install the following packages:

    su -c "
      # libxcb-xkb-dev is found in wheezy-backports repository
      echo 'deb http://ftp.debian.org/debian wheezy-backports main' >> /etc/apt/sources.list
      apt-get update

      # we don't want to provide user input
      export DEBIAN_FRONTEND=noninteractive

      # install packages needed to build Qt
      apt-get install -y -t wheezy-backports \
        tar bzip2 zip debootstrap vim \
        build-essential make bison gettext texinfo gcc g++ clang clang++ \
        gtk2.0-dev libglib2.0-dev \
        libcups2-dev \
        libdbus-1-dev \
        libproxy-dev \
        libicu-dev \
        libglu1-mesa-dev libegl1-mesa-dev \
        $(apt-cache --names-only search ^libxcb.*-dev | awk '{ print $1 }' | grep -v libxcb-sync0-dev) libx11-xcb-dev libxrender-dev libxi-dev libxcb-xkb-dev \
        libssl-dev \
        libfontconfig1-dev
    "

#### 32-bit Linux environment
We will not make use of debians multiarch feature because it is possible that the 64- and 32-bit versions conflict. Instead we just create separate environment we can chroot into and let ld find libraries from there as well.

    # change path to you liking, this is where the 32-bit debian system is going to be installed
    [ "$CHROOT" == "" ] && CHROOT=/chroot-32

    su -c "
      # delete chroot folder to rebuild
      [ -d \"$CHROOT\" ] || {

        # install base system
        mkdir $CHROOT
        debootstrap --arch i386 wheezy \"$CHROOT\" http://httpredir.debian.org/debian/

        # mount necessary folder to chroot
        mount --bind /dev \"$CHROOT/dev\"
        mount --bind /dev/pts \"$CHROOT/dev/pts\"

        # save current directory for changing back when coming from chroot
        CURDIR=`pwd`

        chroot \"$CHROOT\" bash -c \"
            # mount proc and sys
            mount -t proc proc /proc
            mount -t sysfs sys /sys

            # libxcb-xkb-dev is found in wheezy-backports repository
            echo 'deb http://ftp.debian.org/debian wheezy-backports main' >> /etc/apt/sources.list
            apt-get update

            # we don't want to provide user input
            export DEBIAN_FRONTEND=noninteractive

            # install packages needed to build Qt
            apt-get install -y -t wheezy-backports \
              vim build-essential make bison gettext texinfo gcc g++ clang clang++ \
              gtk2.0-dev libglib2.0-dev \
              libcups2-dev \
              libdbus-1-dev \
              libproxy-dev \
              libicu-dev \
              libglu1-mesa-dev libegl1-mesa-dev \
              `echo $(apt-cache --names-only search ^libxcb.*-dev | awk '{ print $1 }' | grep -v libxcb-sync0-dev)` libx11-xcb-dev libxrender-dev libxi-dev libxcb-xkb-dev \
              libssl-dev \
              libfontconfig1-dev

            # convert all symbolic links of libraries to hard links, else we would not
            # be able to access the files from outside the chroot
            find /lib -type l -name \"lib*.so*\" -exec bash -c 'ln -f \"$(readlink -m \"$0\")\" \"$0\"' {} \;
            find /usr/lib -type l -name \"lib*.so*\" -exec bash -c 'ln -f \"$(readlink -m \"$0\")\" \"$0\"' {} \;

            exit
        \"

        cd $CURDIR

        # add needed library paths to ld config of our host
        echo \"$CHROOT/usr/lib/i386-linux-gnu\" > /etc/ld.so.conf.d/chroot-32.conf
        echo \"$CHROOT/lib/i386-linux-gnu\" >> /etc/ld.so.conf.d/chroot-32.conf
        echo \"$CHROOT/usr/lib\" >> /etc/ld.so.conf.d/chroot-32.conf
        echo \"$CHROOT/lib\" >> /etc/ld.so.conf.d/chroot-32.conf
        echo \"$CHROOT/usr/lib/gcc/i486-linux-gnu/4.7\" >> /etc/ld.so.conf.d/chroot-32.conf
        ldconfig

        # add the 32-bit loader to host
        ln -sf \"$CHROOT/lib/ld-linux.so.2\" /lib/
      }
    "

#### general setup
Set the flags to your liking, the default is to build with twice as many threads as logical CPU cores.

    export MAKEFLAGS="-j$((`cat /proc/cpuinfo | grep processor | wc -l `*2))"

#### libxkbcommon
Since this library is not present on debian wheezy we have to build it ourselves.

    [ -f "libxkbcommon-0.4.1.tar.xz" ] || {
      wget --no-check-certificate https://xkbcommon.org/download/libxkbcommon-0.4.1.tar.xz
      tar xf libxkbcommon-0.4.1.tar.xz
    }

    # delete .done file to rebuild
    [ -f "libxkbcommon-0.4.1/.done" ] || {
      cd libxkbcommon-0.4.1
      ./configure
      make
      su -c "make install"
      make distclean
      # now build 32-bit version
      CFLAGS="-I$CHROOT/usr/include -I$CHROOT/usr/include/i386-linux-gnu" CXXFLAGS=$CFLAGS CC="$CHROOT/usr/bin/gcc" ./configure --prefix="$CHROOT/usr/local" --host=i386-pc-linux-gnu
      make
      su -c "make install"
      touch .done
      cd ..
    }

### GCC 6.4.0 (optional)
If you want to build your application with recent C++ features a recent GCC is mandatory.

    # change version to your liking
    [ "$GCC_VERSION" == "" ] && GCC_VERSION=6.4.0
    # change prefix to you liking, this is where the new gcc is going to be installed
    [ "$GCC_PREFIX" == "" ] && GCC_PREFIX=/opt/gcc-$GCC_VERSION

    # delete installation folder of previous build to rebuild
    [ "$BUILD_GCC" == "no" ] || [ -d "$GCC_PREFIX" ] || {
      # get gcc
      [ -f "gcc-$GCC_VERSION.tar.gz" ] || {
        wget --no-check-certificate https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.gz
        tar xf gcc-$GCC_VERSION.tar.gz
        cd gcc-$GCC_VERSION/contrib
        ./download_prerequisites
        cd ..
      }

      # more recent automake version is needed
      [ -f "automake-1.14.tar.gz" ] || {
        apt-get -y install autoconf
        wget https://ftp.gnu.org/gnu/automake/automake-1.14.tar.gz
        tar xf automake-1.14.tar.gz
        cd automake-1.14
        ./configure
        make
        su -c "make install"
      }

      mkdir build-gcc
      cd build-gcc

      rm -rf ./* && ../gcc-$GCC_VERSION/configure \
        --prefix="$GCC_PREFIX" \
        --build=x86_64-pc-linux-gnu --target=x86_64-pc-linux-gnu \
        --enable-languages=c,c++ \
        --disable-multilib
      make
      su -c "
        make install
        ln -sf "$GCC_PREFIX/bin/gcc" "$GCC_PREFIX/bin/cc"
      "
      cd ..

      # Update PATH so our newly built gcc is used instead of the system provided one.
      su -c "
        echo \"export PATH=$GCC_PREFIX/bin:$ _PATH_\" >> /etc/bash.bashrc
        sed -i "s/\s_PATH_/PATH/g" /etc/bash.bashrc
        . /etc/bash.bashrc
      "

      # configure ld to find our newly built libraries (libstdc++ and gcc support libraries)
      su -c "
          echo $GCC_PREFIX/lib64 >> /etc/ld.so.conf.d/gcc-$GCC_VERSION.conf
          ldconfig
      "

      su -c "
        [ -d \"$CHROOT/tools\" ] || mkdir \"$CHROOT/tools\"
        mount --bind . \"$CHROOT/tools\"

        # save current directory for changing back when coming from chroot
        CURDIR=`pwd`

        chroot \"$CHROOT\" bash -c \"
          cd /tools
          cd automake-1.14
          make distclean
          ./configure
          make
          make install
          cd ..
          cd build-gcc
          # we will bind our root to $CHROOT so that the paths are correct
          # when we exit to our host from the chroot
          mkdir \"$CHROOT\"
          mount --bind / \"$CHROOT\"
          rm -rf ./* && \
            AR=ar AS=as LD=ld ../gcc-$GCC_VERSION/configure \
                --prefix=\""$GCC_PREFIX\" \
                --with-sysroot=\"$CHROOT\" \
                --with-local-prefix=\"$CHROOT/usr/local\" \
                --with-as="$CHROOT/usr/bin/as" \
                --with-ld="$CHROOT/usr/bin/ld" \
                --build=i386-linux-gnu --target=i386-pc-linux-gnu \
                --enable-languages=c,c++ \
                --disable-multilib
          make
          su -c "
              make install
              ln -sf "$GCC_PREFIX/bin/gcc" "$GCC_PREFIX/bin/cc"
            "
            cd ..

            # Update PATH so our newly built gcc is used instead of the system provided one.
            su -c "
              echo \"export PATH=$GCC_PREFIX/bin:$ _PATH_\" >> /etc/bash.bashrc
              sed -i "s/\s_PATH_/PATH/g" /etc/bash.bashrc
              . /etc/bash.bashrc
            "

            # configure ld to find our newly built libraries (libstdc++ and gcc support libraries)
            su -c "
                echo $GCC_PREFIX/lib32 >> /etc/ld.so.conf.d/gcc-$GCC_VERSION.conf
                ldconfig
            "

          exit
        \"

        cd \"$CURDIR\"
      "

    }

### CMake 3.9.0 (optional)
Follow these steps if you want to build LLVM/Clang or just need a more recent CMake.

    [ "$BUILD_GCC" == "no" ] && {
      echo building CMake requires a recent gcc
      exit 1
    }

    [ -f "cmake-3.9.0.tar.gz" ] || {
      wget https://cmake.org/files/v3.9/cmake-3.9.0.tar.gz
      tar xf cmake-3.9.0.tar.gz
    }

    # delete .done file to rebuild
    [ "$BUILD_CMAKE" == "no" ] || [ -f "cmake-3.9.0/.done" ] || {
      [ -d "build-cmake" ] || mkdir build-cmake
      cd build-cmake
      rm -rf ./* && ../cmake-3.9.0/configure
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
            -DCMAKE_CXX_COMPILER="$GCC_PREFIX/bin/g++" \
            -DGCC_INSTALL_PREFIX:PATH="$GCC_PREFIX" \
            -DCMAKE_CXX_LINK_FLAGS="-L$GCC_PREFIX/lib -Wl,-rpath,$GCC_PREFIX/lib -L$GCC_PREFIX/lib32 -Wl,-rpath,$GCC_PREFIX/lib32 -L$GCC_PREFIX/lib64 -Wl,-rpath,$GCC_PREFIX/lib64" \
            -DCMAKE_BUILD_TYPE:STRING="Release" \
            -DLLVM_TARGETS_TO_BUILD:STRING="X86" \
            -DLLVM_INCLUDE_EXAMPLES:BOOL=OFF \
            -DLLVM_INCLUDE_TESTS:BOOL=OFF \
        ../llvm-$LLVM_VERSION.src

      make
      
      su -c "
        make install
        # Update PATH so our newly built llvm is used instead of the system provided one.
        echo \"export PATH=$LLVM_PREFIX/bin:$ _PATH_\" >> /etc/bash.bashrc
        sed -i \"s/\s_PATH_/PATH/g\" /etc/bash.bashrc
        . /etc/bash.bashrc
      "

      cd ..
    }

### git 2.9.4 (optional)
Wheezy comes with a pretty old git version, follow these steps to build a more recent one.

    # delete .done file to rebuild
    [ "$BUILD_GIT" == "no" ] || [ -f "git-2.9.4/.done" ] || {

      apt-get install -y -t wheezy-backports libcurl4-openssl-dev libldap2-dev

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
          -platform linux-clang \
          --prefix="$QT_LINUX_64_PREFIX" \
          -release -force-debug-info -separate-debug-info -pch -strip -no-ltcg -use-gold-linker \
          -opensource -confirm-license \
          -system-proxies -system-freetype -system-xcb -dbus-linked -glib -gtkstyle -xkb-config-root /usr/share/X11/xkb \
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
          --platform linux-clang \
          -static \
          --prefix=$QT_LINUX_64_STATIC_PREFIX \
          -release -force-debug-info -separate-debug-info -pch -strip -no-ltcg -use-gold-linker \
          -opensource -confirm-license \
          -system-proxies -system-freetype -dbus-linked -glib -gtkstyle -xkb-config-root /usr/share/X11/xkb \
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

#### Linux 32-bit

    # change prefix to you liking, this is where Qt is going to be installed
    [ "$QT_LINUX_32_PREFIX" == "" ] && QT_LINUX_32_PREFIX=/opt/qt-5.6.0-linux-x86

    # delete installation folder of previous build to rebuild
    [ -d "$QT_LINUX_32_PREFIX" ] || {
      [ -d "build-qt" ] || mkdir build-qt
      cd build-qt

      # please add/remove flags to accomodate your requirements
      rm -rf ./* && \
        LD_LIBRARY_PATH="$CHROOT/usr/lib/i386-linux-gnu:$CHROOT/usr/lib:$CHROOT/lib:$CHROOT/lib/i386-linux-gnu" ../qt-5.6.0/configure \
          -platform linux-clang \
          -xplatform linux-clang-32 \
          --prefix="$QT_LINUX_32_PREFIX" \
          -no-pkg-config \
          -L"$CHROOT/lib" -L"$CHROOT/lib/i386-linux-gnu" -L"$CHROOT/usr/lib" -L"$CHROOT/usr/lib/i386-linux-gnu" \
          -I"$CHROOT/usr/include/dbus-1.0" -I"$CHROOT/usr/lib/i386-linux-gnu/dbus-1.0/include" -I"$CHROOT/usr/include/glib-2.0" -I"$CHROOT/usr/include/gtk-2.0" -I"$CHROOT/usr/lib/i386-linux-gnu/gtk-2.0/include" -I"$CHROOT/usr/include/atk-1.0" -I"$CHROOT/usr/include/cairo" -I"$CHROOT/usr/include/gdk-pixbuf-2.0" -I"$CHROOT/usr/include/pango-1.0" -I"$CHROOT/usr/include/gio-unix-2.0" -I"$CHROOT/usr/include/glib-2.0" -I"$CHROOT/usr/lib/i386-linux-gnu/glib-2.0/include" -I"$CHROOT/usr/include/pixman-1" -I"$CHROOT/usr/include/freetype2" -I"$CHROOT/usr/include/libpng12" \
          -release -force-debug-info -separate-debug-info -pch -strip -no-ltcg -no-use-gold-linker -c++11\
          -opensource -confirm-license \
          -system-proxies -system-freetype -system-xcb -dbus-linked -glib -gtkstyle -xkb-config-root /usr/share/X11/xkb \
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








#### binutils 2.28
We have to build a custom binutils which will have the ability to search for libraries in both the host and the 32-bit chroot environment.

    [ -f "binutils-2.28.tar.bz2" ] || {
        wget https://ftp.gnu.org/gnu/binutils/binutils-2.28.tar.bz2
        tar xf binutils-2.28.tar.bz2
    }

    # delete .done file to rebuild
    [ -f "binutils-2.28/.done" ] || {
      cd binutils-2.28
      ./configure --prefix=/usr/local --target=x86_64-linux-gnu --enable-targets=x86_64-linux-gnu,i386-linux-gnu --enable-gold --enable-threads --enable-64-bit-bfd --program-prefix=

      # add our new libstdc++ 64-bit to search path in case gcc was built
      [ -d "$GCC_PREFIX" ] && _LIB_PATH="$GCC_PREFIX/lib64"
      # add our host's 64-bit lib paths
      _LIB_PATH="$_LIB_PATH:/usr/lib/x86_64-linux-gnu:/usr/lib:/lib/x86_64-linux-gnu:/lib"
      # add the chroot's 32-bit lib paths
      _LIB_PATH="$_LIB_PATH:$CHROOT/usr/lib/i386-linux-gnu:$CHROOT/usr/lib:$CHROOT/lib/i386-linux-gnu:$CHROOT/lib"

      make LIB_PATH="$_LIB_PATH"

      su -c "make install"
      touch .done
      cd ..
    }


#### binutils 2.28
We have to build a custom binutils which will have the ability to search for libraries in both the host and the 32-bit chroot environment.

    [ -f "binutils-2.28.tar.bz2" ] || {
        wget https://ftp.gnu.org/gnu/binutils/binutils-2.28.tar.bz2
        tar xf binutils-2.28.tar.bz2
    }

    # delete .done file to rebuild
    [ -f "binutils-2.28/.done" ] || {
      cd binutils-2.28
      ./configure --prefix=/usr/local --target=x86_64-linux-gnu --enable-targets=x86_64-linux-gnu,i386-linux-gnu --enable-gold --program-prefix=

      # add our new libstdc++ 64-bit to search path in case gcc was built
      [ -d "$GCC_PREFIX" ] && _LIB_PATH="$GCC_PREFIX/lib64"
      # add our host's 64-bit lib paths
      _LIB_PATH="$_LIB_PATH:/usr/lib/x86_64-linux-gnu:/usr/lib:/lib/x86_64-linux-gnu:/lib"
      # add our new libstdc++ 32-bit to search path in case gcc was built
      [ -d "$GCC_PREFIX" ] && _LIB_PATH="$_LIB_PATH:$GCC_PREFIX/lib32"
      # add our host's 32-bit lib paths
      _LIB_PATH="$_LIB_PATH:/usr/lib/i386-linux-gnu:/usr/lib32:/lib32"
      # and finally add the chroot's 32-bit lib paths
      _LIB_PATH="$_LIB_PATH:$CHROOT/usr/lib/i386-linux-gnu:$CHROOT/usr/lib:$CHROOT/lib/i386-linux-gnu:$CHROOT/lib"

      make LIB_PATH="$_LIB_PATH"

      su -c "make install"
      touch .done
      cd ..
    }
