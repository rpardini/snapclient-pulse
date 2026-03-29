# syntax=docker/dockerfile:1.7
#
# Multi-arch, multi-stage Snapclient build with PulseAudio support.
# Final image contains only the snapclient binary + runtime deps.
#
# Build examples:
#   docker buildx build --platform linux/amd64,linux/arm64 \
#     -t yourrepo/snapclient-pulse:0.29.0 --push .
#   docker buildx build --platform linux/arm64 \
#     -t snapclient-pulse:local --load .
#
# Run example (remote TCP PulseAudio):
#   docker run --rm \
#     -e PULSE_SERVER="tcp:PA_SERVER_IP_OR_NAME:4713" \
#     yourrepo/snapclient-pulse:0.29.0 \
#     --host SNAPSERVER_IP_OR_NAME --player pulse

ARG DEBIAN_SUITE=trixie
ARG SNAPCAST_VERSION=0.29.0

# ---------------------------------------------------------------------------
# Build stage — compiles snapclient with PulseAudio and codec support
# ---------------------------------------------------------------------------
FROM debian:${DEBIAN_SUITE} AS build

ARG DEBIAN_FRONTEND=noninteractive
ARG SNAPCAST_VERSION

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN <<'EOF'
build_pkgs=(
  ca-certificates
  git
  build-essential
  cmake
  pkg-config

  # snapclient output backends
  libasound2-dev
  libpulse-dev

  # common codec/stream deps
  libvorbis-dev
  libopus-dev
  libflac-dev

  # avahi (mDNS discovery)
  libavahi-client-dev
)

apt-get update
apt-get install -y --no-install-recommends "${build_pkgs[@]}"
rm -rf /var/lib/apt/lists/*
EOF

RUN <<EOF
git clone --depth 1 --branch "v${SNAPCAST_VERSION}" \
  https://github.com/badaix/snapcast.git /src
EOF

RUN <<'EOF'
cmake -S /src -B /build -DCMAKE_BUILD_TYPE=Release
cmake --build /build --target snapclient -j"$(nproc)"
strip /build/bin/snapclient || true
EOF

# ---------------------------------------------------------------------------
# Runtime stage — minimal image with only the binary and required libs
# ---------------------------------------------------------------------------
FROM debian:${DEBIAN_SUITE}-slim AS runtime

ARG DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN <<'EOF'
runtime_pkgs=(
  ca-certificates

  # PulseAudio client library
  libpulse0

  # ALSA runtime (fallback / dependency of libpulse0)
  libasound2t64

  # codec runtime libs
  libvorbis0a
  libopus0
  libflac14

  # avahi client runtime
  libavahi-client3
)

apt-get update
apt-get install -y --no-install-recommends "${runtime_pkgs[@]}"
rm -rf /var/lib/apt/lists/*
EOF

COPY --from=build /build/bin/snapclient /usr/local/bin/snapclient

ENTRYPOINT ["/usr/local/bin/snapclient"]
CMD ["--player", "pulse"]
