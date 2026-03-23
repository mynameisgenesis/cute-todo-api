# ─────────────────────────────────────────
#  Stage 1: Build
# ─────────────────────────────────────────
FROM golang:1.26-alpine AS builder

# Install certificates for HTTPS calls made during build (e.g. go mod download)
RUN apk add --no-cache ca-certificates git

WORKDIR /app

# Cache dependencies before copying source
COPY go.mod go.sum ./
RUN go mod download

# Copy source and build a fully static binary
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o server .

# ─────────────────────────────────────────
#  Stage 2: Runtime
# ─────────────────────────────────────────
FROM scratch

# Trust system CAs (needed if your app makes outbound HTTPS requests)
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy the compiled binary
COPY --from=builder /app/server /server

# ── OpenShift requirements ──────────────
# OpenShift runs containers with a random UID in the root group (GID 0).
# Giving GID 0 execute permission satisfies that without granting full root.
USER 1001

EXPOSE 8080

ENTRYPOINT ["/server"]