# Local installation

```
docker-compose build
docker-compose up -d
docker-compose exec app php bin/console doctrine:migrations:migrate
```

# Usage

```
http://localhost:8080/api
```