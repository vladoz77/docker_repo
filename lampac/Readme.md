# LAMPAC Docker Compose Setup

This repository contains a Docker Compose configuration for running [LAMPAC](https://github.com/immisterio/Lampac) - a media aggregator and streaming platform.

## Prerequisites

- Docker installed on your system
- Docker Compose installed
- Proper DNS configuration pointing `lampa.home-local.site` to your host (or adjust the domain in `init.conf`)

## Installation

1. Clone this repository or create the files manually:
   - `docker-compose.yaml`
   - `init.conf`
   - `manifest.json`

2. Adjust the configuration files as needed (see Configuration section below)

3. Start the container:
   ```bash
   docker-compose up -d
   ```

## Configuration

### `init.conf`

Main configuration file for LAMPAC:

- `listenport`: 80 (HTTP port)
- `listenhost`: Domain name for the service
- `typecache`: Memory caching type (`mem`)
- Enabled modules: SISI, BongaCams, Runetki, etc.
- Disabled: Chromium, Firefox, DLNA cover, TorrServer

### `manifest.json`

Lists enabled modules/plugins:
- SISI.dll (enabled)
- Online.dll (enabled)
- DLNA.dll (enabled)
- JacRed.dll (enabled, with Jackett integration)
- TorrServer.dll (disabled)

### `docker-compose.yaml`

Basic container configuration:
- Exposes port 80
- Mounts config files
- Sets Moscow timezone
- Uses a dedicated network

## Accessing the Service

After starting the container, access LAMPAC at:
```
http://lampa.home-local.site
```

(or whatever domain you configured in `init.conf`)

## Maintenance

- **Restart the container**:
  ```bash
  docker-compose restart
  ```

- **View logs**:
  ```bash
  docker-compose logs -f
  ```

- **Update to latest version**:
  ```bash
  docker-compose pull
  docker-compose up -d
  ```

## Customization

1. To enable TorrServer, set `"enable": true` in `manifest.json`
2. To change caching settings, modify `init.conf`
3. To add new modules, include them in `manifest.json`

## Troubleshooting

If the service doesn't start:
1. Check container logs
2. Verify all config files are properly formatted (valid JSON)
3. Ensure port 80 is available on your host

## License

LAMPAC is licensed under its own terms. This setup is provided as-is.