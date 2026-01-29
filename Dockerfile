# =========================
# x86_64 builder
# =========================
FROM --platform=linux/amd64 rust:1.63.0-slim-bookworm AS builder-amd64

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    git \
    && rm -rf /var/lib/apt/lists/*

COPY . .

RUN cargo build \
    --release \
    --no-default-features \
    --features send3,crypto-ring

RUN mkdir -p /out/amd64 && \
    cp target/release/* /out/amd64/


# =========================
# ARM64 builder
# =========================
FROM --platform=linux/arm64 rust:1.63.0-slim-bookworm AS builder-arm64

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    git \
    && rm -rf /var/lib/apt/lists/*

COPY . .

RUN cargo build \
    --release \
    --no-default-features \
    --features send3,crypto-ring

RUN mkdir -p /out/arm64 && \
    cp target/release/* /out/arm64/


# =========================
# Final NGINX image
# =========================
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

COPY --from=builder-amd64 /out /usr/share/nginx/html/amd64
COPY --from=builder-arm64 /out /usr/share/nginx/html/arm64

EXPOSE 80
