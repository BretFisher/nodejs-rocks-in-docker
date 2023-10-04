# syntax=docker/dockerfile:1

###
## Example: The most basic, CORRECT, Dockerfile for Node.js
###

# alwyas use slim and the lastest debian distro offered
FROM node:20-bookworm-slim@sha256:8d26608b65edb3b0a0e1958a0a5a45209524c4df54bbe21a4ca53548bc97a3a5

EXPOSE 3000

# add user first, then set WORKDIR to set permissions
USER node

WORKDIR /app

# copy in with correct permissions. Using * prevents errors if file is missing
COPY --chown=node:node package*.json ./

# use ci to only install packages from lock files
RUN npm ci && npm cache clean --force

# copy files with correct permissions
COPY --chown=node:node . .

# change command to run node directly
CMD ["node", "./bin/www"]
