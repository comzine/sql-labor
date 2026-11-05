#!/bin/sh
# Ruft phpMyAdmin im Netz-Namespace des DB-Containers auf:
# Startseite mit Urheberzeile, northwind, SQL per AJAX, Lizenzseite,
# Host-Pruefung von router.php (DNS-Rebinding).
b=http://127.0.0.1:18080
j=/tmp/jar
echo "== Startseite:"
curl -s -c $j -b $j -o /tmp/i.html -w "%{http_code}\n" "$b/index.php?route=/"
grep -o -E "SQL-Labor von Tobias Weber|northwind|Konfigurationsspeicher[^<]{0,60}|phpMyAdmin-Konfigurationsspeicher[^<]{0,60}|errors? (has|have) been detected|Fehler[^<]{0,60}" /tmp/i.html | sort | uniq -c | head
token=$(grep -o -E '"token":"[0-9a-f]+"|name="token" value="[0-9a-f]+"' /tmp/i.html | head -1 | grep -o -E '[0-9a-f]{20,}')
echo "token=$token"
echo "== Datenbank northwind:"
curl -s -c $j -b $j -o /tmp/d.html -w "%{http_code}\n" "$b/index.php?route=/database/structure&db=northwind"
grep -o -E "orderdetails|customers|suppliers" /tmp/d.html | sort | uniq -c
echo "== SQL:"
curl -s -c $j -b $j -o /tmp/s.html -w "%{http_code}\n" "$b/index.php?route=/import" \
	--data-urlencode "db=northwind" --data-urlencode "token=$token" --data-urlencode "is_js_confirmed=0" \
	--data-urlencode "sql_query=SELECT CompanyName FROM customers WHERE Country='Germany' ORDER BY 1 LIMIT 3" \
	--data-urlencode "ajax_request=true"
grep -o -E "Alfreds Futterkiste|Blauer See Delikatessen|\"success\":(true|false)|#[0-9]{4} - [^\"<]{0,80}" /tmp/s.html | head -5
echo "== Lizenzseite:"
curl -s -o /dev/null -w "%{http_code}\n" "$b/lizenz.html"
echo "== Host-Pruefung:"
echo "Fremder Host-Kopf: $(curl -s -o /dev/null -w "%{http_code}" -H "Host: fremd.example:18080" "$b/index.php?route=/")"
echo "Eigener Host-Kopf: $(curl -s -o /dev/null -w "%{http_code}" -H "Host: localhost:18080" "$b/lizenz.html")"
