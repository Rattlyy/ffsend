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
    && rm -rf /var/lib/apt/lists/*

# Install Rust 1.63.0
RUN rustup install $RUST_VERSION && rustup default $RUST_VERSION

# Copy full source
COPY . .

RUN apt-get install -y build-essential wget musl-tools
RUN wget https://github.com/openssl/openssl/releases/download/openssl-3.0.15/openssl-3.0.15.tar.gz
RUN tar xzvf openssl-3.0.15.tar.gz
WORKDIR /app/openssl-3.0.15
RUN ./config no-async -fPIC --openssldir=/usr/local/ssl --prefix=/usr/local
RUN make && make install 
WORKDIR /app
RUN export OPENSSL_STATIC=1
RUN export OPENSSL_LIB_DIR=/usr/local/lib64
RUN export OPENSSL_INCLUDE_DIR=/usr/local/include

RUN rustup target add $RUST_TARGET
RUN cargo build --target=$RUST_TARGET --release --verbose


# ---------- Build binaries ----------
#RUN for target in $RUST_TARGETS; do \
#        echo "Adding target $target"; \
##       rustup target add $target; \
#        cargo build $CARGO_FEATURES --target=$target --release --verbose --all; \
#    done

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
