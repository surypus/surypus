# ============================================================================
# Surypus ERP/CRM Docker Configuration
# ============================================================================
# Multi-stage build for production with optimized caching
# Single unified library project (no sub-packages)

# Stage 1: Build environment
FROM haskell:9.6.6 AS builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install build dependencies and PostgreSQL dev libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    build-essential \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy lock and cabal files first for dependency caching
COPY stack.yaml stack.yaml.lock* ./
COPY Surypus.cabal ./

# Pre-install dependencies (cached layer)
RUN stack setup --install-ghc && stack build --only-dependencies

# Copy project source
COPY src ./src
COPY app ./app
COPY config ./config
COPY web ./web

# Build library + executable with optimizations
RUN stack build --install-ghc --copy-bins --ghc-options="-O2 -j4"

# Stage 2: Production runtime (minimal)
FROM debian:bookworm-slim

# Install minimal runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    ca-certificates \
    curl \
    dumb-init \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create non-root user
RUN groupadd -r surypus && useradd -r -g surypus surypus

WORKDIR /app

# Copy binary from builder
COPY --from=builder /root/.local/bin/surypus-server /usr/local/bin/surypus-server

# Copy web assets
COPY --from=builder /build/web ./web

# Environment variables
ENV PORT=8080

# Expose port
EXPOSE 8080

# Health check (liveness + readiness)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/api/v1/health || exit 1

# Run with dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]
CMD ["surypus-server"]
