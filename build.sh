#!/bin/bash
# Baut dist/SQL-Labor-<VERSION>.zip.
# Laedt MariaDB, PHP und phpMyAdmin nach cache/ (mit SHA-256-Pruefung), kuerzt
# sie auf das Noetige und legt die eigenen Dateien aus kit/ dazu.
# Aufruf: ./build.sh            Kit bauen (Version aus der Datei VERSION)
#         ./build.sh --quellen  zusaetzlich die Quellarchive von MariaDB und
#                               phpMyAdmin nach dist/quellen/ (GPLv2 §3, fuer Releases)
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")"

KIT_VERSION=$(tr -d '[:space:]' < VERSION)
QUELLEN=0
[[ ${1:-} == --quellen ]] && QUELLEN=1

MARIADB_VERSION=12.3.3
MARIADB_SHA256=4b5706b47148b47c8f36963c8352d1ddee37a1287b4690428f631a74b09b85a0
PHP_VERSION=8.5.12-1
PHP_SHA256=2a36a2edcb7a5b9252f638fd5e4cf84d7f6e066092654220dc0b63e5cf4e9723
PMA_VERSION=5.2.3
PMA_SHA256=2d2e13c735366d318425c78e4ee2cc8fc648d77faba3ddea2cd516e43885733f
# Quellarchive passend zu den Binaerpaketen (Pruefsummen vom Hersteller)
MARIADB_SRC_SHA256=e99d739fd4a55f9a11dea7bd2287a262673e287550af3071c8469dd2bec0c163
PMA_SRC_SHA256=df1e7a4363db80af7916f4c6b7ceb25457baf50b3647c05b48ef59199be075e0

MARIADB_ZIP=mariadb-$MARIADB_VERSION-winx64.zip
PHP_ZIP=php-$PHP_VERSION-nts-Win32-vs17-x64.zip
PMA_ZIP=phpMyAdmin-$PMA_VERSION-all-languages.zip
MARIADB_SRC=mariadb-$MARIADB_VERSION.tar.gz
PMA_SRC=phpMyAdmin-$PMA_VERSION-source.tar.xz

CACHE=cache
OUT=dist/SQL-Labor
ZIP=dist/SQL-Labor-$KIT_VERSION.zip

# laden URL... ZIEL SHA256: erste erreichbare URL laden, Pruefsumme pruefen
laden() {
	local ziel=${*: -2:1} sha=${*: -1} url
	if [[ -f $ziel ]] && echo "$sha  $ziel" | sha256sum -c --status; then
		return 0
	fi
	for url in "${@:1:$#-2}"; do
		echo "Lade $url"
		if curl -fsSL -A "Mozilla/5.0 (sql-labor build)" -o "$ziel.tmp" "$url"; then
			mv "$ziel.tmp" "$ziel"
			echo "$sha  $ziel" | sha256sum -c --quiet
			return 0
		fi
	done
	echo "FEHLER: $ziel nicht ladbar" >&2
	return 1
}

mkdir -p "$CACHE"
laden "https://downloads.mariadb.org/rest-api/mariadb/$MARIADB_VERSION/$MARIADB_ZIP" \
	"$CACHE/$MARIADB_ZIP" "$MARIADB_SHA256"
# Aeltere PHP-Builds wandern bei windows.php.net nach archives/
laden "https://downloads.php.net/~windows/releases/$PHP_ZIP" \
	"https://downloads.php.net/~windows/releases/archives/$PHP_ZIP" \
	"$CACHE/$PHP_ZIP" "$PHP_SHA256"
laden "https://files.phpmyadmin.net/phpMyAdmin/$PMA_VERSION/$PMA_ZIP" \
	"$CACHE/$PMA_ZIP" "$PMA_SHA256"

echo "Entpacke nach $CACHE/"
rm -rf "$CACHE/mariadb" "$CACHE/php" "$CACHE/pma"
unzip -q "$CACHE/$MARIADB_ZIP" -d "$CACHE/mariadb"
unzip -q "$CACHE/$PHP_ZIP" -d "$CACHE/php"
unzip -q "$CACHE/$PMA_ZIP" -d "$CACHE/pma"
M=$CACHE/mariadb/mariadb-$MARIADB_VERSION-winx64
P=$CACHE/php
PMA=$CACHE/pma/phpMyAdmin-$PMA_VERSION-all-languages

echo "Baue $OUT"
rm -rf "$OUT"
mkdir -p "$OUT/app/mariadb/bin" "$OUT/app/mariadb/lib" "$OUT/app/php/ext" "$OUT/app/lizenzen"

# MariaDB: Server, Client und Werkzeuge des Kits. mysqld.exe ist eine Kopie von
# mariadbd.exe; mariadb-install-db ruft fuer den Bootstrap fest bin\mysqld.exe auf.
cp "$M"/bin/{mariadbd.exe,mysqld.exe,server.dll,mariadb.exe,mariadb-admin.exe,mariadb-install-db.exe,mariadb-dump.exe} \
	"$OUT/app/mariadb/bin/"
