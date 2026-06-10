# Multi-target: thunder | consent
ARG VERSION=0.43.0

# ---------------------------------------------------------------------------
FROM alpine:3.20 AS release
ARG VERSION
RUN apk add --no-cache curl unzip \
    && curl -fsSL \
       "https://github.com/thunder-id/thunderid/releases/download/v${VERSION}/thunderid-${VERSION}-linux-arm64.zip" \
       -o /tmp/thunder.zip \
    && unzip /tmp/thunder.zip -d /opt \
    && mv /opt/thunderid-${VERSION}-linux-arm64 /opt/thunder \
    && rm /tmp/thunder.zip

# ---------------------------------------------------------------------------
FROM release AS patched

# Write full deployment.yaml: bind 0.0.0.0, postgres DBs, proxy URLs, CORS
RUN cat > /opt/thunder/repository/conf/deployment.yaml <<'EOF'
server:
  hostname: "0.0.0.0"
  port: 8090
  public_url: "https://localhost:8091"

tls:
  min_version: "1.3"
  cert_file: "repository/resources/security/server.cert"
  key_file: "repository/resources/security/server.key"

database:
  config:
    type: "postgres"
    postgres:
      hostname: "postgres"
      port: 5432
      username: "thunder"
      password: "thunder"
      name: "thunderdb"
      sslmode: "disable"
  runtime:
    type: "postgres"
    postgres:
      hostname: "postgres"
      port: 5432
      username: "thunder"
      password: "thunder"
      name: "thunderdb"
      sslmode: "disable"
  user:
    type: "postgres"
    postgres:
      hostname: "postgres"
      port: 5432
      username: "thunder"
      password: "thunder"
      name: "thunderdb"
      sslmode: "disable"

crypto:
  encryption:
    key: "file://repository/resources/security/crypto.key"
  password_hashing:
    algorithm: "PBKDF2"
  keys:
    - id: "default-key"
      cert_file: "repository/resources/security/signing.cert"
      key_file: "repository/resources/security/signing.key"

jwt:
  preferred_key_id: "default-key"
  issuer: "https://localhost:8091"

cors:
  allowed_origins:
    - "https://localhost:8090"
    - "https://localhost:8091"

passkey:
  allowed_origins:
    - "https://localhost:8090"

consent:
  enabled: true
  base_url: "https://net-dump:9091/api/v1"
EOF

# Browser-side JS → proxy port
RUN sed -i 's/port: 8090/port: 8091/' /opt/thunder/apps/console/config.js \
    && sed -i 's/port: 8090/port: 8091/' /opt/thunder/apps/gate/config.js

# Regenerate server cert with SANs for both localhost and net-dump
RUN apk add --no-cache openssl \
    && openssl req -x509 -newkey rsa:2048 -days 365 -nodes \
       -keyout /opt/thunder/repository/resources/security/server.key \
       -out /opt/thunder/repository/resources/security/server.cert \
       -subj '/O=WSO2/OU=ThunderID/CN=localhost' \
       -addext 'subjectAltName=DNS:localhost,DNS:net-dump' 2>/dev/null

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
