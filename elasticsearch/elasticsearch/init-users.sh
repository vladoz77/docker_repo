#!/bin/bash
set -e

echo "Waiting for Elasticsearch availability..."
until curl -s --cacert /usr/share/elasticsearch/config/certs/ca.crt https://es01:9200 | grep -q "missing authentication credentials"; do
    echo "Elasticsearch not ready, waiting..."
    sleep 10
done

echo "Elasticsearch is ready!"

# Проверка и установка пароля kibana_system
echo "Checking kibana_system password status..."
KIBANA_PASSWORD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://es01:9200/_security/user/kibana_system" \
    --cacert /usr/share/elasticsearch/config/certs/ca.crt \
    -u "elastic:${ELASTIC_PASSWORD}")

if [ "$KIBANA_PASSWORD_STATUS" -eq 200 ]; then
    echo "kibana_system password already set, skipping..."
else
    echo "Setting kibana_system password..."
    until curl -s -o /dev/null -w "%{http_code}" -X POST "https://es01:9200/_security/user/kibana_system/_password" \
        --cacert /usr/share/elasticsearch/config/certs/ca.crt \
        -u "elastic:${ELASTIC_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d "{\"password\":\"${KIBANA_PASSWORD}\"}" | grep -q "200"; do 
      echo "Failed to set kibana_system password, retrying..."
      sleep 10 
    done
    echo "kibana_system password set successfully!"
fi

# Проверка и создание пользователя vlad
echo "Checking if user kovalev.v exists..."
VLAD_USER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://es01:9200/_security/user/kovalev.v" \
    --cacert /usr/share/elasticsearch/config/certs/ca.crt \
    -u "elastic:${ELASTIC_PASSWORD}")

if [ "$VLAD_USER_STATUS" -eq 200 ]; then
    echo "User kovalev.v already exists, skipping..."
else
    echo "Creating user kovalev.v..."
    until curl -s -o /dev/null -w "%{http_code}" -X PUT "https://es01:9200/_security/user/kovalev.v" \
        --cacert /usr/share/elasticsearch/config/certs/ca.crt \
        -u "elastic:${ELASTIC_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d '{
          "password" : "password",
          "roles" : [ "superuser" ],
          "full_name" : "Kovalev Vlad",
          "email" : "vladoz77@yandex.ru",
          "metadata" : {
            "intelligence" : 7
          },
          "enabled": true
        }' | grep -q "200"; do
      echo "Failed to create user kovalev.v, retrying..."
      sleep 10
    done
    echo "User kovalev.v created successfully!"
fi

echo "All initialization completed!"