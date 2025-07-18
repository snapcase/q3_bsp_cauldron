# Use multi-stage build to keep final image small
FROM elixir:1.18.4-alpine AS builder

# Set build ENV
ENV MIX_ENV=prod

# Create app directory
WORKDIR /app

# Install mix dependencies
RUN apk update && \
    apk add --no-cache \
    build-base \
    git \
    mix local.rebar --force && \
    mix local.hex --force

# Copy source code
COPY . .

RUN mix do deps.get, deps.compile, compile, release

# Start a new stage for runtime
FROM alpine:3.18.4 AS runtime

# Install runtime dependencies
RUN apk add --no-cache \
    libstdc++ \
    openssl \
    ncurses \
    inotify-tools

# Create app user
RUN addgroup -g 1000 appuser && \
    adduser -u 1000 -G appuser -s /bin/sh -D appuser

# Set environment
ENV MIX_ENV=prod

# Create app directory
WORKDIR /app

# Copy the release from build stage
COPY --from=builder --chown=appuser:appuser /app/_build/prod/rel/q3_bsp_cauldron ./

# Switch to app user
USER appuser

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:${PORT:-4000}/health || exit 1

# Default command
CMD ["./bin/q3_bsp_cauldron", "start"]