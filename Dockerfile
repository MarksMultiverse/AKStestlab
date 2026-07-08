# --- Build stage ---
FROM node:20-alpine AS build
WORKDIR /app
COPY app/package.json ./
RUN npm install --omit=dev
COPY app/ ./

# --- Runtime stage ---
FROM node:20-alpine
WORKDIR /app
# Draai als non-root user (security best practice)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=build /app ./
USER appuser

EXPOSE 3000
CMD ["node", "index.js"]
