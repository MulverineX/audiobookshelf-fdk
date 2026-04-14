# audiobookshelf-fdk

Audiobookshelf with **fdk-aac** support, enabling xHE-AAC/USAC audio decoding for high-quality Audible downloads from Libation.

## Why?

The official Audiobookshelf Docker image ships with an older ffmpeg that lacks xHE-AAC/USAC support. This image replaces ffmpeg with a custom build that includes the Fraunhofer FDK AAC decoder, enabling playback of xHE-AAC audiobooks (e.g., from Libation with "use widevine DRM" disabled).

## Quick Start

```yaml
services:
  audiobookshelf:
    image: ghcr.io/mulverinex/audiobookshelf-fdk:latest
    ports:
      - 13378:80
    volumes:
      - ./audiobooks:/audiobooks
      - ./podcasts:/podcasts
      - ./metadata:/metadata
      - ./config:/config
    restart: unless-stopped
```

## Tags

| Tag | Description |
|-----|-------------|
| `latest` | Latest stable release |
| `edge` | Bleeding edge |
| `2.x.x` | Specific version |

## Auto-Update

This image rebuilds automatically when upstream Audiobookshelf releases a new version (checked twice daily at 9am/9pm UTC).

## Provenance

This image is built with **SLSA provenance attestation** and **SBOM**, providing supply-chain security guarantees about how the image was built.

## Build from Source

```bash
# Clone
git clone git@github.com:MulverineX/audiobookshelf-fdk.git
cd audiobookshelf-fdk

# Build locally
docker build --build-arg AUDIOBOOKSHELF_TAG=latest -t audiobookshelf-fdk:local .

# Or use docker compose
docker compose up -d
```

## License

This project is for personal use. The fdk-aac encoder is non-free and cannot be distributed with GPL-licensed code in pre-built binaries. The Dockerfile builds fdk-aac from source so you can build your own image.
