FROM golang:1.18 AS builder
WORKDIR /app
COPY go.mod ./
COPY go.sum ./
RUN go mod download
COPY . .
RUN go build -a -installsuffix cgo -o lyrics .
RUN chmod +x lyrics

FROM scratch
WORKDIR /
COPY --from=builder /app/lyrics .
EXPOSE 8080
CMD ["/lyrics"]
