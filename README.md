# OpenWrt Builder

[![Русская версия](https://img.shields.io/badge/lang-ru-blue)](README.ru.md)

Dockerized build system for OpenWrt firmware. Supports custom devices, patches, and configs via a pluggable `custom/` submodule.

Based on OpenWrt **v25.12.4**.

## Requirements

- Docker with buildx
- Git
- Make

## Quick Start

```bash
git clone --recurse-submodules <repo-url>
cd firmware
make build-system
make firmware
```

## Make Targets

| Target | Description |
|--------|-------------|
| `build-system` | Build the Docker image |
| `firmware` | Build firmware inside container |
| `shell` | Interactive shell inside build container |
| `clean` | Remove build_dir and staging_dir cache |

## Configuration

`build.sh` accepts one or more config files as arguments. Configs are concatenated in order (last value wins), then `make defconfig` fills in the rest.

```bash
# Default (set in Makefile)
make firmware

# Override configs
make firmware CONFIGS="custom/configs/common.config custom/configs/mt7981.config"

# Vanilla OpenWrt without custom submodule
make firmware CONFIGS="configs/mt7981.config"
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CONFIGS` | `custom/configs/common.config custom/configs/tr.config` | Config files to merge |
| `MAKE_JOBS` | `$(nproc)` | Parallel jobs |
| `MAKE_OPTS` | `V=s` | Extra make flags |

## Project Structure

```
.
├── Dockerfile          # Build environment (Debian trixie)
├── Makefile            # Docker orchestration
├── build.sh            # Build script (runs inside container)
├── configs/            # Base configs (public)
│   └── mt7981.config   # Minimal mediatek/filogic target
├── custom/             # Git submodule (optional, private)
│   ├── configs/        # Full build configs
│   ├── devices/        # DTS files and device patches
│   └── base-files/     # System patches and overlays
├── output/             # Firmware images after build
└── .cache/             # Persistent build cache
    ├── dl/             # Downloaded sources
    ├── feeds/          # OpenWrt package feeds
    ├── build_dir/      # Intermediate build artifacts
    ├── staging_dir/    # Toolchain
    └── ccache/         # Compiler cache
```

## Custom Submodule

The `custom/` directory is optional. Without it, a vanilla OpenWrt image is built.

To add your own devices, create a repository with:

```
custom/
├── configs/
│   ├── common.config       # Shared package selection
│   └── <platform>.config   # Target + device-specific options
├── devices/
│   └── <vendor>/
│       ├── files/          # DTS and board files (copied into source tree)
│       └── patches/        # Patches for existing OpenWrt files
└── base-files/
    ├── etc/                # Overlay files (banner, hostname, etc.)
    └── *.patch             # Patches for base-files package
```

Then add it as a submodule:

```bash
git submodule add git@github.com:user/my-custom.git custom
```

## Cache

Build cache persists in `.cache/`. First build downloads everything (~40 min), subsequent builds reuse the cache.

To fully reset:

```bash
make clean              # Remove build_dir + staging_dir
rm -rf .cache           # Remove everything including downloads
```
