# ---------- Builder stage ----------
FROM rust:slim-bookworm AS builder

# Arguments for Rust version and targets
ARG RUST_VERSION=stable
ARG RUST_TARGETS="x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu x86_64-pc-windows-gnu"

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    libssl-dev \
    gcc-aarch64-linux-gnu \
    mingw-w64 \
    musl-tools \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Rust version
RUN rustup install $RUST_VERSION && rustup default $RUST_VERSION

# Copy source code
COPY . .

# Disable clipboard-bin in all builds
ENV CARGO_FEATURES="--no-default-features"

# ---------- Cargo check stage ----------
RUN cargo check $CARGO_FEATURES --verbose \
 && cargo check $CARGO_FEATURES --features send3,crypto-ring --verbose \
 && cargo check $CARGO_FEATURES --features send2,crypto-openssl --verbose \
 && cargo check $CARGO_FEATURES --features send3,crypto-openssl --verbose \
 && cargo check $CARGO_FEATURES --features send2,send3,crypto-openssl --verbose \
 && cargo check $CARGO_FEATURES --features send3,crypto-ring,archive --verbose \
 && cargo check $CARGO_FEATURES --features send3,crypto-ring,history --verbose \
 && cargo check $CARGO_FEATURES --features send3,crypto-ring,qrcode --verbose \
 && cargo check $CARGO_FEATURES --features send3,crypto-ring,urlshorten --verbose \
 && cargo check $CARGO_FEATURES --features send3,crypto-ring,infer-command --verbose \
 && cargo check $CARGO_FEATURES --features no-color --verbose


# Build binaries for all targets
RUN for target in $RUST_TARGETS; do \
        echo "Adding target $target"; \
        rustup target add $target; \
        cargo build $CARGO_FEATURES --target=$target --release --verbose --all; \
    done

# Collect binaries in /out
RUN mkdir -p /out && \
    for target in $RUST_TARGETS; do \
        mkdir -p /out/$target && \
        cp target/$target/release/* /out/$target/ || true; \
    done

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

# Copy all built binaries from builder
COPY --from=builder /out /usr/share/nginx/html

EXPOSE 80
