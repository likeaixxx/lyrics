# Build stage
FROM golang AS builder
WORKDIR /build
# Copy only dependency files first
COPY go.mod go.sum ./
RUN go mod download
# Copy source code
COPY . .
# Build with optimizations
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags="-w -s" -o lyrics .

# Final stage
FROM scratch

WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/lyrics .

EXPOSE 8331

ENTRYPOINT ["/app/lyrics"]
