# this file is wrong, but common in examples or 
# basic dockerfile 101 blogs
# look at other Dockerfiles and the README.md for improvements

# FIXME: don't use latest. Pin to a specific version, debian distro, and use slim
# FIXME: ProTip: pin to sha with @sha256:hash
FROM node:latest

EXPOSE 3000

# FIXME: Don't use root. Add USER node first, then (as of 2019) WORKDIR sets perms to match USER
# then set USER node or USER 1000
WORKDIR /app

# FIXME: Don't use COPY, use COPY --chown=node:node
# FIXME: Also include package-lock.json or yarn.lock: COPY package*.json yarn*.lock ./
COPY package.json .

# FIXME: Don't install dev dependencies in a image used in production
# use npm ci for images that run on servers
RUN npm install && npm cache clean --force

# FIXME: Use COPY --chown=node:node . .
COPY . .

# FIXME: Don't use npm, nodemon, pm2, forever, or any process manager on servers
# call node and your starting .js directly.
# Scale with docker/kubernetes, not process managers, which only add complexity
CMD ["npm", "start"]
