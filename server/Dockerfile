# ---------- Stage 1: Build ----------------------------------------------------
# 1. Use a specific Go minor version for reproducibility
FROM golang:1.23.3-bookworm AS builder

# 2. Enable Go modules & turn off CGO right away
ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

WORKDIR /src

# 3. Download dependencies first (better layer caching)
COPY go.mod go.sum ./
RUN go mod download

# 4. Copy the rest of the source and build
COPY . .
RUN go build -trimpath -ldflags="-s -w" -o /src/lyrics .

# ---------- Stage 2: Minimal runtime -----------------------------------------
# 5. Use distroless instead of Debian slim (smaller & safer)
FROM gcr.io/distroless/static-debian12:nonroot

# 6. Workdir and non-root already set by distroless, just copy binary
WORKDIR /app
COPY --from=builder /src/lyrics .

# 7. Expose & run
EXPOSE 8331
ENTRYPOINT ["/app/lyrics"]