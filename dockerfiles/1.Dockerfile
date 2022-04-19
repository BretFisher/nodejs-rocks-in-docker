# alwyas use slim
FROM node:16-slim

EXPOSE 3000

# change permissions to non-root user
RUN mkdir /app && chown -R node:node /app

WORKDIR /app

USER node

# copy in for npm and yarn. Using * prevents errors if file is missing
COPY --chown=node:node package*.json yarn*.lock ./

# use ci to only install packages from lock files
RUN npm ci --only=production && npm cache clean --force

# copy files with correct permissions
COPY --chown=node:node . .

CMD ["npm", "start"]