cp "$M"/bin/*.dll "$OUT/app/mariadb/bin/"
cp -r "$M/share" "$OUT/app/mariadb/"
# Plugins: nur die Anmelde-Plugins des Clients. Keine Server-Plugins (CONNECT,
# Spider, Federated u. a. koennen Dateien und Netz erreichen; der Unterricht
# braucht sie nicht, InnoDB/MyISAM/Aria sind eingebaut).
mkdir -p "$OUT/app/mariadb/lib/plugin"
cp "$M"/lib/plugin/{caching_sha2_password.dll,client_ed25519.dll,dialog.dll,mysql_clear_password.dll,parsec.dll,sha256_password.dll} \
	"$OUT/app/mariadb/lib/plugin/"

# PHP: nur der eingebaute Webserver mit mysqli, pdo_mysql, mbstring und fileinfo.
# Die Visual-C++-Laufzeit kommt aus dem MariaDB-Paket (keine Installation noetig).
cp "$P"/{php.exe,php8.dll} "$OUT/app/php/"
cp "$P"/ext/{php_mysqli.dll,php_pdo_mysql.dll,php_mbstring.dll,php_fileinfo.dll} "$OUT/app/php/ext/"
cp "$M"/bin/{vcruntime140.dll,vcruntime140_1.dll,msvcp140.dll} "$OUT/app/php/"

# phpMyAdmin: nur Deutsch (Englisch ist eingebaut), ohne Setup-Assistent und Beispiele.
mkdir -p "$OUT/app/phpmyadmin"
cp -r "$PMA/." "$OUT/app/phpmyadmin/"
find "$OUT/app/phpmyadmin/locale" -mindepth 1 -maxdepth 1 -type d ! -name de -exec rm -rf {} +
rm -rf "$OUT/app/phpmyadmin/setup" "$OUT/app/phpmyadmin/examples" "$OUT/app/phpmyadmin/config.sample.inc.php"

# Eigene Dateien (darunter config.inc.php, config.footer.inc.php, lizenz.html fuer phpMyAdmin)
cp -r kit/. "$OUT/"

# Lizenzen
cp LICENSE "$OUT/app/lizenzen/SQL-Labor-LICENSE.txt"
cp "$M/COPYING" "$OUT/app/lizenzen/MariaDB-COPYING.txt"
cp "$M/THIRDPARTY" "$OUT/app/lizenzen/MariaDB-THIRDPARTY.txt"
cp "$P/license.txt" "$OUT/app/lizenzen/PHP-LICENSE.txt"
cp "$PMA/LICENSE" "$OUT/app/lizenzen/phpMyAdmin-LICENSE.txt"

# Platzhalter fuellen
for f in "$OUT"/*.txt "$OUT"/*.bat "$OUT"/app/*.bat "$OUT/app/phpmyadmin/lizenz.html"; do
	sed -i -e "s/@KIT_VERSION@/$KIT_VERSION/g" -e "s/@MARIADB_VERSION@/$MARIADB_VERSION/g" \
		-e "s/@PHP_VERSION@/${PHP_VERSION%-*}/g" -e "s/@PMA_VERSION@/$PMA_VERSION/g" \
		-e "s/@PMA_VERSION_TAG@/${PMA_VERSION//./_}/g" "$f"
done
if grep -rl '@[A-Z_]*VERSION[A-Z_]*@' "$OUT" --include='*.txt' --include='*.bat' --include='*.html'; then
	echo "FEHLER: Platzhalter nicht ersetzt" >&2
	exit 1
fi

# Windows-Zeilenenden fuer Skripte und Texte
for f in "$OUT"/*.bat "$OUT"/*.txt "$OUT"/app/*.bat "$OUT/app/php/php.ini" "$OUT/app/sql/init.sql"; do
	sed -i 's/\r$//; s/$/\r/' "$f"
done
if grep -n -P '[^\x00-\x7F]' "$OUT"/*.bat "$OUT"/app/*.bat; then
	echo "FEHLER: Batch-Dateien muessen reines ASCII sein (Codepage)" >&2
	exit 1
fi

rm -f "$ZIP"
(cd dist && zip -q -r -9 -X "SQL-Labor-$KIT_VERSION.zip" SQL-Labor)
echo "Fertig: $ZIP ($(du -h "$ZIP" | cut -f1))"

if (( QUELLEN )); then
	laden "https://downloads.mariadb.org/rest-api/mariadb/$MARIADB_VERSION/$MARIADB_SRC" \
		"$CACHE/$MARIADB_SRC" "$MARIADB_SRC_SHA256"
	laden "https://files.phpmyadmin.net/phpMyAdmin/$PMA_VERSION/$PMA_SRC" \
		"$CACHE/$PMA_SRC" "$PMA_SRC_SHA256"
	rm -rf dist/quellen
	mkdir -p dist/quellen
	cp "$CACHE/$MARIADB_SRC" "$CACHE/$PMA_SRC" dist/quellen/
	echo "Quellen: dist/quellen/ ($(du -sh dist/quellen | cut -f1))"
fi
