### Запускаем docker-compose

```bash
docker compose up -d --build
```

### Получаем unsel токены и рут токет

```bash
docker exec -it vault vault operator init
```

### Добавляем в переменную адрес vault

```bash
export VAULT_ADDR='http://0.0.0.0:8200'
```

### Распечатываем хранилище

Вводим 3 ключа для распечатования хранилища
```bash
vault operator unseal Q/Hy8/SuI+ZJQDNpuq/vgSjuyADFOKEzXpYgVWgYxLKB
vault operator unseal H7T4/AL6ixNekerVYYCN2I2J/5T4j0J3nneWCGBYRSpM
vault operator unseal Q/Hy8/SuI+ZJQDNpuq/vgSjuyADFOKEzXpYgVWgYxLKB
```

### Логинимся в vault

Логинимся с помощью рут токена который получили ранее
```bash
vault login
```

### Включаем kv хранилище

```bash
vault secrets enable --path /kv kv-v2
```

### Создаем секреты для настройки терраформ провайдера

```bash
vault kv put -mount=kv yc-sa-admin \                                                       
folder_id=$(yc config get folder-id) \
cloud_id=$(yc config get folder-id) \
iam_token=$(yc iam create-token)
```

### Включаем аутентификацию APPROLE

```bash
vault auth enable approle
```

### Создаем политику для terraform

- Создаем файл политики terraform.hcl

    ```hcl
    path "*" {
    capabilities = ["list", "read"]
    }

    path "kv/data/*" {
    capabilities = ["create", "read", "update", "delete", "list"]
    }


    path "auth/token/create" {
    capabilities = ["create", "read", "update", "list"]
    }
    ```

- Применяем политику:

    ```bash
    vault policy write terraform terraform.hcl
    ```

### Создаем роль terraform

```bash
vault write auth/approle/role/terraform \
    secret_id_ttl=10m \
    token_num_uses=10 \
    token_ttl=20m \
    token_max_ttl=30m \
    secret_id_num_uses=40 \
    token_policies=terraform
```

### Узнаем id-role

```bash
vault read auth/approle/role/terraform/role-id
```

### Узнаем secret

```bash
vault write -f auth/approle/role/terraform/secret-id
```

### Настраиваем провайдер в terraform

```hcl
provider "vault" {
  address = "http://127.0.0.1:8200"
  skip_child_token = true
  auth_login {
    path = "auth/approle/login"

    parameters = {
      role_id = "fac78a2a-ed15-7dd1-8a23-dcab95b63db8"
      secret_id = "ef95f477-3351-8f47-0c14-e4e5bd47c9e6"
    }
  }
}

// Настройка vault
data "vault_kv_secret_v2" "yc_creds" {
  mount = "kv" // change it according to your mount
  name  = "yc" // change it according to your secret
}

provider "yandex" {
  token = data.vault_kv_secret_v2.yc_creds.data["iam_token"]
  cloud_id  = data.vault_kv_secret_v2.yc_creds.data["cloud_id"]
  folder_id = data.vault_kv_secret_v2.yc_creds.data["folder_id"]
  zone      = "ru-central1-a"
}
```
