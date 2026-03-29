# snapclient-pulse

Multi-arch (`linux/amd64`, `linux/arm64`) Docker image that builds
[Snapclient](https://github.com/badaix/snapcast) from source on Debian Trixie
with PulseAudio support enabled.  The final image contains only the compiled
`snapclient` binary and the minimum runtime dependencies.

## Build multi-arch image locally with buildx

```bash
# Build and push to a registry
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg SNAPCAST_VERSION=0.29.0 \
  -t yourrepo/snapclient-pulse:0.29.0 \
  --push .

# Build for the local machine only (no push)
docker buildx build \
  --platform linux/arm64 \
  -t snapclient-pulse:local \
  --load .
```

Available build args (with defaults):

| Arg | Default |
|-----|---------|
| `SNAPCAST_VERSION` | `0.29.0` |
| `DEBIAN_SUITE` | `trixie` |

## Run snapclient with remote TCP PulseAudio

Point the container at a remote PulseAudio server using the `PULSE_SERVER`
environment variable.  The remote server must have `module-native-protocol-tcp`
loaded (ideally with `auth-anonymous=1` or a shared cookie).

```bash
docker run --rm \
  -e PULSE_SERVER="tcp:PA_SERVER_IP_OR_NAME:4713" \
  ghcr.io/rpardini/snapclient-pulse:latest \
  --host SNAPSERVER_IP_OR_NAME \
  --player pulse
```

With `docker compose`:

```yaml
services:
  snapclient:
    image: ghcr.io/rpardini/snapclient-pulse:latest
    restart: unless-stopped
    environment:
      PULSE_SERVER: "tcp:PA_SERVER_IP_OR_NAME:4713"
    command:
      - "--host"
      - "SNAPSERVER_IP_OR_NAME"
      - "--player"
      - "pulse"
```

## Pre-built images

Images are automatically built and pushed to GHCR on every push to `main`:

```
ghcr.io/rpardini/snapclient-pulse:<run_number>
```
