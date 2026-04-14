# Audiobookshelf with fdk-aac support for xHE-AAC/USAC audio
# Based on https://gist.github.com/dymk/7a6c9e4237335dcb73a0833522668bbf

ARG AUDIOBOOKSHELF_TAG=latest

FROM ubuntu:22.04 AS builder

# Install essential tools and dependencies
RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt/lists \
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates wget sed git && \
    sed -i 's/main$/main universe multiverse/' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    build-essential \
    libbz2-dev \
    libmp3lame-dev \
    libtool \
    pkg-config \
    tar \
    yasm \
    nasm \
    libwebp-dev \
    zlib1g-dev

# Build fdk-aac from source
RUN git clone --depth 1 https://github.com/mstorsjo/fdk-aac /usr/src/fdk-aac && \
    cd /usr/src/fdk-aac && \
    autoreconf -fiv && \
    ./configure --prefix=/usr/local/ffmpeg_build --disable-shared && \
    make -j$(nproc) && \
    make install && \
    cd / && \
    rm -rf /usr/src/fdk-aac

# Download and build ffmpeg
ARG FFMPEG_VERSION=7.1.1
RUN wget https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.bz2 && \
    tar xjvf ffmpeg-${FFMPEG_VERSION}.tar.bz2 && \
    rm ffmpeg-${FFMPEG_VERSION}.tar.bz2 && \
    cd ffmpeg-${FFMPEG_VERSION} && \
    export PKG_CONFIG_PATH="/usr/local/ffmpeg_build/lib/pkgconfig:${PKG_CONFIG_PATH:-}" && \
    ./configure \
        --prefix=/usr/local/ffmpeg_build \
        --pkg-config-flags="--static" \
        --extra-cflags="-I/usr/local/ffmpeg_build/include" \
        --extra-ldflags="-L/usr/local/ffmpeg_build/lib" \
        --disable-shared \
        --enable-static \
        --disable-debug \
        --disable-doc \
        --enable-bzlib \
        --enable-libmp3lame \
        --enable-nonfree \
        --enable-libfdk_aac \
        --enable-decoder=libfdk_aac \
        --enable-encoder=libfdk_aac \
        --disable-encoder=aac \
        --disable-encoder=aac_mf \
        --disable-decoder=aac \
        --disable-decoder=aac_fixed \
        --disable-decoder=aac_latm \
        --enable-zlib \
        --enable-libwebp \
        --extra-ldflags="-static -L/usr/local/ffmpeg_build/lib" && \
    make -j$(nproc) && \
    cp ffmpeg /ffmpeg && \
    cp ffprobe /ffprobe && \
    cd / && \
    rm -rf ffmpeg-${FFMPEG_VERSION} /usr/local/ffmpeg_build

# Use the build argument to specify the base image tag
FROM ghcr.io/advplyr/audiobookshelf:${AUDIOBOOKSHELF_TAG}

# Copy the custom-built ffmpeg and ffprobe to a location not on the PATH
COPY --from=builder /ffmpeg /usr/local/bin/ffmpeg.real
COPY --from=builder /ffprobe /usr/local/bin/ffprobe.real

# Create ffmpeg wrapper that remaps -c:a aac -> -c:a libfdk_aac for better transcoding
RUN echo '#!/usr/bin/perl\n\
use strict;\n\
use warnings;\n\
my @newargs;\n\
my $i = 0;\n\
while ($i < @ARGV) {\n\
    if ($ARGV[$i] eq '"'"'-c:a'"'"' && $i + 1 < @ARGV && $ARGV[$i+1] eq '"'"'aac'"'"') {\n\
        push @newargs, '"'"'-c:a'"'"', '"'"'libfdk_aac'"'"';\n\
        $i += 2;\n\
    } else {\n\
        push @newargs, $ARGV[$i];\n\
        $i++;\n\
    }\n\
}\n\
exec "/usr/local/bin/ffmpeg.real", @newargs;' > /usr/bin/ffmpeg && chmod +x /usr/bin/ffmpeg

# ffprobe wrapper (pass-through, no remapping needed)
RUN echo '#!/bin/sh\nexec /usr/local/bin/ffprobe.real "$@"' > /usr/bin/ffprobe && chmod +x /usr/bin/ffprobe
