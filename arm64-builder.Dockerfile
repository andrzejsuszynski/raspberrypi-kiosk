# Builder image with the arm64 Native AOT cross-compilation toolchain baked in.
# Rebuild only when the .NET SDK version or toolchain needs bumping:
#   docker build --platform linux/amd64 -t kiosk-arm64-builder -f arm64-builder.Dockerfile .
FROM --platform=linux/amd64 mcr.microsoft.com/dotnet/sdk:10.0

# The default Ubuntu mirror (archive.ubuntu.com) only carries amd64 packages;
# arm64 packages live on ports.ubuntu.com, so route that architecture there.
RUN sed -i '/^URIs: http:\/\/archive.ubuntu.com/i Architectures: amd64' /etc/apt/sources.list.d/ubuntu.sources && \
    sed -i '/^URIs: http:\/\/security.ubuntu.com/i Architectures: amd64' /etc/apt/sources.list.d/ubuntu.sources && \
    printf 'Types: deb\nURIs: http://ports.ubuntu.com/ubuntu-ports/\nSuites: noble noble-updates noble-backports noble-security\nComponents: main universe restricted multiverse\nArchitectures: arm64\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n' \
      > /etc/apt/sources.list.d/arm64.sources && \
    dpkg --add-architecture arm64 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      clang \
      zlib1g-dev \
      binutils-aarch64-linux-gnu \
      libc6-dev:arm64 \
      libstdc++-13-dev:arm64 \
      zlib1g-dev:arm64 && \
    rm -rf /var/lib/apt/lists/*
