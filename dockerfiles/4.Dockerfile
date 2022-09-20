###
## Adding test stage, and avoiding source in dev
###
FROM node:16-bullseye-slim as base
ENV NODE_ENV=production
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    tini \
    && rm -rf /var/lib/apt/lists/*
EXPOSE 3000
RUN mkdir /app && chown -R node:node /app
WORKDIR /app
USER node
COPY --chown=node:node package*.json yarn*.lock ./
RUN npm ci --only=production && npm cache clean --force

# dev stage (no source added, assumes bind mount)
FROM base as dev
ENV NODE_ENV=development
ENV PATH=/app/node_modules/.bin:$PATH
RUN npm install && npm cache clean --force
CMD ["nodemon", "./bin/www", "--inspect=0.0.0.0:9229"]

# copy in source code for test and prod stages
# we do this in its own stage to ensure the
# layers we test are the exact hashed layers the cache
# uses to build prod stage
FROM base as source
COPY --chown=node:node . .

# test stage: combine source code and dev stage deps
FROM source as test
ENV NODE_ENV=development
ENV PATH=/app/node_modules/.bin:$PATH
COPY --from=dev /app/node_modules /app/node_modules
RUN npx eslint .
RUN npm test
CMD ["npm", "run", "test"]

### prod stage
FROM source as prod
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "./bin/www"]
