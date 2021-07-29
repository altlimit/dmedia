FROM golang:1.16-alpine as builder

WORKDIR /build

RUN apk update \
  && apk add --no-cache git \
  && apk add --no-cache ca-certificates \
  && apk add --update gcc musl-dev \
  && update-ca-certificates
COPY go.mod .
COPY go.sum .
RUN go mod download

COPY . .

RUN CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o dmedia

FROM alpine:3.14 as app

RUN apk update \
  && apk add --no-cache ffmpeg

WORKDIR /app
VOLUME [ "/data" ]
COPY --from=builder /build/dmedia .

ENV LOGFILE=1

CMD ["/app/dmedia"]