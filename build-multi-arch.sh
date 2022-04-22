#!/bin/bash

# if you haven't created a new custom builder instance, run this once:
docker buildx create --use

# now build and push an image for two architectures:
docker buildx build -f dockerfile/5.Dockerfile --target prod --name <account/repo>:latest --platform=linux/amd64,linux/arm64 .