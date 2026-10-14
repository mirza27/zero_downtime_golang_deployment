FROM golang:1.26-alpine AS builder

WORKDIR /app

ARG APP_VERSION=dev

COPY go.mod ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-X main.version=${APP_VERSION}" \
    -o /app/server .   

# run
FROM scratch

WORKDIR /app

COPY --from=builder /app/server /app/server

EXPOSE 8080

ENTRYPOINT ["/app/server"]