FROM node:12-slim as base
ENV NODE=ENV=production
ENV TINI_VERSION v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
EXPOSE 3000
RUN mkdir /app && chown -R node:node /app
WORKDIR /app
USER node
COPY --chown=node:node package.json package-lock*.json ./
RUN npm ci && npm cache clean --force

FROM base as dev
ENV NODE_ENV=development
ENV PATH=/app/node_modules/.bin:$PATH
RUN npm install --only=development
CMD ["nodemon", "./bin/www", "--inspect=0.0.0.0:9229"]

FROM base as source
COPY --chown=node:node . .

FROM source as test
ENV NODE_ENV=development
ENV PATH=/app/node_modules/.bin:$PATH
COPY --from=dev /app/node_modules /app/node_modules
RUN eslint .
RUN npm test
CMD ["npm", "run", "test"]

FROM source as prod
ENTRYPOINT ["/tini", "--"]
CMD ["node", "./bin/www"]
