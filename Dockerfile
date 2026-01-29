# ---------- Builder stage ----------
FROM rust:slim-bookworm AS builder

ARG RUST_VERSION=stable
ARG RUST_TARGETS="x86_64-unknown-linux-musl"

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    libssl-dev \
    gcc-aarch64-linux-gnu \
    mingw-w64 \
    musl-tools \
    wget curl git \
    gcc-aarch64-linux-gnu \
    libc6-dev-arm64-cross \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Install Rust 1.63.0
RUN rustup install stable && rustup default stable

# Copy full source
COPY . .

RUN rustup target add x86_64-unknown-linux-gnu
RUN rustup target add x86_64-pc-windows-gnu
RUN rustup target add aarch64-unknown-linux-gnu

RUN cargo build --target=x86_64-unknown-linux-gnu --release --verbose
RUN cargo build --target=aarch64-unknown-linux-gnu --release --verbose
RUN cargo build --target=x86_64-pc-windows-gnu --release --verbose

RUN mkdir -p /out \
    cp target/x86_64-unknown-linux-gnu/release/* /out/ || true && \
    cp target/aarch64-unknown-linux-gnu/release/* /out/ || true && \
    cp target/x86_64-pc-windows-gnu/release/* /out/ || true

# ---------- Nginx stage ----------
FROM nginx:alpine

# Enable directory listing
RUN rm /etc/nginx/conf.d/default.conf
COPY <<EOF /etc/nginx/conf.d/files.conf
server {
    listen 80;
    server_name _;

    location / {
        root /usr/share/nginx/html;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
    }
}
EOF

# Copy built binaries
COPY --from=builder /out /usr/share/nginx/html

EXPOSE 80
