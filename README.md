# raspberrypi-kiosk

Avalonia "hello world" (current date/time, white on black, auto-scaling to any
resolution with a 10% left/right margin) that runs either as a normal desktop
window or as a Raspberry Pi kiosk rendering straight to the Linux framebuffer.

- `--kiosk-mode` selects framebuffer mode (`Avalonia.LinuxFramebuffer`,
  `/dev/fb0`); no flag runs a normal desktop window.
- Source: [src/KioskHelloWorld](src/KioskHelloWorld).

## Desktop mode (Windows/Linux/macOS dev machine)

```
dotnet run --project src/KioskHelloWorld
```

## Building for the Raspberry Pi (arm64, Native AOT)

Native AOT can't cross the OS boundary (Windows -> Linux), and running the
.NET SDK itself under QEMU arm64 emulation is unstable (it can crash MSBuild
with `AccessViolationException`). So we cross-*link* instead: run the SDK
natively as `linux/amd64` and only target arm64 for the final link step, using
a clang cross-toolchain.

One-time setup — build the toolchain image (bakes in the arm64 sysroot so you
don't re-run `apt-get` on every publish):

```
docker build --platform linux/amd64 -t kiosk-arm64-builder -f arm64-builder.Dockerfile .
```

Then publish (fast, no apt installs, reuses the image above):

```
docker run --rm --platform linux/amd64 \
  -v "//c/Git/raspberrypi-kiosk:/src" -w /src/src/KioskHelloWorld \
  kiosk-arm64-builder \
  dotnet publish -c Release -r linux-arm64 -p:PublishAot=true -p:StripSymbols=false -o /src/publish/linux-arm64
```

(`-p:StripSymbols=false` skips a post-link `objcopy --only-keep-debug` step
that uses the host's amd64 `objcopy`, which can't parse the arm64 binary.)

Output lands in `publish/linux-arm64/`: the native `KioskHelloWorld`
executable plus `libSkiaSharp.so` / `libHarfBuzzSharp.so`, which must ship
alongside it.

### Deploy as a bare binary

```
scp -r publish/linux-arm64 pi@<raspberry-pi-ip>:/home/pi/kiosk-app
ssh pi@<raspberry-pi-ip>
cd /home/pi/kiosk-app
chmod +x KioskHelloWorld
sudo apt-get install -y libfontconfig1 libicu76   # see "Runtime dependencies" below
./KioskHelloWorld --kiosk-mode
```

### Deploy as a Docker container

Build the runtime image (also on Windows, via buildx/QEMU — this one is just
`apt-get` + copying files, so emulation is fine here, unlike the SDK build
above):

```
docker buildx build --platform linux/arm64 -f kiosk-runtime.Dockerfile -t kiosk-helloworld:arm64 --load .
docker save kiosk-helloworld:arm64 -o publish/kiosk-helloworld-arm64.tar
```

Copy the tar and `docker-compose.yml` to the Pi, then:

```
docker load -i kiosk-helloworld-arm64.tar
docker tag kiosk-helloworld:arm64 kiosk-helloworld:latest
docker compose up -d
```

To run automatically on boot, install the systemd unit:

```
sudo cp kiosk-helloworld.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now kiosk-helloworld.service
```

(Edit `WorkingDirectory` in [kiosk-helloworld.service](kiosk-helloworld.service)
if the repo doesn't live at `/home/pi/kiosk-app` on your Pi.)

## Runtime dependencies (the Pi, container or bare metal)

- `libfontconfig1` — SkiaSharp needs it for font handling, even headless.
- `libicu76` (or whatever ICU build your base ships) — the app keeps full ICU
  (`InvariantGlobalization=false` in the csproj) so `DateTime` formatting
  stays locale-aware instead of falling back to English names.
- **glibc version**: the AOT binary is linked against whatever `kiosk-arm64-builder`
  uses (currently Ubuntu 24.04/noble, glibc 2.39), so it requires `GLIBC_2.38+`
  on the target. `debian:bookworm-slim` (glibc 2.36) is too old and fails with
  `version 'GLIBC_2.38' not found`; `debian:trixie-slim` (glibc 2.41) works and
  stays smaller than `ubuntu:24.04`. If you bump the SDK/Ubuntu version in
  `arm64-builder.Dockerfile`, re-check this.
- No GL/DRM/`libinput` packages needed: the app renders via plain fbdev and
  the kiosk builder passes `NullInputBackend` explicitly (a hello-world clock
  takes no input, so there's no reason to pull in `libinput.so.10`).

## Other kiosk niceties (Raspberry Pi OS console, not this app)

- Disable the blinking console cursor: append `vt.global_cursor_default=0` to
  `/boot/firmware/cmdline.txt`, then reboot. (Or test live, non-persistently:
  `sudo sh -c "echo 0 > /sys/class/graphics/fbcon/cursor_blink"`.)
- Stop the login prompt competing for the console the app uses:
  `sudo systemctl disable --now getty@tty1.service` (only do this if you have
  another way to reach the Pi, e.g. SSH, since it removes local tty1 login).

## Cross-arch apt gotcha (Ubuntu builder image only)

Ubuntu's default mirror (`archive.ubuntu.com`) only carries `amd64` packages;
arm64 packages live on `ports.ubuntu.com`. `arm64-builder.Dockerfile` adds a
second apt source for that, restricted to `Architectures: arm64`, alongside
the default source restricted to `Architectures: amd64`. Debian's default
mirrors don't have this split, which is why `kiosk-runtime.Dockerfile` (Debian
based) doesn't need it.
