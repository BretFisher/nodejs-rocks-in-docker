# this file is wrong, but common in examples or 
# basic dockerfile 101 blogs
# look at other Dockerfiles and the README.md for improvements

# FIXME: don't use latest. Pin to a specific version, and use slim
FROM node:latest

EXPOSE 3000

# FIXME: Don't use root. You'll need to manually create dir and set perms
# then set USER node or USER 1000
WORKDIR /app

COPY package*.json ./

# FIXME: Don't install dev dependencies in a image used in production
# use npm ci --only=production for images that run on servers
RUN npm install && npm cache clean --force

COPY . .

# FIXME: Don't use npm, nodemon, pm2, forever, or any process manager on servers
# call node and your starting .js directly.
# Scale with docker/kubernetes, not process managers, which only add complexity
CMD ["npm", "start"]
