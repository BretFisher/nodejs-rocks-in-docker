FROM node:16-slim as base
ENV NODE_ENV=production
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
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

###
### run audit and scan commands
###
FROM test as audit
RUN 
RUN npm audit 
# --audit-level critical
ENV TRIVY_VERSION=0.26.0
# Use BuildKit to help translate architecture names
ARG TARGETPLATFORM
USER root
RUN case ${TARGETPLATFORM} in \
         "linux/amd64")  ARCH=64bit  ;; \
         "linux/arm64")  ARCH=ARM64  ;; \
         "linux/arm/v7") ARCH=ARM    ;; \
    esac \
    && curl -o trivy.deb -SL https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${ARCH}.deb \
    && dpkg -i trivy.deb
RUN trivy fs --severity "HIGH,CRITICAL" --ignore-unfixed --no-progress --security-checks vuln .

FROM source as prod
ENTRYPOINT ["/tini", "--"]
CMD ["node", "./bin/www"]
