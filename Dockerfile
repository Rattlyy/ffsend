# =========================
# x86_64 builder
# =========================
FROM --platform=linux/amd64 rust AS builder-amd64

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

# Copy the latest built binary automatically
RUN mkdir -p /out/amd64 && \
    find target/release -maxdepth 1 -type f -executable ! -name '*.d' -exec cp {} /out/amd64/ \;


# =========================
# ARM64 builder
# =========================
FROM --platform=linux/arm64 rust AS builder-arm64

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
    find target/release -maxdepth 1 -type f -executable ! -name '*.d' -exec cp {} /out/arm64/ \;


# =========================
# NGINX final stage
# =========================
FROM nginx:alpine

LABEL org.opencontainers.image.title="ffsend" \
      org.opencontainers.image.description="Multi-arch NGINX image serving Rust ffsend binaries" \
      org.opencontainers.image.url="https://github.com/Rattlyy/ffsend" \
      org.opencontainers.image.source="https://github.com/Rattlyy/ffsend" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.authors="Rattlyy <me@gmmz.dev>"

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

COPY --from=builder-amd64 /out/amd64 /usr/share/nginx/html/amd64
COPY --from=builder-arm64 /out/arm64 /usr/share/nginx/html/arm64

EXPOSE 80
