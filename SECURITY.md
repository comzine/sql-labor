# Sicherheit

## Sicherheitslücke melden

Bitte **nicht** als öffentliches Issue. Nutze auf GitHub
„Security → Report a vulnerability“ (private Meldung an den Maintainer).
Antwort in der Regel innerhalb einer Woche.

## Was das SQL-Labor schützt und was nicht

Das Kit ist für einen einzelnen Schul-PC gedacht, auf dem eine Schülerin oder
ein Schüler mit eigenem Windows-Konto arbeitet.

- **Nur lokal:** MariaDB (Port 13306), der PHP-Webserver mit phpMyAdmin
  (Port 18080) und der Webserver für eigene Seiten (Port 18000) lauschen
  ausschließlich auf `127.0.0.1`. Andere Rechner im Netz erreichen nichts.
- **Kein Passwortschutz nach innen:** phpMyAdmin meldet sich automatisch an,
  der Datenbankbenutzer `sus` (Passwort `sus`) hat alle Rechte, auch
  `CREATE USER` und `GRANT`, weil der Unterricht das braucht. Wer am selben PC
  angemeldet ist, kann die Datenbank benutzen. Das ist gewollt.
- **Schutz vor fremden Webseiten:** `app/router.php` nimmt auf beiden
  Webservern nur Anfragen an, die den Server als `127.0.0.1` oder `localhost`
  ansprechen. Eine Webseite, deren
  Name per DNS-Rebinding auf `127.0.0.1` zeigt, bekommt 403. Anfragen anderer
  Seiten an `127.0.0.1` scheitern an den CSRF-Tokens von phpMyAdmin und an der
  Same-Origin-Policy des Browsers.
- **Eigene Seiten:** Der Webserver auf Port 18000 führt PHP aus dem Webordner
  der Schülerin oder des Schülers aus und zeigt Fehlermeldungen im Browser an
  (zum Lernen gewollt). Er läuft mit den Rechten des angemeldeten Windows-Kontos,
  wie jedes Programm, das man selbst startet. Selbst geschriebene Formulare
  haben in der Regel keine CSRF-Tokens: Eine fremde Webseite könnte sie blind
  absenden (lesen kann sie die Antwort nicht). Betroffen sind nur die eigenen
  Übungsdaten; aktuelle Browser blockieren solche Anfragen öffentlicher Seiten
  an `127.0.0.1` zunehmend (Private Network Access).
- **Dateizugriffe per SQL** (`LOAD DATA INFILE`, `SELECT … INTO OUTFILE`) sind
  per `secure_file_priv` auf den Ordner `dateien` im Datenordner beschränkt.
- **Keine Server-Plugins:** Das Kit liefert nur die Anmelde-Plugins des
  Clients mit, nicht CONNECT, Spider, Federated und Co., die Dateien oder das
  Netz erreichen könnten.
- **Kein Ersatz für einen Server:** Das Kit ist nicht dafür gedacht, über das
  Netz erreichbar gemacht zu werden. Wer `--bind-address` oder den Webserver
  auf eine andere Adresse umstellt, öffnet eine Datenbank ohne Passwortschutz.

## Testprotokoll

`TEST.bat` schreibt `testprotokoll.txt` mit Windows-Benutzername, PC-Name und
den Netzlaufwerken der Schule. Vor dem Teilen (Issue, Forum) diese Angaben
entfernen.
