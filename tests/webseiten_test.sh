#!/bin/sh
# Ruft den Webserver fuer die eigenen Seiten der SuS (Port 18000) im Netz-Namespace
# des DB-Containers auf: Startseite der Vorlage mit DB-Check, PDO-Beispiel (auch mit
# SQL-Injection-Versuch), statische Seite, Dateiliste, sichtbare PHP-Fehler, Host-Pruefung.
b=http://127.0.0.1:18000

echo "== Startseite:"
curl -s "$b/" | grep -o -E "northwind hat [0-9]+ Kunden|nicht erreichbar[^<]{0,80}" | head -1

echo "== PDO-Beispiel:"
curl -s "$b/northwind_kunden.php?land=Germany" | grep -o -E "[0-9]+ Kunden in Germany|Alfreds Futterkiste" | sort -u

echo "== SQL-Injection-Versuch:"
curl -s -G "$b/northwind_kunden.php" --data-urlencode "land=Germany' OR '1'='1" | grep -o -E "[0-9]+ Kunden in" | head -1

echo "== Statische Seite: $(curl -s -o /dev/null -w "%{http_code}" "$b/hallo.html")"

echo "== Dateiliste:"
echo "Ohne Schraegstrich: $(curl -s -o /dev/null -w "%{http_code} %{redirect_url}" "$b/projekt")"
curl -s "$b/projekt/" | grep -o -E "Inhalt von /projekt/|aufgabe1\.php" | sort -u

echo "== PHP-Fehler sichtbar:"
curl -s "$b/fehler.php" | grep -o -E "Undefined variable \\\$nicht_definiert" | head -1

echo "== Host-Pruefung:"
echo "Fremder Host-Kopf Webseiten: $(curl -s -o /dev/null -w "%{http_code}" -H "Host: fremd.example:18000" "$b/")"
