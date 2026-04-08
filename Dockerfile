# ---------------------------------------------
# Stage 1: Install dependencies
# ---------------------------------------------
FROM node:20-alpine AS deps
WORKDIR /app

# Configure npm for reliability
RUN npm config set registry https://registry.npmjs.org/ \
    && npm config set fetch-retries 5 \
    && npm config set fetch-retry-mintimeout 20000 \
    && npm config set fetch-retry-maxtimeout 120000

# Copy package files and install production dependencies
COPY package.json package-lock.json* ./
RUN npm ci --only=production --ignore-scripts && npm cache clean --force

# ---------------------------------------------
# Stage 2: Build the app
# ---------------------------------------------
FROM node:20-alpine AS builder
WORKDIR /app

# Copy node_modules from deps stage
COPY --from=deps /app/node_modules ./node_modules

# Copy the rest of the project
COPY . .

# Copy environment variables for build
# You can create .env.production with all your production variables
COPY .env.production .env.production

# Install dev dependencies for build
RUN npm ci --ignore-scripts

# Build Next.js app
RUN npm run build

# ---------------------------------------------
# Stage 3: Production image
# ---------------------------------------------
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

# Create a non-root user
RUN addgroup --system --gid 1001 nodejs \
    && adduser --system --uid 1001 nextjs

# Copy built app and necessary files
COPY --from=builder /app/next.config.mjs ./
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Optional: copy environment file (if you want secrets baked in)
# COPY --from=builder /app/.env.production .env.production

USER nextjs

EXPOSE 3000

CMD ["node", "server.js"]
