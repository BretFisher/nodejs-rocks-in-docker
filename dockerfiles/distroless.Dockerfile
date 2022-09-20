###
## Distroless in Prod. Multi-stage dev/test/prod with distroless
###
FROM gcr.io/distroless/nodejs@sha256:794e26246770ff28d285d7f800ce1982883cf4105662845689efa33f04ec4340 as distroless
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

# switch to distroless for prod
# use version tags for always building with latest 
#    (more risky for stability, but likely more secure)
#    gcr.io/distroless/nodejs:16
# OR pin to the sha256 hash for stable, deterministic builds,
#    but less secure if you don't update it regularly
# NOTE: I like to set versions at the top of files, 
#    so I set the image used in line 1 above, so I can just use the alias here
FROM distroless as prod
COPY --from=source --chown=1000:1000 /app /app
COPY --from=base /usr/bin/tini /usr/bin/tini
USER 1000
EXPOSE 3000
ENV NODE_ENV=production
ENV PATH=/app/node_modules/.bin:$PATH
WORKDIR /app
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/nodejs/bin/node", "./bin/www"]
