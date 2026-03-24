#!/usr/bin/env bash
# download-airgap-bundle.sh
# ==========================
# Downloads all artifacts needed to deploy osodevops.kafka_platform
# in an air-gapped environment. Run this on an internet-connected machine,
# then transfer the resulting bundle to the air-gapped network.
#
# Usage:
#   ./scripts/download-airgap-bundle.sh
#
# Override versions via environment variables:
#   KAFKA_VERSION=4.1.1 GRAFANA_VERSION=11.5.2 ./scripts/download-airgap-bundle.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Version defaults — override with environment variables
# ---------------------------------------------------------------------------
KAFKA_VERSION="${KAFKA_VERSION:-4.0.0}"
SCALA_VERSION="${SCALA_VERSION:-2.13}"
JMX_EXPORTER_VERSION="${JMX_EXPORTER_VERSION:-1.1.0}"
PROMETHEUS_VERSION="${PROMETHEUS_VERSION:-3.2.1}"
GRAFANA_VERSION="${GRAFANA_VERSION:-11.5.2}"
KAFBAT_UI_VERSION="${KAFBAT_UI_VERSION:-1.4.2}"
PLATFORM_ARCH="${PLATFORM_ARCH:-linux-amd64}"
COLLECTION_VERSION="${COLLECTION_VERSION:-latest}"

