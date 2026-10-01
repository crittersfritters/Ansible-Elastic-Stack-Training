#!/usr/bin/env bash
set -euo pipefail

elasticsearch_url="${ELASTICSEARCH_URL:-http://elasticsearch.local:9200}"

put_template() {
  local template_name="$1"
  local index_pattern="$2"
  curl -fsS -X PUT "${elasticsearch_url}/_index_template/${template_name}" \
    -H 'Content-Type: application/json' -d @- <<JSON
{
  "index_patterns": ["${index_pattern}"],
  "priority": 100,
  "template": {
    "settings": {"number_of_shards": 1, "number_of_replicas": 0},
    "mappings": {
      "dynamic": true,
      "properties": {
        "@timestamp": {"type": "date"},
        "event": {"properties": {
          "action": {"type": "keyword"},
          "created": {"type": "date"},
          "original": {"type": "wildcard"},
          "sequence": {"type": "long"}
        }},
        "_parser": {"properties": {
          "id": {"type": "keyword"},
          "version": {"type": "keyword"}
        }},
        "source": {"properties": {
          "ip": {"type": "ip"}, "port": {"type": "integer"},
          "bytes": {"type": "long"}, "packets": {"type": "long"}
        }},
        "destination": {"properties": {
          "ip": {"type": "ip"}, "port": {"type": "integer"},
          "bytes": {"type": "long"}, "packets": {"type": "long"}
        }},
        "network": {"properties": {
          "application": {"type": "keyword"},
          "transport": {"type": "keyword"},
          "bytes": {"type": "long"},
          "packets": {"type": "long"}
        }},
        "rule": {"properties": {"name": {"type": "keyword"}}},
        "src_ip": {"type": "ip"}, "dest_ip": {"type": "ip"},
        "src_port": {"type": "integer"}, "dest_port": {"type": "integer"},
        "ts": {"type": "double"},
        "id": {"properties": {
          "orig_h": {"type": "ip"}, "orig_p": {"type": "integer"},
          "resp_h": {"type": "ip"}, "resp_p": {"type": "integer"}
        }}
      }
    }
  }
}
JSON
}

ensure_index_and_alias() {
  local backing_index="$1"
  local write_alias="$2"
  if ! curl -fsSI "${elasticsearch_url}/${backing_index}" >/dev/null; then
    curl -fsS -X PUT "${elasticsearch_url}/${backing_index}" >/dev/null
  fi

  # Updating a template does not change indices that already exist. Reapply
  # the additive core mapping so this manual checkpoint converges on reruns in
  # the same way as the later Ansible role.
  curl -fsS -X PUT "${elasticsearch_url}/${backing_index}/_mapping" \
    -H 'Content-Type: application/json' -d @- >/dev/null <<'JSON'
{
  "dynamic": true,
  "properties": {
    "@timestamp": {"type": "date"},
    "event": {"properties": {
      "action": {"type": "keyword"},
      "created": {"type": "date"},
      "original": {"type": "wildcard"},
      "sequence": {"type": "long"}
    }},
    "_parser": {"properties": {
      "id": {"type": "keyword"},
      "version": {"type": "keyword"}
    }},
    "source": {"properties": {
      "ip": {"type": "ip"}, "port": {"type": "integer"},
      "bytes": {"type": "long"}, "packets": {"type": "long"}
    }},
    "destination": {"properties": {
      "ip": {"type": "ip"}, "port": {"type": "integer"},
      "bytes": {"type": "long"}, "packets": {"type": "long"}
    }},
    "network": {"properties": {
      "application": {"type": "keyword"},
      "transport": {"type": "keyword"},
      "bytes": {"type": "long"},
      "packets": {"type": "long"}
    }},
    "rule": {"properties": {"name": {"type": "keyword"}}},
    "src_ip": {"type": "ip"}, "dest_ip": {"type": "ip"},
    "src_port": {"type": "integer"}, "dest_port": {"type": "integer"},
    "ts": {"type": "double"},
    "id": {"properties": {
      "orig_h": {"type": "ip"}, "orig_p": {"type": "integer"},
      "resp_h": {"type": "ip"}, "resp_p": {"type": "integer"}
    }}
  }
}
JSON

  if curl -fsS "${elasticsearch_url}/_alias/${write_alias}" >/dev/null 2>&1; then
    curl -fsS -X POST "${elasticsearch_url}/_aliases" \
      -H 'Content-Type: application/json' \
      -d "{\"actions\":[{\"remove\":{\"index\":\"*\",\"alias\":\"${write_alias}\"}},{\"add\":{\"index\":\"${backing_index}\",\"alias\":\"${write_alias}\",\"is_write_index\":true}}]}" \
      >/dev/null
  else
    curl -fsS -X POST "${elasticsearch_url}/_aliases" \
      -H 'Content-Type: application/json' \
      -d "{\"actions\":[{\"add\":{\"index\":\"${backing_index}\",\"alias\":\"${write_alias}\",\"is_write_index\":true}}]}" \
      >/dev/null
  fi
}

put_template training-lab-parsed 'search-parsed*'
put_template training-lab-unparsed 'search-unparsed*'
put_template training-lab-zeek 'search-zeek*'
put_template training-lab-suricata 'search-suricata*'

ensure_index_and_alias search-parsed active-grok-match
ensure_index_and_alias search-unparsed active-unparsed
ensure_index_and_alias search-zeek active-zeek
ensure_index_and_alias search-suricata active-suricata

curl -fsS "${elasticsearch_url}/_cat/aliases?v"
