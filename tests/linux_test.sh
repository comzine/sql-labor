#!/bin/bash
# Prueft den gebauten Kit-Ordner dist/SQL-Labor unter Linux mit Docker:
# MariaDB mit init.sql (mysql_native_password) und den Serveroptionen aus
# START.bat (secure-file-priv, myisam-recover-options), Import von northwind und
# Konfigurationsspeicher, MySQL-Client 8.0/8.4 wie in MySQL Workbench,
# phpMyAdmin unter PHP 8.5 hinter router.php (Urheberzeile, SQL, Lizenzseite,
# fremder Host-Kopf = 403, keine PHP-Meldungen).
#
# Laeuft lokal und in der CI (GitHub Actions, auch mit Docker-Socket im Job-Container).
# Darum keine Bind-Mounts: deren Pfade kennt der Host-Docker im Runner nicht.
# Dateien kommen per docker cp in die Container, Skripte per stdin.
# Keine Host-Ports: Web- und Curl-Container teilen das Netz des DB-Containers.
# Die Windows-Skripte (*.bat) prueft das nicht, dafuer TEST.bat am Schul-PC.
set -euo pipefail
cd "$(dirname "$0")/.."

KIT=$PWD/dist/SQL-Labor
LAUF=${GITHUB_RUN_ID:-lokal-$$}
DB=sqllabor-test-db-$LAUF
WEB=sqllabor-test-web-$LAUF
AUSGABE=$(mktemp)
DATEIEN=$(mktemp -d)
chmod 777 "$DATEIEN"

aufraeumen() { docker rm -f "$DB" "$WEB" >/dev/null 2>&1 || true; rm -rf "$AUSGABE" "$DATEIEN"; }
trap aufraeumen EXIT

docker create --name "$DB" -e MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=1 \
	mariadb:12.3 --port=13306 --init-file=/sql/init.sql \
	--myisam-recover-options=BACKUP,FORCE --secure-file-priv=/tmp/sqllabor-dateien >/dev/null
docker cp "$KIT/app/sql" "$DB:/sql"
docker cp "$DATEIEN" "$DB:/tmp/sqllabor-dateien"
docker start "$DB" >/dev/null
for _ in $(seq 1 60); do
	docker exec "$DB" mariadb-admin -h127.0.0.1 -P13306 -usus -psus --silent ping >/dev/null 2>&1 && break
	sleep 1
done
sql() { docker exec -i "$DB" mariadb -h127.0.0.1 -P13306 -usus -psus "$@"; }
sql --default-character-set=utf8mb4 < "$KIT/app/sql/northwind.sql"
sql < "$KIT/app/phpmyadmin/sql/create_tables.sql"

kunden=$(sql -N -e "SELECT COUNT(*) FROM northwind.customers")
echo "northwind.customers: $kunden"
[[ $kunden == 91 ]]
plugins=$(sql -N -e "SELECT DISTINCT plugin FROM mysql.user WHERE user='sus'")
echo "Anmeldeverfahren sus: $plugins"
[[ $plugins == mysql_native_password ]]

# secure_file_priv: OUTFILE nur im Ordner dateien
sql -e "SELECT 'ok' INTO OUTFILE '/tmp/sqllabor-dateien/ok.txt'"
if sql -e "SELECT 'boese' INTO OUTFILE '/tmp/boese.txt'" 2>/dev/null; then
	echo "FEHLER: OUTFILE ausserhalb von secure_file_priv moeglich" >&2
	exit 1
fi
echo "secure_file_priv: OUTFILE nur in /tmp/sqllabor-dateien"

for v in 8.0 8.4; do
	ergebnis=$(docker run --rm --network "container:$DB" mysql:$v \
		mysql -h127.0.0.1 -P13306 -usus -psus -N -e "SELECT COUNT(*) FROM northwind.orders" 2>/dev/null)
	echo "MySQL-Client $v (Workbench-Bibliothek): $ergebnis Bestellungen"
	[[ $ergebnis == 830 ]]
done

docker create --name "$WEB" --network "container:$DB" -e SQLLABOR_TMP=/tmp/pma php:8.5-cli \
	sh -c "mkdir -p /tmp/pma && docker-php-ext-install mysqli >/tmp/build.log 2>&1 && php -d error_reporting=E_ALL -d display_errors=stderr -S 127.0.0.1:18080 -t /web /router.php" >/dev/null
docker cp "$KIT/app/phpmyadmin" "$WEB:/web"
docker cp "$KIT/app/router.php" "$WEB:/router.php"
docker start "$WEB" >/dev/null
for _ in $(seq 1 90); do
	docker logs "$WEB" 2>&1 | grep -q "Development Server" && break
	sleep 2
done

docker run --rm -i --network "container:$DB" curlimages/curl:latest sh -s < tests/phpmyadmin_test.sh \
	| tee "$AUSGABE"
grep -q "SQL-Labor von Tobias Weber" "$AUSGABE"
grep -q '"success":true' "$AUSGABE"
grep -q "Alfreds Futterkiste" "$AUSGABE"
grep -q "Fremder Host-Kopf: 403" "$AUSGABE"
grep -q "Eigener Host-Kopf: 200" "$AUSGABE"
if docker logs "$WEB" 2>&1 | grep -E -i "deprecated|warning|fatal" | grep -v -E "Accepted|Closing"; then
	echo "FEHLER: PHP-Meldungen von phpMyAdmin" >&2
	exit 1
fi
echo "OK: Linux-Test bestanden"