BUNDLE_DIR="${BUNDLE_DIR:-./oso-kafka-airgap-bundle-$(date +%Y%m%d)}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { echo -e "\033[36m[INFO]\033[0m  $*"; }
ok()    { echo -e "\033[32m[OK]\033[0m    $*"; }
warn()  { echo -e "\033[33m[WARN]\033[0m  $*"; }
fail()  { echo -e "\033[31m[FAIL]\033[0m  $*" >&2; exit 1; }

check_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command '$1' not found. Please install it."
}

download() {
  local url="$1" dest="$2"
  if [[ -f "$dest" ]]; then
    info "Already downloaded: $(basename "$dest")"
    return 0
  fi
  info "Downloading: $url"
  curl -fSL --progress-bar -o "$dest" "$url"
  ok "$(basename "$dest")"
}

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
check_command curl
check_command tar
check_command sha256sum

if command -v ansible-galaxy >/dev/null 2>&1; then
  HAS_GALAXY=true
else
  HAS_GALAXY=false
  warn "ansible-galaxy not found — skipping collection download. Install manually."
fi

if command -v pip >/dev/null 2>&1 || command -v pip3 >/dev/null 2>&1; then
  PIP_CMD="$(command -v pip3 || command -v pip)"
  HAS_PIP=true
else
  HAS_PIP=false
  warn "pip not found — skipping Python package download. Install manually."
fi

# ---------------------------------------------------------------------------
# Create bundle directory structure
# ---------------------------------------------------------------------------
info "Creating bundle directory: ${BUNDLE_DIR}"
mkdir -p "${BUNDLE_DIR}"/{ansible,kafka,jmx,prometheus,grafana,kafka-ui,pip,os-packages}

echo ""
echo "============================================="
echo "  OSO Kafka Platform Air-Gap Bundle Builder"
echo "============================================="
echo ""
echo "  Kafka:        ${KAFKA_VERSION}"
echo "  Scala:        ${SCALA_VERSION}"
echo "  JMX Exporter: ${JMX_EXPORTER_VERSION}"
echo "  Prometheus:   ${PROMETHEUS_VERSION}"
echo "  Grafana:      ${GRAFANA_VERSION}"
echo "  Kafbat UI:    ${KAFBAT_UI_VERSION}"
echo "  Architecture: ${PLATFORM_ARCH}"
echo "  Bundle:       ${BUNDLE_DIR}"
echo ""

# ---------------------------------------------------------------------------
# 1. Ansible collection
# ---------------------------------------------------------------------------
info "[1/7] Downloading Ansible collection..."
if [[ "$HAS_GALAXY" == "true" ]]; then
  ansible-galaxy collection download osodevops.kafka_platform \
    -p "${BUNDLE_DIR}/ansible/" 2>/dev/null || \
    warn "Collection download failed — you may need to download manually or build from source."
  # Also download dependency collections
  for dep in ansible.posix community.general community.crypto; do
    ansible-galaxy collection download "$dep" \
      -p "${BUNDLE_DIR}/ansible/" 2>/dev/null || \
      warn "Failed to download dependency: $dep"
  done
else
  warn "Skipping collection download (ansible-galaxy not available)"
fi

# ---------------------------------------------------------------------------
# 2. Apache Kafka binary
# ---------------------------------------------------------------------------
info "[2/7] Downloading Apache Kafka ${KAFKA_VERSION}..."
KAFKA_FILENAME="kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"
download \
  "https://downloads.apache.org/kafka/${KAFKA_VERSION}/${KAFKA_FILENAME}" \
  "${BUNDLE_DIR}/kafka/${KAFKA_FILENAME}"

download \
  "https://downloads.apache.org/kafka/${KAFKA_VERSION}/${KAFKA_FILENAME}.sha512" \
  "${BUNDLE_DIR}/kafka/${KAFKA_FILENAME}.sha512" || \
  warn "SHA512 checksum not available for Kafka ${KAFKA_VERSION}"

# ---------------------------------------------------------------------------
# 3. JMX Prometheus JavaAgent
# ---------------------------------------------------------------------------
info "[3/7] Downloading JMX Exporter ${JMX_EXPORTER_VERSION}..."
JMX_JAR="jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar"
download \
  "https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_EXPORTER_VERSION}/${JMX_JAR}" \
  "${BUNDLE_DIR}/jmx/${JMX_JAR}"

# ---------------------------------------------------------------------------
# 4. Prometheus
# ---------------------------------------------------------------------------
info "[4/7] Downloading Prometheus ${PROMETHEUS_VERSION}..."
PROM_FILENAME="prometheus-${PROMETHEUS_VERSION}.${PLATFORM_ARCH}.tar.gz"
download \
  "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/${PROM_FILENAME}" \
  "${BUNDLE_DIR}/prometheus/${PROM_FILENAME}"

download \
  "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/sha256sums.txt" \
  "${BUNDLE_DIR}/prometheus/sha256sums.txt" || \
  warn "SHA256 checksums not available for Prometheus ${PROMETHEUS_VERSION}"

# ---------------------------------------------------------------------------
# 5. Grafana
# ---------------------------------------------------------------------------
info "[5/7] Downloading Grafana ${GRAFANA_VERSION}..."
GRAFANA_FILENAME="grafana-${GRAFANA_VERSION}.${PLATFORM_ARCH}.tar.gz"
download \
  "https://dl.grafana.com/oss/release/${GRAFANA_FILENAME}" \
  "${BUNDLE_DIR}/grafana/${GRAFANA_FILENAME}"

# ---------------------------------------------------------------------------
# 6. Kafbat UI
# ---------------------------------------------------------------------------
info "[6/7] Downloading Kafbat UI ${KAFBAT_UI_VERSION}..."
KAFBAT_JAR="api-v${KAFBAT_UI_VERSION}.jar"
download \
  "https://github.com/kafbat/kafka-ui/releases/download/v${KAFBAT_UI_VERSION}/${KAFBAT_JAR}" \
  "${BUNDLE_DIR}/kafka-ui/${KAFBAT_JAR}"

# ---------------------------------------------------------------------------
# 7. Python pip packages
# ---------------------------------------------------------------------------
info "[7/7] Downloading Python pip packages..."
if [[ "$HAS_PIP" == "true" ]]; then
  "$PIP_CMD" download cryptography -d "${BUNDLE_DIR}/pip/" --quiet || \
    warn "Failed to download cryptography pip package"
  "$PIP_CMD" download ansible-core -d "${BUNDLE_DIR}/pip/" --quiet || \
    warn "Failed to download ansible-core pip package"
else
  warn "Skipping pip package download (pip not available)"
fi

# ---------------------------------------------------------------------------
# Generate checksums
# ---------------------------------------------------------------------------
info "Generating SHA-256 checksums..."
cd "${BUNDLE_DIR}"
find . -type f \( -name "*.tgz" -o -name "*.tar.gz" -o -name "*.jar" \
  -o -name "*.deb" -o -name "*.rpm" -o -name "*.whl" \) \
  -exec sha256sum {} \; > checksums.sha256
ok "Checksums written to checksums.sha256"

# ---------------------------------------------------------------------------
# Generate manifest
# ---------------------------------------------------------------------------
cat > MANIFEST.md << 'MANIFEST_EOF'
# OSO Kafka Platform Air-Gap Bundle

## Contents

| Directory | Contents |
|-----------|----------|
| `ansible/` | osodevops.kafka_platform collection tarball + dependencies |
| `kafka/` | Apache Kafka binary tarball |
| `jmx/` | JMX Prometheus JavaAgent JAR |
| `prometheus/` | Prometheus server binary |
| `grafana/` | Grafana OSS tarball |
| `kafka-ui/` | Kafbat UI JAR |
| `pip/` | Python pip wheels (cryptography, ansible-core) |
| `os-packages/` | OS-level packages (user-provided) |
| `checksums.sha256` | SHA-256 checksums for integrity verification |

## Usage

1. Transfer this bundle to the air-gapped network
2. Run `scripts/verify-airgap-bundle.sh` to validate integrity
3. Run `scripts/setup-airgap-repo.sh` to serve files via HTTP
4. Configure inventory with air-gap variable overrides
5. Deploy with `ansible-playbook site.yml`

See docs/AIRGAP.md for the full guide.
MANIFEST_EOF

cd - > /dev/null

# ---------------------------------------------------------------------------
# Create archive
# ---------------------------------------------------------------------------
info "Creating bundle archive..."
tar czf "${BUNDLE_DIR}.tar.gz" -C "$(dirname "${BUNDLE_DIR}")" "$(basename "${BUNDLE_DIR}")"
ok "Archive created: ${BUNDLE_DIR}.tar.gz"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================="
echo "  Bundle Complete"
echo "============================================="
echo ""
echo "  Archive: ${BUNDLE_DIR}.tar.gz"
echo "  Size:    $(du -sh "${BUNDLE_DIR}.tar.gz" | cut -f1)"
echo ""
echo "  Next steps:"
echo "  1. Transfer ${BUNDLE_DIR}.tar.gz to the air-gapped network"
echo "  2. Extract: tar xzf $(basename "${BUNDLE_DIR}").tar.gz"
echo "  3. Verify:  scripts/verify-airgap-bundle.sh --bundle-dir $(basename "${BUNDLE_DIR}")"
echo "  4. Serve:   scripts/setup-airgap-repo.sh --bundle-dir $(basename "${BUNDLE_DIR}")"
echo ""
echo "  NOTE: OS packages (Java 21, chrony, xfsprogs, etc.) must be"
echo "  downloaded separately for your target OS. Place them in the"
echo "  os-packages/ directory before creating the archive."
echo ""
echo "  For RHEL/Rocky:"
echo "    yum install --downloadonly --downloaddir=${BUNDLE_DIR}/os-packages/ \\"
echo "      java-21-openjdk-headless chrony xfsprogs acl curl tar"
echo ""
echo "  For Ubuntu/Debian:"
echo "    apt-get install --download-only -y \\"
echo "      openjdk-21-jdk-headless chrony xfsprogs acl curl tar"
echo "    cp /var/cache/apt/archives/*.deb ${BUNDLE_DIR}/os-packages/"
echo ""
