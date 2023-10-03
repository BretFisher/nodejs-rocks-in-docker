###
## ubuntu base with nodejs coppied in from official image, for a more secure base
###
#cache our node version for installing later
#FROM node:20.7-slim as node
FROM node:18.18-slim as node
FROM ubuntu:lunar-20230816 as base

# replace npm in CMD with tini for better kernel signal handling
# You may also need development tools to build native npm addons:
# apt-get install gcc g++ make
RUN apt-get update \
    && apt-get -qq install -y --no-install-recommends \
    tini \
    && rm -rf /var/lib/apt/lists/*
ENTRYPOINT ["/usr/bin/tini", "--"]

# new way to get node, let's copy in the specific version we want from a docker image
# this avoids depdency package installs (python3) that the deb package requires
COPY --from=node /usr/local/include/ /usr/local/include/
COPY --from=node /usr/local/lib/ /usr/local/lib/
COPY --from=node /usr/local/bin/ /usr/local/bin/
RUN corepack disable && corepack enable

# create node user and group
RUN groupadd --gid 1001 node \
    && useradd --uid 1001 --gid node --shell /bin/bash --create-home node

# you'll likely need more stages for dev/test, but here's our basic prod layer with source code
FROM base as prod
EXPOSE 3000
USER node
WORKDIR /app
COPY --chown=node:node package*.json ./
RUN npm ci && npm cache clean --force
COPY --chown=node:node . .
CMD ["node", "./bin/www"]
