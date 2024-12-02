# Build stage
FROM golang:1.18-alpine AS builder

# Add necessary build tools
RUN apk add --no-cache git

WORKDIR /build

# Copy only dependency files first
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build with optimizations
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags="-w -s" -o lyrics .

# Final stage
FROM alpine:3.18

# Add CA certificates for HTTPS
RUN apk --no-cache add ca-certificates

# Create non-root user
RUN adduser -D appuser

WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/lyrics .

# Use non-root user
USER appuser

EXPOSE 8331

# Proper signal handling
ENTRYPOINT ["/app/lyrics"]
