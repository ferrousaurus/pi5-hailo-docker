# Hailo-Ollama on Raspberry Pi 5 with Coolify

This project runs Hailo-Ollama in a Docker container on a Raspberry Pi 5 with an AI HAT+ 2 (Hailo-10H). The Hailo kernel driver stays on the Pi host. The container contains the Hailo runtime userspace libraries and Hailo-Ollama.

The Compose file does not publish a host port. The API is intended for private Docker-network access, not direct public access.

## Requirements

- Raspberry Pi 5, AI HAT+ 2, and 64-bit Raspberry Pi OS Trixie.
- The host Hailo setup installed with `hailo-h10-all`, followed by a reboot.
- Docker Engine with the Compose plugin on the Pi.
- Coolify connected to the Pi as a deployment server if using Coolify.

Raspberry Pi documents `hailortcli fw-control identify` as the host hardware check. Before deploying, check the installed Hailo packages and actual device node:

```sh
uname -m
cat /etc/os-release
dpkg-query -W '*hailo*' '*hailort*'
found=0
for device in /dev/hailo0 /dev/h1x-0; do
  if [ -e "$device" ]; then
    ls -l "$device"
    found=1
  fi
done
test "$found" -eq 1 || { echo 'No Hailo device node found' >&2; exit 1; }
hailortcli fw-control identify
```

Use the actual device node reported on the host. This project defaults to `/dev/hailo0`; some Hailo examples use `/dev/h1x-0` instead. Do not enable privileged mode or add the `video` group unless host device permissions show it is required.

## Package versions and integrity

The Dockerfile currently pins these ARM64 Debian packages to version 5.1.1:

- HailoRT `h10-hailort` from the Raspberry Pi package archive.
- Hailo GenAI Model Zoo from Hailo's public package URL.

The Dockerfile verifies each downloaded package against its SHA-256 digest and checks its package version before installation. The digest values were calculated from the official package downloads and are pinned in the Dockerfile. Verify them independently before relying on them in a production supply chain.

The versions are a starting point, not a guarantee that they match every host installation. Confirm compatibility with the runtime and driver installed on the target Pi before deployment. Do not update the host Hailo packages automatically as part of this build.

The GenAI 5.1.1 package does not document `OLLAMA_HOST`. Its packaged configuration sets the server host to `0.0.0.0` and port to `8000`, which allows other containers to reach it. This project relies on that package default and does not set an environment variable whose support is version-dependent.

## Run with Docker Compose

On the Pi, clone this repository and set the device path:

```sh
cp .env.example .env
# Edit .env if the Pi reports a device node other than /dev/hailo0.
docker compose config
docker compose up --build -d
docker compose ps
docker compose logs -f hailo-ollama
```

The first build downloads the pinned package files. The named `hailo-model-blobs` volume persists downloaded model blobs at `/usr/share/hailo-ollama/models/blob`. Model manifests remain in the image at `/usr/share/hailo-ollama/models/manifests`, following Hailo's Docker example. Keep the volume when recreating or upgrading the container.

Check API readiness inside the container:

```sh
docker compose exec hailo-ollama \
  curl --fail --silent --show-error http://127.0.0.1:8000/api/version
```

List available models and pull a model from the supported list:

```sh
docker compose exec hailo-ollama \
  curl --fail --silent --show-error http://127.0.0.1:8000/hailo/v1/list

docker compose exec -T hailo-ollama \
  curl --no-buffer --fail --silent --show-error http://127.0.0.1:8000/api/pull \
  -H 'Content-Type: application/json' \
  -d @- <<'JSON'
{"model":"qwen2:1.5b","stream":true}
JSON
```

Replace `qwen2:1.5b` with a model returned by `/hailo/v1/list`. A model pull may take time and uses network access from the Pi.

Test generation after the pull:

```sh
docker compose exec -T hailo-ollama \
  curl --fail --silent --show-error http://127.0.0.1:8000/api/generate \
  -H 'Content-Type: application/json' \
  -d @- <<'JSON'
{"model":"qwen2:1.5b","prompt":"Why is the sky blue?","stream":false}
JSON
```

An HTTP health check does not prove that the accelerator works. Successful model inference is the hardware validation.

## Deploy with Coolify

1. Push this project to a Git repository accessible to Coolify.
2. Add the Pi as a Coolify deployment server. Deploy this Compose application to the Pi, not the Coolify control-plane server.
3. Create a Git-based Docker Compose application and select `docker-compose.yml`.
4. Set the environment variable `HAILO_DEVICE` to the actual host device path.
5. Keep Raw Compose mode disabled. Do not add a public domain or port mapping if the API should remain private.
6. Deploy, then confirm in the container terminal that the device is present and the `/api/version` health check passes.

The Compose file has no `ports:` entry. Other services in the same Compose application can address the API by service name at `http://hailo-ollama:8000`. For a separate Coolify application, configure and verify a private shared network; do not assume separate Compose projects can reach each other by service name.

To make private administrative requests through Coolify's container terminal, run the `curl` commands above inside the container. Avoid publishing port 8000 merely to pull a model.

## Operations

- Do not run the host `hailo-ollama` service at the same time as this container; both may contend for the Hailo device.
- Keep the host driver and firmware installed on the Pi. The container only supplies userspace components.
- Back up the Compose named volume `hailo-model-blobs` (Coolify may prefix its deployed name). Do not remove it during redeploys if downloaded models should be retained.
- Hailo-Ollama uses a REST API; the standard Ollama CLI is not supported. Hailo documents one simultaneous connection with one pending request and does not support running multiple LLM/VLM models at once.
- The API has no authentication configured here. Keep it on a trusted private network or add an authenticated gateway before allowing access from untrusted networks.

## Sources

- [Raspberry Pi AI setup](https://www.raspberrypi.com/documentation/computers/ai.html)
- [Hailo GenAI usage guide](https://github.com/hailo-ai/hailo_model_zoo_genai/blob/main/docs/USAGE.rst)
- [Coolify Docker Compose deployments](https://coolify.io/docs/applications/builds/docker-compose)
