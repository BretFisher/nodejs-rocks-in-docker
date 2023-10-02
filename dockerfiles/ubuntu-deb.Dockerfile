###
## ubuntu base with nodejs deb package, for a more secure base
###
FROM ubuntu:jammy-20230816 as base

# version of Node.js we will install later
ENV NODE_MAJOR=20

# replace npm in CMD with tini for better kernel signal handling
RUN apt-get update \
    && apt-get -qq install -y --no-install-recommends \
    tini \
    && rm -rf /var/lib/apt/lists/*

# You may also need development tools to build native npm addons:
# apt-get install gcc g++ make

ENTRYPOINT ["/usr/bin/tini", "--"]

# create node user and group, then create app dir
RUN groupadd --gid 1000 node \
    && useradd --uid 1000 --gid node --shell /bin/bash --create-home node \
    && mkdir /app \
    && chown -R node:node /app

# get full list of packages at https://deb.nodesource.com/node_18.x/pool/main/n/nodejs/
# this basic TARGETARCH design only works on amd64 and arm64 builds.
# for more on multi-platform builds, see https://github.com/BretFisher/multi-platform-docker-build
ARG TARGETARCH
RUN apt-get -qq update \
  && apt-get -qq install -y ca-certificates curl gnupg \
  && mkdir -p /etc/apt/keyrings \
  && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
  && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
  && apt-get update \
  && apt-get -qq install -y nodejs --no-install-recommends \
  && apt-get -qq remove curl \
  && apt-get -qq autoremove -y \
  && rm -rf /var/lib/apt/lists/* \
  && which npm

# you'll likely need more stages for dev/test, but here's our basic prod layer with source code
FROM base as prod
EXPOSE 3000
WORKDIR /app
USER node
COPY --chown=node:node package*.json yarn*.lock ./
RUN npm ci --only=production && npm cache clean --force
COPY --chown=node:node . .
CMD ["node", "./bin/www"]
