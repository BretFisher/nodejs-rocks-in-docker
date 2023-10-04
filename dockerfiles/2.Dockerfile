# syntax=docker/dockerfile:1

###
## Example: run tini first, as PID 1
###

FROM node:20-bookworm-slim@sha256:8d26608b65edb3b0a0e1958a0a5a45209524c4df54bbe21a4ca53548bc97a3a5

# replace npm in CMD with tini for better kernel signal handling
ENV NODE_ENV=production
ENV TINI_VERSION=v0.19.0
ADD --chmod=755 https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/local/bin/tini

# set entrypoint to always run commands with tini
ENTRYPOINT ["/usr/local/bin/tini", "--"]

EXPOSE 3000

USER node

WORKDIR /app

COPY --chown=node:node package*.json ./

RUN npm ci && npm cache clean --force

COPY --chown=node:node . .

CMD ["node", "./bin/www"]
