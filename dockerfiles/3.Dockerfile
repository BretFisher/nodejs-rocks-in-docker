###
### prod build
###
FROM node:16-slim as base
ENV NODE_ENV=production
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    tini \
    && rm -rf /var/lib/apt/lists/*
RUN chmod +x /tini
EXPOSE 3000
RUN mkdir /app && chown -R node:node /app
WORKDIR /app
USER node
COPY --chown=node:node package*.json yarn*.lock ./
RUN npm ci --only=production && npm cache clean --force
COPY --chown=node:node . .
CMD ["node", "./bin/www"]

###
### layer dev dependencies on top for dev or testing
###
FROM base as dev
ENV NODE_ENV=development
ENV PATH=/app/node_modules/.bin:$PATH
RUN npm install --only=development
CMD ["nodemon", "./bin/www", "--inspect=0.0.0.0:9229"]

###
### prod stage
###
FROM base as prod
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "./bin/www"]