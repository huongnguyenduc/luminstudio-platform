FROM docker.io/library/rust:1.95-bookworm AS build

WORKDIR /src
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential ca-certificates pkg-config \
    && rm -rf /var/lib/apt/lists/*

COPY Cargo.toml Cargo.lock ./
COPY services/worker-3d/Cargo.toml services/worker-3d/Cargo.toml
COPY services/worker-3d/src services/worker-3d/src
RUN cargo build --release -p worker-3d --bin worker-3d

FROM docker.io/library/debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends blender ca-certificates libegl1 python3-numpy webp \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /src/target/release/worker-3d /usr/local/bin/worker-3d
COPY services/worker-3d/scripts/render_360_sprite.py /opt/lumin/render_360_sprite.py

ENV WORKER_RUNTIME=1 \
    BLENDER_BINARY=/usr/bin/blender \
    BLENDER_RENDER_SCRIPT=/opt/lumin/render_360_sprite.py \
    HOME=/tmp

USER 65532:65532
ENTRYPOINT ["/usr/local/bin/worker-3d"]
