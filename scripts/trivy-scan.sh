#!/bin/bash
IMAGE=$1
SEVERITY=${2:-"HIGH,CRITICAL"}
OUTPUT_FILE=${3:-"trivy-report.json"}

echo "=== Trivy Security Scan ==="
echo "Image: $IMAGE"
echo "Severity: $SEVERITY"

trivy image \
  --severity $SEVERITY \
  --format json \
  --output $OUTPUT_FILE \
  $IMAGE

trivy image \
  --severity $SEVERITY \
  --format table \
  $IMAGE

CRITICAL=$(cat $OUTPUT_FILE | python3 -c \
  "import sys,json; r=json.load(sys.stdin); \
  vulns=[v for res in r.get('Results',[]) \
  for v in res.get('Vulnerabilities',[]) \
  if v.get('Severity')=='CRITICAL']; print(len(vulns))")

echo ""
echo "CRITICAL vulnerabilities found: $CRITICAL"

if [ "$CRITICAL" -gt "0" ]; then
  echo "SECURITY SCAN FAILED: Critical vulnerabilities detected!"
  exit 1
fi

echo "Trivy scan PASSED — no CRITICAL vulnerabilities!"
exit 0
