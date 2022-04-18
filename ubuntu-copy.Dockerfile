#cache our node version for installing later
FROM node:16.14.2-slim as node
FROM ubuntu:focal-20220404 as base

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

# new way to get node, let's copy in the specific version we want from a docker image
# this avoids depdency package installs (python3) that the deb package requires
COPY --from=node /usr/local/include/ /usr/local/include/
COPY --from=node /usr/local/lib/ /usr/local/lib/
COPY --from=node /usr/local/bin/ /usr/local/bin/
RUN corepack disable && corepack enable

# you'll likely need more stages for dev/test, but here's our basic prod layer with source code
FROM base as prod

EXPOSE 3000

WORKDIR /app

USER node

COPY --chown=node:node package*.json yarn*.lock ./

RUN npm ci --only=production && npm cache clean --force

COPY --chown=node:node . .

CMD ["node", "./bin/www"]
