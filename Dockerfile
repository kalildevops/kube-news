FROM node:22-alpine3.21

WORKDIR /app

COPY src/package.json src/package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY src/ .

RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup && \
    chown -R appuser:appgroup /app
USER appuser

ENV NODE_ENV=production

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD wget -qO- http://localhost:8080/health || exit 1

CMD ["node", "server.js"]
