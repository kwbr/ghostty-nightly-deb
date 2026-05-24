ARG DEBIAN_DIST=sid
FROM debian:${DEBIAN_DIST}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential debhelper devscripts git curl pkg-config gettext \
    libgtk-4-dev libadwaita-1-dev libgtk4-layer-shell-dev \
    libfontconfig-dev libharfbuzz-dev libpixman-1-dev \
    libx11-dev libwayland-dev libxkbcommon-dev \
    libgl-dev libegl-dev blueprint-compiler libxml2-utils \
    pandoc gnupg lsb-release \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sS https://debian.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc \
    | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/debian.griffo.io.gpg \
    && echo "deb https://debian.griffo.io/apt $(lsb_release -sc) main" \
    | tee /etc/apt/sources.list.d/debian.griffo.io.list \
    && apt-get update \
    && apt-get install -y zig-oldstable

RUN useradd -m -s /bin/bash builder
WORKDIR /build
RUN chown builder:builder /build

USER builder
