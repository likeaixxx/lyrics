FROM golang AS builder
WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags="-w -s" -o lyrics .

# 使用 debian slim 替代 alpine
FROM debian:12-slim

WORKDIR /app

# 安装证书
RUN apt-get update && \
    apt-get install -y ca-certificates && \
    update-ca-certificates

# 从构建阶段复制二进制文件
COPY --from=builder /build/lyrics .

EXPOSE 8331

ENTRYPOINT ["/app/lyrics"]
