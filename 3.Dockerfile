FROM node:12-slim as prod
ENV NODE_ENV=production
ENV TINI_VERSION v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "--"]
EXPOSE 3000
RUN mkdir /app && chown -R node:node /app
WORKDIR /app
USER node
COPY --chown=node:node package.json package-lock*.json ./
RUN npm ci && npm cache clean --force
COPY --chown=node:node . .
CMD ["node", "./bin/www"]

FROM prod as dev
ENV NODE_ENV=development
ENV PATH=/app/node_modules/.bin:$PATH
RUN npm install --only=development
# NOTE CHANGE ENTRYPOINT?
CMD ["nodemon", "./bin/www", "--inspect=0.0.0.0:9229"]
