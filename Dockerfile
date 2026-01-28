# ---------- Builder stage ----------
FROM rust:1.75 AS builder

# List of targets to build (space-separated)
# Example:
# linux x86_64: x86_64-unknown-linux-gnu
# linux arm64:  aarch64-unknown-linux-gnu
# windows:      x86_64-pc-windows-gnu
ARG RUST_TARGETS="x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu x86_64-pc-windows-gnu"

WORKDIR /app

# Install cross-compilation dependencies
RUN apt-get update && apt-get install -y \
    gcc-aarch64-linux-gnu \
    mingw-w64 \
    && rm -rf /var/lib/apt/lists/*

# Copy manifest first for better caching
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main(){}" > src/main.rs
RUN cargo fetch

# Copy full source
COPY . .

# Add targets and build
RUN for target in $RUST_TARGETS; do \
        rustup target add $target; \
        cargo build --target=$target --release --verbose --all; \
    done

# Collect binaries
RUN mkdir -p /out && \
    for target in $RUST_TARGETS; do \
        mkdir -p /out/$target && \
        cp target/$target/release/* /out/$target/ || true; \
    done


# ---------- Nginx stage ----------
FROM nginx:alpine

# Remove default config
RUN rm /etc/nginx/conf.d/default.conf

# Simple file hosting config
COPY <<EOF /etc/nginx/conf.d/files.conf
server {
    listen 80;
    location / {
        root /usr/share/nginx/html;
        autoindex on;
    }
}
EOF

# Copy built binaries
COPY --from=builder /out /usr/share/nginx/html

EXPOSE 80
