FROM debian:trixie-slim

# libfontconfig1 pulls in freetype/expat automatically; SkiaSharp needs it for
# font handling even in headless framebuffer mode.
# libicu76 is required because the app keeps full ICU (InvariantGlobalization=false)
# so DateTime formatting stays locale-aware instead of falling back to English names.
# No GL/DRM/libinput packages: the app renders via fbdev and uses NullInputBackend.
RUN apt-get update && \
    apt-get install -y --no-install-recommends libfontconfig1 libicu76 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY publish/linux-arm64/ ./
RUN chmod +x ./KioskHelloWorld

ENTRYPOINT ["./KioskHelloWorld", "--kiosk-mode"]
