### Run docker-compose

```bash
docker compose up -d --build
```

### For get unseel key and root token we need run and save then

```bash
docker exec -it vault vault operator init
```

### Run ui in web browser

```bash
http://localhost:8200
```

### Create a policy
In UI go 