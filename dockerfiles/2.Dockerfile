FROM node:16-bullseye-slim
###
## Example: run tini first, as PID 1
###

# replace npm in CMD with tini for better kernel signal handling
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    tini \
    && rm -rf /var/lib/apt/lists/*
# set entrypoint to always run commands with tini
ENTRYPOINT ["/usr/bin/tini", "--"]

EXPOSE 3000

RUN mkdir /app && chown -R node:node /app

WORKDIR /app

USER node

COPY --chown=node:node package*.json yarn*.lock ./

RUN npm ci --only=production && npm cache clean --force

COPY --chown=node:node . .

# change command to run node directly
CMD ["node", "./bin/www"]
