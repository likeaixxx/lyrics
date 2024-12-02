# Build stage
FROM --platform=linux/arm64 golang AS builder

WORKDIR /build

# Copy only dependency files first
COPY go.mod go.sum ./
RUN go mod download

# Copy ALL source files
COPY . .

# 添加调试命令
RUN ls -la
RUN ls -la route/
RUN ls -la provider/

# Build with optimizations
RUN CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -a -installsuffix cgo -ldflags="-w -s" -o lyrics .

# Final stage
FROM --platform=linux/arm64 debian:stable-slim

WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/lyrics .

EXPOSE 8331

ENTRYPOINT ["/app/lyrics"]
