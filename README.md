# build-env

## prerequisites
* system with rather old glibc and gcc multilib support
* git

### debian wheezy
Install the following packages:

    # libxcb-xkb-dev is found in wheezy-backports repository
    su -c "echo 'deb http://ftp.debian.org/debian wheezy-backports main' >> /etc/apt/sources.list"

    sudo apt-get update
    sudo apt-get install \
        tar bzip2 zip \
        build-essential make bison gettext texinfo gcc g++ gcc-multilib g++-multilib \
        gtk2.0-dev libglib2.0-dev \
        libcups2-dev \
        libdbus-1-dev \
        libproxy-dev \
        libicu-dev \
        libglu1-mesa-dev libegl1-mesa-dev \
        '^libxcb.*-dev' libx11-xcb-dev libxrender-dev libxi-dev libxcb-xkb-dev \
        libssl-dev \
        libfontconfig1-dev

#### libxkbcommon
Since this library is not present on debian wheezy we have to build it ourselves.

    wget --no-check-certificate http://xkbcommon.org/download/libxkbcommon-0.4.1.tar.xz
    tar xf libxkbcommon-0.4.1.tar.xz
    cd libxkbcommon-0.4.1
    ./configure
    make
    make install

### GCC 5.4.0 (optional)
If you want to build your application with recent C++ features a recent GCC is mandatory.

    # change version to your liking
    VERSION=5.4.0
    # change prefix to you liking, this is where the new gcc is going to be installed
    PREFIX=/opt/$VERSION

    wget --no-check-certificate https://ftp.gnu.org/gnu/gcc/gcc-$VERSION/gcc-$VERSION.tar.bz2
    tar xf gcc-$VERSION.tar.bz2
    cd gcc-$VERSION/contrib
    ./download_prerequisites
    cd ../../
    mkdir build-gcc
    cd build-gcc

    ../gcc-$VERSION/configure --prefix=$PREFIX --enable-languages=c,c++
    make
    sudo make install

    # configure ld to find our newly built libraries
    echo "$PREFIX/lib" > /etc/ld.so.conf.d/gcc-$VERSION.conf
    echo "$PREFIX/lib32" >> /etc/ld.so.conf.d/gcc-$VERSION.conf
    echo "$PREFIX/lib64" >> /etc/ld.so.conf.d/gcc-$VERSION.conf
    sudo ldconfig

    # Update PATH so our newly built gcc is used instead of the system provided one. You might want to make this sticky in your bash startup scripts (~/.bashrc and the like).
    export PATH=$PREFIX/bin:$PATH

### git 2.9.4 (optional)
Wheezy comes with a pretty old git version, follow these steps to build a more recent one.

    wget https://www.kernel.org/pub/software/scm/git/git-2.9.4.tar.xz
    cd git-2.9.4
    ./configure
    make
    make install

### Qt 5.6.0
In the following steps we will build 32-/64-bit dynamic/static Qt libraries and tools for Linux and setup a cross build environment for Windows and Mac.
    # get the qt source
    git submodule update --init --recursive

#### Linux 64-bit

    # change prefix to you liking, this is where Qt is going to be installed
    PREFIX=/opt/qt-5.6.0-linux-x86_64

    [ -d "build-qt" ] || mkdir build-qt
    cd build-qt

    # please add/remove flags to accomodate your requirements
    rm -rf ./* && ../qt-5.6.0/configure \
        --prefix=$PREFIX \
        -release -force-debug-info -separate-debug-info -pch -strip -no-ltcg -use-gold-linker \
        -opensource -confirm-license \
        -system-proxies -system-freetype -dbus-linked -gtkstyle -xkb-config-root /usr/share/X11/xkb \
        -nomake examples -nomake tests \
        -accessibility -cups -gui -widgets -iconv -icu -libinput -qml-debug -openssl -xcb-xlib -xrender -xcursor -xfixes -xinput  -xshape -xsync -xrandr -libproxy -fontconfig \
        -qpa xcb -eglfs -opengl desktop \
        -qt-zlib -qt-libpng -qt-libjpeg -qt-harfbuzz -qt-pcre -qt-xkbcommon -qt-xkbcommon-x11 -qt-xcb \
        -no-mtdev -no-journald -no-syslog -no-pulseaudio -no-alsa -no-evdev -no-tslib -no-kms -no-gbm -no-linuxfb -no-directfb -no-mirclient -no-gstreamer -no-sql-sqlite -no-xinput2 -no-xvideo -no-xkb -no-xkbcommon-evdev -no-xinerama \
        -skip qt3d -skip qtcanvas3d -skip qtenginio -skip qtserialport -skip qtserialbus -skip qtwebchannel -skip qtwebengine -skip qtwebsockets -skip qtwebview -skip qtdoc -skip qtconnectivity -skip qtlocation -skip qtmultimedia -skip qttranslations

    make
    make install
    cd ..

#### Linux 64-bit static
The static version of Qt is used to build the installer. If you modified flags in the previous step just be sure to choose another PREFIX for the static version and just add the -static flag to configure.

    # change prefix to you liking, this is where Qt is going to be installed
    PREFIX=/opt/qt-5.6.0-linux-x86_64-static

    [ -d "build-qt" ] || mkdir build-qt
    cd build-qt

    # please add/remove flags to accomodate your requirements
    rm -rf ./* && ../qt-5.6.0/configure \
        -static --prefix=$PREFIX \
        -release -force-debug-info -separate-debug-info -pch -strip -no-ltcg -use-gold-linker \
        -opensource -confirm-license \
        -system-proxies -system-freetype -dbus-linked -gtkstyle -xkb-config-root /usr/share/X11/xkb \
        -nomake examples -nomake tests \
        -accessibility -cups -gui -widgets -iconv -icu -libinput -qml-debug -openssl -xcb-xlib -xrender -xcursor -xfixes -xinput  -xshape -xsync -xrandr -libproxy -fontconfig \
        -qpa xcb -eglfs -opengl desktop \
        -qt-zlib -qt-libpng -qt-libjpeg -qt-harfbuzz -qt-pcre -qt-xkbcommon -qt-xkbcommon-x11 -qt-xcb \
        -no-mtdev -no-journald -no-syslog -no-pulseaudio -no-alsa -no-evdev -no-tslib -no-kms -no-gbm -no-linuxfb -no-directfb -no-mirclient -no-gstreamer -no-sql-sqlite -no-xinput2 -no-xvideo -no-xkb -no-xkbcommon-evdev -no-xinerama \
        -skip qt3d -skip qtcanvas3d -skip qtenginio -skip qtserialport -skip qtserialbus -skip qtwebchannel -skip qtwebengine -skip qtwebsockets -skip qtwebview -skip qtdoc -skip qtconnectivity -skip qtlocation -skip qtmultimedia -skip qttranslations

    make
    make install
    cd ..
