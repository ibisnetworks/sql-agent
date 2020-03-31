# Base build image
FROM golang:1.12-alpine AS build_base

# Install some dependencies needed to build the project
RUN apk update && apk add git
WORKDIR /go/src/github.com/ibisnetworks/sql-agent

# Force the go compiler to use modules
ENV GO111MODULE=on

# We want to populate the module cache based on the go.{mod,sum} files.
COPY go.mod .
COPY go.sum .

# This is the ‘magic’ step that will download all the dependencies that are
# specified in the go.mod and go.sum file.
# Because of how the layer caching system works in Docker, the  go mod download
# command will _ only_ be re-run when the go.mod or go.sum file change
# (or when we add another docker instruction this line)
RUN go mod download

# Here we copy the rest of the source code
COPY . .

# And compile the project
ENV CGO_ENABLED=0
ENV GOOS=linux
RUN go build -o sql-agent ./cmd/sql-agent

# # In this last stage, we start from an image, to reduce the image size and not
# # ship the Go compiler in our production artifacts.
# # FROM scratch
FROM alpine

# Finally we copy the statically compiled Go binary.
COPY --from=build_base /go/src/github.com/ibisnetworks/sql-agent/sql-agent /usr/bin/sql-agent

CMD ["sql-agent", "-host", "0.0.0.0"] 
