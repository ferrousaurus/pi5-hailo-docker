FROM debian:trixie-slim

ARG HAILORT_VERSION=5.1.1
ARG HAILORT_DEB_URL=https://archive.raspberrypi.com/debian/pool/main/h/h10-hailort/h10-hailort_5.1.1_arm64.deb
ARG HAILORT_DEB_SHA256=6d19ca247030d4ab2f0ede3fe9f7c4959f12c0924d3d7d1d7368cecda450b2bf
ARG GENAI_VERSION=5.1.1
ARG GENAI_DEB_URL=https://dev-public.hailo.ai/2025_12/Hailo10/hailo_gen_ai_model_zoo_5.1.1_arm64.deb
ARG GENAI_DEB_SHA256=17d5b476320b72ec199032e7a7b87ba72cb51311d56a9f0604213b7a9056deb9

RUN set -eux; \
    test "$(dpkg --print-architecture)" = arm64; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl; \
    curl --fail --location --retry 3 --output /tmp/h10-hailort.deb "$HAILORT_DEB_URL"; \
    curl --fail --location --retry 3 --output /tmp/hailo-gen-ai-model-zoo.deb "$GENAI_DEB_URL"; \
    echo "$HAILORT_DEB_SHA256  /tmp/h10-hailort.deb" | sha256sum --check --status; \
    echo "$GENAI_DEB_SHA256  /tmp/hailo-gen-ai-model-zoo.deb" | sha256sum --check --status; \
    test "$(dpkg-deb --field /tmp/h10-hailort.deb Version)" = "$HAILORT_VERSION"; \
    test "$(dpkg-deb --field /tmp/hailo-gen-ai-model-zoo.deb Version)" = "$GENAI_VERSION"; \
    apt-get install -y --no-install-recommends /tmp/h10-hailort.deb /tmp/hailo-gen-ai-model-zoo.deb; \
    rm -f /tmp/h10-hailort.deb /tmp/hailo-gen-ai-model-zoo.deb; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

EXPOSE 8000

STOPSIGNAL SIGTERM
CMD ["hailo-ollama"]
