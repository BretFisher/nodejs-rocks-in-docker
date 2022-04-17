FROM node:16 as base
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

FROM base as dev
ENV NODE_ENV=development
ENV PATH=/app/node_modules/.bin:$PATH
RUN npm install && npm cache clean --force
CMD ["nodemon", "./bin/www", "--inspect=0.0.0.0:9229"]

FROM base as source
COPY --chown=node:node . .

FROM source as test
ENV NODE_ENV=development
ENV PATH=/app/node_modules/.bin:$PATH
COPY --from=dev /app/node_modules /app/node_modules
RUN npx eslint .
RUN npm test
CMD ["npm", "run", "test"]

FROM gcr.io/distroless/nodejs:16 as prod
COPY --from=source --chown=1000:1000 /app /app
COPY --from=base /usr/bin/tini /usr/bin/tini
USER 1000
EXPOSE 3000
ENV NODE_ENV=production
WORKDIR /app
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/nodejs/bin/node", "./bin/www"]
