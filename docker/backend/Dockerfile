FROM gradle:7-jdk17 AS builder

WORKDIR /app

# Clone repository
ARG REPO_URL=https://github.com/Grupo1-Semestre3/salontime-app-kotlin
ARG BRANCH=main
RUN apt-get update && apt-get install -y git && \
    git clone --depth 1 --branch ${BRANCH} ${REPO_URL} .

# Copy application properties
COPY application.properties src/main/resources/application.properties

# Build
RUN gradle clean build -x test

# Production stage
FROM openjdk:17-slim

WORKDIR /app

COPY --from=builder /app/build/libs/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
