# syntax=docker/dockerfile:1

###
## Adding stages for dev and prod
###

FROM node:20-bookworm-slim@sha256:8d26608b65edb3b0a0e1958a0a5a45209524c4df54bbe21a4ca53548bc97a3a5 as base
ENV NODE_ENV=production
ENV TINI_VERSION=v0.19.0
ADD --chmod=755 https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/local/bin/tini
EXPOSE 3000
USER node
WORKDIR /app
COPY --chown=node:node package*.json ./
RUN npm ci && npm cache clean --force
ENV PATH=/app/node_modules/.bin:$PATH

# dev stage
FROM base as dev
ENV NODE_ENV=development
RUN npm install
COPY --chown=node:node . .
CMD ["nodemon", "./bin/www", "--inspect=0.0.0.0:9229"]

# prod stage
FROM base as prod
COPY --chown=node:node . .
ENTRYPOINT ["/usr/local/bin/tini", "--"]
CMD ["node", "./bin/www"]
