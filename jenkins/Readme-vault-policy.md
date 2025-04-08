## Настройка jenkins approle и policies в vault

1. Настройка политики для роли `jenkins` в vault. Секреты хранятся по пути `/kv`

```bash
vault policy write jenkins -<<EOF
# Read-only permission on secrets stored at 'kv/data/*'
path "kv/data/*" {
  capabilities = [ "read" ]
}
EOF
```

2. Создадим approle `jenkins-role` и привяжем политику jenkins

```bash
vault write auth/approle/role/jenkins \
    token_ttl=1h \
    token_max_ttl=4h \
    token_policies=jenkins
```

3. Чтобы получить `role-id` выполните следующую команду

```bash
vault read auth/approle/role/jenkins/role-id
```

4. Чтобы получить `secret-id` выполните:

```bash
vault write -f auth/approle/role/jenkins/secret-id
```