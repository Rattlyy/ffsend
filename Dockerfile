# ---------- Builder stage ----------
FROM rust:slim-bookworm AS builder

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
    wget curl git \
    && rm -rf /var/lib/apt/lists/*

# Install Rust 1.63.0
RUN rustup install $RUST_VERSION && rustup default $RUST_VERSION

# Copy Cargo.toml first for caching
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main(){}" > src/main.rs
RUN cargo fetch

# Copy full source
COPY . .

# ---------- Patch ffsend-api ----------
# Fix missing rand_bytes, type annotations, and function return types
RUN find ./ -type f -name '*.rs' -exec sed -i \
    -e 's/use super::{b64, rand_bytes}/use super::b64;/' \
    -e 's/let (result, nonce) = match self.version:/let (result, nonce): (RemoteFile, Vec<u8>) = match self.version:/' \
    -e 's/fn encrypt_aead(key_set: &KeySet, plaintext: &\[u8\]) -> Result<Vec<u8>, Error> {$/&\n    Ok(do_encryption(key_set, plaintext)?)/' \
    -e 's/fn decrypt_aead(key_set: &KeySet, payload: &mut \[u8\]) -> Result<Vec<u8>, Error> {$/&\n    Ok(do_decryption(key_set, payload)?)/' \
    -e 's/pub fn signature_encoded(key: &\[u8\], data: &\[u8\]) -> Result<String, ()> {$/&\n    Ok(sign_data(key, data))/' \
    {} +

# ---------- Cargo check stage ----------
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

# Collect binaries
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

# Copy built binaries
COPY --from=builder /out /usr/share/nginx/html

EXPOSE 80
