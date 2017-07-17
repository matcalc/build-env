# build-env
## prerequisites
* system with rather old glibc and gcc multilib support
### debian wheezy
    su -c "echo 'deb http://ftp.debian.org/debian wheezy-backports main' >> /etc/apt/sources.list"
    sudo apt-get update
    sudo apt-get install tar bzip2 build-essential make gcc g++ gcc-multilib g++-multilib bison libcups2-dev libdbus-1-dev libproxy-dev libicu-dev libglu1-mesa-dev '^libxcb.*-dev' libx11-xcb-dev libxrender-dev libxi-dev libxcb-xkb-dev libssl-dev libfontconfig1-dev
