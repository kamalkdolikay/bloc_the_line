# ---- Build Stage ----
FROM elixir:1.17-otp-26-alpine AS builder

# Install everything we might need
RUN apk add --no-cache build-base git nodejs-current npm

ENV MIX_ENV=prod
WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

# Copy mix files (cache deps)
COPY mix.exs mix.lock ./
COPY config/*.exs config/
RUN mix deps.get --only prod
RUN mix deps.compile

# === ASSETS: only run npm if package.json actually exists ===
COPY assets ./assets

# Check if package.json exists → only then run npm install
RUN if [ -f assets/package.json ]; then \
    cd assets && npm ci --prefer-offline --no-audit --progress=false && cd ..; \
    else \
    echo "No package.json found → skipping npm install (you probably only have static files)"; \
    fi

# Deploy assets only if esbuild/tailwind is configured (safe to run always)
RUN mix assets.deploy || echo "No assets to deploy (this is fine if you only have static files)"

# Copy source code
COPY . .

# BUILD ASSETS
RUN mix assets.deploy

# Final compile + release
RUN mix compile
RUN mix release

# ---- Runtime Stage ----
FROM alpine:3.20

RUN apk add --no-cache libstdc++ openssl ncurses-libs bash
RUN addgroup -g 1000 phoenix && adduser -D -u 1000 -G phoenix phoenix

WORKDIR /app
COPY --from=builder --chown=phoenix:phoenix /app/_build/prod/rel/bloc_the_line .

USER phoenix
EXPOSE 4000
ENV PORT=4000
ENV PHX_SERVER=true

CMD ["bin/bloc_the_line", "start"]