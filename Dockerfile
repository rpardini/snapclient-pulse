ARG DEBIAN_SUITE=trixie
# Should match MA's version of snapserver, which is currently 0.34.0
ARG SNAPCAST_VERSION=0.34.0

# --- Build stage ---
FROM debian:${DEBIAN_SUITE} AS build
ARG DEBIAN_FRONTEND=noninteractive

RUN <<EOF
  sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/debian.sources
  apt-get update
  apt-get install -y --no-install-recommends ca-certificates git build-essential libpulse-dev
  apt-get build-dep -y snapclient
EOF

ARG SNAPCAST_VERSION
RUN git clone --depth 1 --branch "v${SNAPCAST_VERSION}" https://github.com/badaix/snapcast.git /src

WORKDIR /src/build

RUN <<EOF
  cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_WITH_PULSE=ON -DBUILD_WITH_AVAHI=OFF -DBUILD_SERVER=OFF
EOF

WORKDIR /src/build
RUN <<EOF
  cmake --build . --target snapclient -j$(nproc)
EOF

RUN <<EOF
  ls -lah /src/bin/snapclient
  strip /src/bin/snapclient
  ls -lah /src/bin/snapclient
EOF

# --- Runtime stage ---
FROM debian:${DEBIAN_SUITE}-slim
ARG DEBIAN_FRONTEND=noninteractive

RUN <<EOF
  apt-get update
  apt-get install -y --no-install-recommends libpulse0 snapclient # cheat
  rm -rf /var/lib/apt/lists/*
EOF

COPY --from=build /src/bin/snapclient /usr/bin/snapclient

ENV PULSE_SERVER=192.168.66.21
RUN /usr/bin/snapclient --list --player=pulse || true

ENTRYPOINT ["/usr/bin/snapclient"]
CMD ["tcp://snap:1704", "--player=pulse", "--mixer=hardware", "--logsink=stdout", "--hostID=inthecluster3", "--soundcard=alsa_output.2.stereo-fallback"]
