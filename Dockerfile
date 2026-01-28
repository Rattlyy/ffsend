# ---------- Builder stage ----------
FROM rust:slim-bookworm AS builder

# Rust version fixed to 1.63.0 (MSRV)
ARG RUST_VERSION=1.63.0
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

# Copy Cargo.toml first for caching
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main(){}" > src/main.rs
RUN cargo fetch

# Copy full source
COPY . .

# ---------- Cargo check stage (disable clipboard-bin) ----------
ENV CARGO_FEATURES="--no-default-features"

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

# ---------- Build binaries ----------
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
