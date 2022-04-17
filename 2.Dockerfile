FROM node:16-slim

# replace npm in CMD with tini for better kernel signal handling
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    tini \
    && rm -rf /var/lib/apt/lists/*
ENTRYPOINT ["/usr/bin/tini", "--"]

EXPOSE 3000

RUN mkdir /app && chown -R node:node /app

WORKDIR /app

USER node

COPY --chown=node:node package*.json yarn*.lock ./

RUN npm ci --only=production && npm cache clean --force

COPY --chown=node:node . .

CMD ["node", "./bin/www"]
