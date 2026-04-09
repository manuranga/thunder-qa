# Multi-target: thunder | consent
ARG VERSION=0.32.0

# ---------------------------------------------------------------------------
FROM alpine:3.20 AS release
ARG VERSION
RUN apk add --no-cache curl unzip \
    && curl -fsSL \
       "https://github.com/asgardeo/thunder/releases/download/v${VERSION}/thunder-${VERSION}-linux-arm64.zip" \
       -o /tmp/thunder.zip \
    && unzip /tmp/thunder.zip -d /opt \
    && mv /opt/thunder-${VERSION}-linux-arm64 /opt/thunder \
    && rm /tmp/thunder.zip

# ---------------------------------------------------------------------------
FROM release AS patched

# Bind 0.0.0.0 so other containers can reach it
RUN sed -i 's/hostname: "localhost"/hostname: "0.0.0.0"/' /opt/thunder/repository/conf/deployment.yaml

# Browser-side JS → proxy port
RUN sed -i 's/port: 8090/port: 8091/' /opt/thunder/apps/console/config.js \
    && sed -i 's/port: 8090/port: 8091/' /opt/thunder/apps/gate/config.js

# public_url, JWT issuer, CORS, consent via proxy
RUN sed -i '/^\s*port: 8090/a\  public_url: "https://localhost:8091"' \
        /opt/thunder/repository/conf/deployment.yaml \
    && sed -i 's|issuer:.*|issuer: "https://localhost:8091"|' \
        /opt/thunder/repository/conf/deployment.yaml \
    && sed -i '/allowed_origins:/a\    - "https://localhost:8090"\n    - "https://localhost:8091"' \
        /opt/thunder/repository/conf/deployment.yaml \
    && sed -i 's|base_url:.*|base_url: "https://net-dump:9091/api/v1"|' \
        /opt/thunder/repository/conf/deployment.yaml

# Regenerate server cert with SANs for both localhost and net-dump
RUN apk add --no-cache openssl \
    && openssl req -x509 -newkey rsa:2048 -days 365 -nodes \
       -keyout /opt/thunder/repository/resources/security/server.key \
       -out /opt/thunder/repository/resources/security/server.cert \
       -subj '/O=WSO2/OU=Thunder/CN=localhost' \
       -addext 'subjectAltName=DNS:localhost,DNS:net-dump' 2>/dev/null

# Switch all three DBs from sqlite to postgres (path = DSN string)
RUN sed -i 's/type: "sqlite"/type: "postgres"/g' /opt/thunder/repository/conf/deployment.yaml \
    && sed -i 's|path: "repository/database/.*\.db"|hostname: "postgres"\n    port: 5432\n    username: "thunder"\n    password: "thunder"\n    name: "thunderdb"\n    sslmode: "disable"|g' /opt/thunder/repository/conf/deployment.yaml \
    && sed -i '/options:.*journal_mode\|options:.*WAL\|options:.*busy_timeout\|options:.*foreign_keys/d' /opt/thunder/repository/conf/deployment.yaml

# ---------------------------------------------------------------------------
FROM alpine:3.20 AS thunder
RUN apk add --no-cache bash curl postgresql-client ca-certificates \
    && rm -f /usr/bin/lsof
COPY --from=patched /opt/thunder /opt/thunder
# Trust the regenerated self-signed cert (covers localhost + net-dump)
RUN cp /opt/thunder/repository/resources/security/server.cert \
      /usr/local/share/ca-certificates/thunder.crt \
    && update-ca-certificates
WORKDIR /opt/thunder
EXPOSE 8090
HEALTHCHECK --interval=5s --timeout=3s --retries=10 \
    CMD curl -ks https://localhost:8090/health/readiness || exit 1

# ---------------------------------------------------------------------------
FROM ghcr.io/manuranga/net-dump:latest AS net-dump
COPY --from=patched /opt/thunder/repository/resources/security/server.key /app/certs/
COPY --from=patched /opt/thunder/repository/resources/security/server.cert /app/certs/

# ---------------------------------------------------------------------------
FROM alpine:3.20 AS consent
RUN apk add --no-cache bash curl postgresql-client
COPY --from=release /opt/thunder/consent /opt/consent
RUN sed -i 's/hostname: localhost/hostname: 0.0.0.0/' /opt/consent/repository/conf/deployment.yaml \
    && sed -i 's/type: sqlite/type: postgres/' /opt/consent/repository/conf/deployment.yaml \
    && sed -i 's|path:.*consentdb.*|hostname: postgres\n    port: 5432\n    user: thunder\n    password: thunder\n    database: consentdb\n    sslmode: disable|' /opt/consent/repository/conf/deployment.yaml \
    && sed -i '/options:.*pragma/d' /opt/consent/repository/conf/deployment.yaml
WORKDIR /opt/consent
EXPOSE 9090
HEALTHCHECK --interval=5s --timeout=3s --retries=10 \
    CMD curl -sf http://localhost:9090/health/readiness || exit 1
