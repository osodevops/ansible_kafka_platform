#!/usr/bin/env bash
# verify-airgap-bundle.sh
# ========================
# Validates the integrity and completeness of an air-gap bundle.
# Run this after transferring the bundle to the air-gapped network.
#
# Usage:
#   ./scripts/verify-airgap-bundle.sh --bundle-dir /opt/oso-kafka-airgap-bundle-20260324

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { echo -e "\033[36m[INFO]\033[0m  $*"; }
ok()    { echo -e "\033[32m[PASS]\033[0m  $*"; }
warn()  { echo -e "\033[33m[WARN]\033[0m  $*"; }
fail_msg() { echo -e "\033[31m[FAIL]\033[0m  $*"; }

ERRORS=0
WARNINGS=0

check_file() {
  local path="$1" description="$2"
  if [[ -f "$path" ]]; then
    ok "$description"
  else
    fail_msg "$description — file not found: $path"
    ((ERRORS++))
  fi
}

check_dir_not_empty() {
  local path="$1" description="$2"
  if [[ -d "$path" ]] && [[ -n "$(ls -A "$path" 2>/dev/null)" ]]; then
    ok "$description ($(ls -1 "$path" | wc -l) files)"
  elif [[ -d "$path" ]]; then
    warn "$description — directory exists but is empty"
    ((WARNINGS++))
  else
    fail_msg "$description — directory not found: $path"
    ((ERRORS++))
  fi
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
BUNDLE_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle-dir)
      BUNDLE_DIR="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 --bundle-dir <path>"
      echo ""
      echo "Validates an air-gap bundle for completeness and integrity."
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 --bundle-dir <path>" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$BUNDLE_DIR" ]]; then
  # Try to auto-detect
  BUNDLE_DIR=$(ls -d ./oso-kafka-airgap-bundle-* 2>/dev/null | head -1 || true)
  if [[ -z "$BUNDLE_DIR" ]]; then
    echo "Usage: $0 --bundle-dir <path>" >&2
    exit 1
  fi
  info "Auto-detected bundle directory: $BUNDLE_DIR"
fi

if [[ ! -d "$BUNDLE_DIR" ]]; then
  echo "Error: Bundle directory not found: $BUNDLE_DIR" >&2
  exit 1
fi

echo ""
echo "============================================="
echo "  Air-Gap Bundle Verification"
echo "============================================="
echo ""
echo "  Bundle: $BUNDLE_DIR"
echo ""

# ---------------------------------------------------------------------------
# 1. Check directory structure
# ---------------------------------------------------------------------------
info "Checking directory structure..."
for dir in ansible kafka jmx prometheus grafana kafka-ui pip; do
  check_dir_not_empty "${BUNDLE_DIR}/${dir}" "Directory: ${dir}/"
done

# os-packages is optional
if [[ -d "${BUNDLE_DIR}/os-packages" ]] && [[ -n "$(ls -A "${BUNDLE_DIR}/os-packages" 2>/dev/null)" ]]; then
  ok "Directory: os-packages/ ($(ls -1 "${BUNDLE_DIR}/os-packages" | wc -l) files)"
else
  warn "Directory: os-packages/ — empty or missing (OS packages must be provided separately)"
  ((WARNINGS++))
fi

# ---------------------------------------------------------------------------
# 2. Check expected files exist
# ---------------------------------------------------------------------------
echo ""
info "Checking expected artifacts..."

# Kafka binary
KAFKA_FILES=$(find "${BUNDLE_DIR}/kafka" -name "kafka_*.tgz" 2>/dev/null | head -1)
if [[ -n "$KAFKA_FILES" ]]; then
  ok "Kafka binary: $(basename "$KAFKA_FILES")"
else
  fail_msg "Kafka binary: no kafka_*.tgz found in kafka/"
  ((ERRORS++))
fi

# JMX exporter
JMX_FILES=$(find "${BUNDLE_DIR}/jmx" -name "jmx_prometheus_javaagent-*.jar" 2>/dev/null | head -1)
if [[ -n "$JMX_FILES" ]]; then
  ok "JMX Exporter: $(basename "$JMX_FILES")"
