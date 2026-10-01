#!/usr/bin/env bash
set -euo pipefail

kibana_url="${KIBANA_URL:-http://kibana.local:5601}"

put_data_view() {
  local data_view="$1"
  local pattern="$2"
  curl -fsS -X POST "${kibana_url}/api/data_views/data_view" \
    -H 'Content-Type: application/json' \
    -H 'kbn-xsrf: ansible-elastic-stack-training' \
    -d "{\"data_view\":{\"id\":\"${data_view}\",\"name\":\"${data_view}\",\"title\":\"${pattern}\",\"timeFieldName\":\"@timestamp\",\"allowNoIndex\":false},\"override\":true}" \
    >/dev/null
}

put_data_view search-parsed 'search-parsed*'
put_data_view search-unparsed 'search-unparsed*'
put_data_view search-zeek 'search-zeek*'
put_data_view search-suricata 'search-suricata*'

curl -fsS "${kibana_url}/api/data_views" \
  -H 'kbn-xsrf: ansible-elastic-stack-training'
