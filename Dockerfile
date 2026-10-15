FROM golang:1.26-alpine AS builder

WORKDIR /app

ARG APP_VERSION=dev

COPY go.mod ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-X main.version=${APP_VERSION}" \
    -o /app/server ./cmd/app

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -o /tool/manager ./cmd/manager

# run
FROM alpine:3.22

WORKDIR /app

COPY --from=builder /app/server /app/server
COPY --from=builder /tool/manager /tool/manager

EXPOSE 8080

ENTRYPOINT ["/tool/manager"]