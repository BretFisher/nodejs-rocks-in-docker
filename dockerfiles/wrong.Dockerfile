# basic dockerfile 101 example, but wrong in many ways
# look at x.Dockerfile for improvements

FROM node:latest

EXPOSE 3000

WORKDIR /app

COPY package*.json ./

RUN npm install && npm cache clean --force

COPY . .

CMD ["npm", "start"]
