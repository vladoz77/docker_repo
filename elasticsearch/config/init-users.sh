#!/bin/bash

set -e

echo "Waiting for Elasticsearch availability..."
until curl -s --cacert /usr/share/elasticsearch/config/certs/ca.crt https://es01:9200 | grep -q "missing authentication credentials"; do
    echo "Elasticsearch not ready, waiting..."
    sleep 10
done

echo "Elasticsearch is ready! Setting kibana_system password..."

until curl -s -o /dev/null -w "%{http_code}" -X POST "https://es01:9200/_security/user/kibana_system/_password" \
    --cacert /usr/share/elasticsearch/config/certs/ca.crt \
    -u "elastic:${ELASTIC_PASSWORD}" \
    -H "Content-Type: application/json" \
    -d "{\"password\":\"${KIBANA_PASSWORD}\"}" | grep -q "200"; do 
  echo "Failed to set kibana_system password, retrying..."
  sleep 10 
done

echo "kibana_system password set successfully!"

echo "Creating user vlad..."

until curl -s -o /dev/null -w "%{http_code}" -X PUT "https://es01:9200/_security/user/vlad" \
    --cacert /usr/share/elasticsearch/config/certs/ca.crt \
    -u "elastic:${ELASTIC_PASSWORD}" \
    -H "Content-Type: application/json" \
    -d '{
      "password" : "password",
      "roles" : [ "editor" ],
      "full_name" : "Kovalev Vlad",
      "email" : "vladoz77@yandex.ru",
      "metadata" : {
        "intelligence" : 7
      },
      "enabled": true
    }' | grep -q "200"; do
  echo "Failed to create user vlad, retrying..."
  sleep 10
done

echo "User vlad created successfully!"
echo "All initialization completed!"