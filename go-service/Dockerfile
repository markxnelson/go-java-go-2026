FROM golang:1.26.3 AS build
WORKDIR /src
COPY go.mod ./
COPY cmd ./cmd
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/go-service ./cmd/server

FROM scratch
COPY --from=build /out/go-service /go-service
EXPOSE 8080
ENTRYPOINT ["/go-service"]