else
  fail_msg "JMX Exporter: no jmx_prometheus_javaagent-*.jar found in jmx/"
  ((ERRORS++))
fi

# Prometheus
PROM_FILES=$(find "${BUNDLE_DIR}/prometheus" -name "prometheus-*.tar.gz" 2>/dev/null | head -1)
if [[ -n "$PROM_FILES" ]]; then
  ok "Prometheus: $(basename "$PROM_FILES")"
else
  fail_msg "Prometheus: no prometheus-*.tar.gz found in prometheus/"
  ((ERRORS++))
fi

# Grafana
GRAFANA_FILES=$(find "${BUNDLE_DIR}/grafana" -name "grafana-*.tar.gz" 2>/dev/null | head -1)
if [[ -n "$GRAFANA_FILES" ]]; then
  ok "Grafana: $(basename "$GRAFANA_FILES")"
else
  fail_msg "Grafana: no grafana-*.tar.gz found in grafana/"
  ((ERRORS++))
fi

# Kafbat UI
UI_FILES=$(find "${BUNDLE_DIR}/kafka-ui" -name "*.jar" 2>/dev/null | head -1)
if [[ -n "$UI_FILES" ]]; then
  ok "Kafbat UI: $(basename "$UI_FILES")"
else
  fail_msg "Kafbat UI: no *.jar found in kafka-ui/"
  ((ERRORS++))
fi

# Ansible collection
COLLECTION_FILES=$(find "${BUNDLE_DIR}/ansible" -name "*.tar.gz" 2>/dev/null | head -1)
if [[ -n "$COLLECTION_FILES" ]]; then
  ok "Ansible collection: $(basename "$COLLECTION_FILES")"
else
  fail_msg "Ansible collection: no *.tar.gz found in ansible/"
  ((ERRORS++))
fi

# ---------------------------------------------------------------------------
# 3. Verify checksums
# ---------------------------------------------------------------------------
echo ""
info "Verifying SHA-256 checksums..."

CHECKSUM_FILE="${BUNDLE_DIR}/checksums.sha256"
if [[ -f "$CHECKSUM_FILE" ]]; then
  CHECKSUM_ERRORS=0
  cd "${BUNDLE_DIR}"
  while IFS= read -r line; do
    expected_hash=$(echo "$line" | awk '{print $1}')
    filepath=$(echo "$line" | awk '{print $2}')
    if [[ -f "$filepath" ]]; then
      actual_hash=$(sha256sum "$filepath" | awk '{print $1}')
      if [[ "$expected_hash" == "$actual_hash" ]]; then
        ok "Checksum: $(basename "$filepath")"
      else
        fail_msg "Checksum mismatch: $(basename "$filepath")"
        fail_msg "  Expected: $expected_hash"
        fail_msg "  Actual:   $actual_hash"
        ((CHECKSUM_ERRORS++))
        ((ERRORS++))
      fi
    else
      fail_msg "Checksum file references missing file: $filepath"
      ((CHECKSUM_ERRORS++))
      ((ERRORS++))
    fi
  done < checksums.sha256
  cd - > /dev/null

  if [[ $CHECKSUM_ERRORS -eq 0 ]]; then
    ok "All checksums verified"
  fi
else
  fail_msg "checksums.sha256 not found — cannot verify integrity"
  ((ERRORS++))
fi

# ---------------------------------------------------------------------------
# 4. Check manifest
# ---------------------------------------------------------------------------
echo ""
check_file "${BUNDLE_DIR}/MANIFEST.md" "Manifest: MANIFEST.md"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================="
echo "  Verification Summary"
echo "============================================="
echo ""

if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
  ok "All checks passed. Bundle is ready for deployment."
  exit 0
elif [[ $ERRORS -eq 0 ]]; then
  warn "$WARNINGS warning(s), 0 errors. Bundle is usable but review warnings above."
  exit 0
else
  fail_msg "$ERRORS error(s), $WARNINGS warning(s). Bundle has issues — review output above."
  exit 1
fi
