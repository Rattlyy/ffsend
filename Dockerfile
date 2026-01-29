# ---------- Builder stage ----------
FROM rust AS builder

WORKDIR /app

# Install cross toolchains (NO OpenSSL)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc-aarch64-linux-gnu \
    mingw-w64 \
    musl-tools \
    ca-certificates \
    git \
    && rm -rf /var/lib/apt/lists/*

# Add Rust targets
RUN rustup target add \
    x86_64-unknown-linux-gnu \
    aarch64-unknown-linux-gnu \
    x86_64-pc-windows-gnu

# Copy source
COPY . .

# ---------- Build step 1: Linux x86_64 ----------
RUN cargo build \
    --target=x86_64-unknown-linux-gnu \
    --no-default-features \
    --features send3,crypto-ring \
    --release

# ---------- Build step 2: Linux ARM64 ----------
RUN cargo build \
    --target=aarch64-unknown-linux-gnu \
    --no-default-features \
    --features send3,crypto-ring \
    --release

# ---------- Build step 3: Windows ----------
RUN cargo build \
    --target=x86_64-pc-windows-gnu \
    --no-default-features \
    --features send3,crypto-ring \
    --release

# Collect artifacts
RUN mkdir -p /out && \
    cp target/x86_64-unknown-linux-gnu/release/* /out/ && \
    cp target/aarch64-unknown-linux-gnu/release/* /out/ && \
    cp target/x86_64-pc-windows-gnu/release/*.exe /out/

# ---------- Nginx stage ----------
FROM nginx:alpine

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

COPY --from=builder /out /usr/share/nginx/html

EXPOSE 80
