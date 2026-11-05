#!/bin/bash
# Erzeugt docs/screenshot.png: phpMyAdmin des gebauten Kits (dist/SQL-Labor) mit
# der Datenbank northwind, aufgenommen mit Playwright (Chromium) in Docker.
# Vorher ./build.sh. Keine Host-Ports, keine Bind-Mounts (wie tests/linux_test.sh).
set -euo pipefail
cd "$(dirname "$0")/.."

KIT=$PWD/dist/SQL-Labor
LAUF=bild-$$
DB=sqllabor-$LAUF-db
WEB=sqllabor-$LAUF-web
SHOT=sqllabor-$LAUF-shot
PLAYWRIGHT=mcr.microsoft.com/playwright/python:v1.64.1-noble

aufraeumen() { docker rm -f "$DB" "$WEB" "$SHOT" >/dev/null 2>&1 || true; }
trap aufraeumen EXIT

docker create --name "$DB" -e MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=1 \
	mariadb:12.3 --port=13306 --init-file=/sql/init.sql >/dev/null
docker cp "$KIT/app/sql" "$DB:/sql"
docker start "$DB" >/dev/null
for _ in $(seq 1 60); do
	docker exec "$DB" mariadb-admin -h127.0.0.1 -P13306 -usus -psus --silent ping >/dev/null 2>&1 && break
	sleep 1
done
docker exec -i "$DB" mariadb -h127.0.0.1 -P13306 -usus -psus --default-character-set=utf8mb4 < "$KIT/app/sql/northwind.sql"
docker exec -i "$DB" mariadb -h127.0.0.1 -P13306 -usus -psus < "$KIT/app/phpmyadmin/sql/create_tables.sql"

docker create --name "$WEB" --network "container:$DB" -e SQLLABOR_TMP=/tmp/pma php:8.5-cli \
	sh -c "mkdir -p /tmp/pma && docker-php-ext-install mysqli >/tmp/build.log 2>&1 && php -S 127.0.0.1:18080 -t /web /router.php" >/dev/null
docker cp "$KIT/app/phpmyadmin" "$WEB:/web"
docker cp "$KIT/app/router.php" "$WEB:/router.php"
docker start "$WEB" >/dev/null
for _ in $(seq 1 90); do
	docker logs "$WEB" 2>&1 | grep -q "Development Server" && break
	sleep 2
done

# Das Image bringt Browser und Python mit, das Python-Paket in passender Version nicht.
docker create --name "$SHOT" --network "container:$DB" --ipc=host "$PLAYWRIGHT" sh -c 'pip install -q --break-system-packages playwright==1.64.1 && python3 -c "$0"' '
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch()
    s = b.new_page(viewport={"width": 1280, "height": 830}, locale="de-DE")
    s.goto("http://127.0.0.1:18080/index.php?route=/database/structure&db=northwind", wait_until="networkidle")
    s.screenshot(path="/tmp/screenshot.png")
    b.close()
' >/dev/null
docker start -a "$SHOT"
mkdir -p docs
docker cp "$SHOT:/tmp/screenshot.png" docs/screenshot.png
echo "Fertig: docs/screenshot.png"
