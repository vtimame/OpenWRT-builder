FROM debian:trixie AS build-system

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      bc binutils-gold bison build-essential ccache \
      ecj fastjar file flex g++ \
      gawk gcc-arm* gettext git help2man \
      libbsd-dev libelf-dev liblzma-dev libncurses-dev libssl-dev \
      meson mold mtd-utils ninja-build pbzip2 \
      pigz pkg-config python3-dev python3-setuptools rsync \
      subversion swig texinfo time u-boot-tools \
      unzip wget xsltproc xxd zlib1g-dev \
      zstd && \
    rm -rf /var/lib/apt/lists/*

ARG UID=1000
ARG GID=1000

RUN groupadd -g ${GID} builder && \
    useradd -m -u ${UID} -g ${GID} builder && \
    mkdir -p /home/builder/openwrt/dl \
             /home/builder/openwrt/logs \
             /home/builder/openwrt/feeds \
             /home/builder/openwrt/build_dir \
             /home/builder/openwrt/staging_dir \
             /home/builder/output \
             /home/builder/.ccache && \
    chown -R builder:builder /home/builder

USER builder
WORKDIR /home/builder