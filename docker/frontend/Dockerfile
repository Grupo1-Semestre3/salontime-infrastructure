FROM node:18-alpine AS builder

WORKDIR /app

# Clone repository
ARG REPO_URL=https://github.com/Grupo1-Semestre3/salontime-front-end-react
ARG BRANCH=main
RUN apk add --no-cache git && \
    git clone --depth 1 --branch ${BRANCH} ${REPO_URL} .

# Install dependencies and build
RUN npm ci && \
    npm run build

# Production stage
FROM nginx:alpine

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
