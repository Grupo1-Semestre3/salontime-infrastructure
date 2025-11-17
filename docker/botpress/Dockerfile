FROM botpress/server:latest

WORKDIR /botpress

# Clone bot configuration
ARG REPO_URL=https://github.com/Grupo1-Semestre3/salontime-bot-atendimento
ARG BRANCH=main

USER root
RUN apt-get update && apt-get install -y git && \
    git clone --depth 1 --branch ${BRANCH} ${REPO_URL} /tmp/bot && \
    cp -r /tmp/bot/* /botpress/ 2>/dev/null || true && \
    rm -rf /tmp/bot

EXPOSE 3000

CMD ["./bp"]
