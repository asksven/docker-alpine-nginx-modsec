#!/bin/sh

echo "Substituting template"
envsubst < /etc/clamav/clamd.conf.template > /etc/clamav/clamd.conf

cat /etc/clamav/clamd.conf
#freshclam || true
#mkdir -p "${MODSEC_AUDIT_STORAGE}" \
#         "${MODSEC_DATA_DIR}" \
#         "${MODSEC_TMP_DIR}" \
#         "${MODSEC_UPLOAD_DIR}"

echo "Starting nginx"
exec /docker-entrypoint.sh "$@"