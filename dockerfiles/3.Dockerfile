###
## Adding stages for dev and prod
###
FROM node:20-bookworm-slim@sha256:8d26608b65edb3b0a0e1958a0a5a45209524c4df54bbe21a4ca53548bc97a3a5
ENV NODE_ENV=production
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    tini \
    && rm -rf /var/lib/apt/lists/*
EXPOSE 3000
USER node
WORKDIR /app
COPY --chown=node:node package*.json ./
RUN npm ci && npm cache clean --force
COPY --chown=node:node . .
CMD ["node", "./bin/www"]

# dev stage
FROM base as dev
ENV NODE_ENV=development
ENV PATH=/app/node_modules/.bin:$PATH
RUN npm install
CMD ["nodemon", "./bin/www", "--inspect=0.0.0.0:9229"]

# prod stage
FROM base as prod
ENTRYPOINT ["/usr/bin/tini", "--"]
# CMD is technically not needed here, but I like it for clarity
CMD ["node", "./bin/www"]
