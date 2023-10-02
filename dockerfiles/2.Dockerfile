###
## Example: run tini first, as PID 1
###

FROM node:20-bookworm-slim@sha256:8d26608b65edb3b0a0e1958a0a5a45209524c4df54bbe21a4ca53548bc97a3a5

# replace npm in CMD with tini for better kernel signal handling
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    tini \
    && rm -rf /var/lib/apt/lists/*
# set entrypoint to always run commands with tini
ENTRYPOINT ["/usr/bin/tini", "--"]

EXPOSE 3000

USER node

WORKDIR /app

COPY --chown=node:node package*.json ./

RUN npm ci && npm cache clean --force

COPY --chown=node:node . .

CMD ["node", "./bin/www"]
