FROM debian:sid

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential debhelper devscripts git curl pkg-config gettext \
    libgtk-4-dev libadwaita-1-dev libgtk4-layer-shell-dev \
    libfontconfig-dev libharfbuzz-dev libpixman-1-dev \
    libx11-dev libwayland-dev libxkbcommon-dev \
    libgl-dev libegl-dev blueprint-compiler libxml2-utils \
    pandoc \
    && rm -rf /var/lib/apt/lists/*

RUN ZIG_VER="0.15.2" && \
    URL="https://ziglang.org/download/${ZIG_VER}/zig-x86_64-linux-${ZIG_VER}.tar.xz" && \
    curl -L ${URL} -o zig.tar.xz && \
    tar -xf zig.tar.xz && \
    mv zig-x86_64-linux-${ZIG_VER}/zig /usr/local/bin/ && \
    mv zig-x86_64-linux-${ZIG_VER}/lib /usr/local/lib/zig && \
    rm -rf zig-x86_64-linux-${ZIG_VER} zig.tar.xz

RUN useradd -m -s /bin/bash builder
WORKDIR /build
RUN chown builder:builder /build

USER builder
