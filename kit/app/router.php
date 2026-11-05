<?php
/**
 * SQL-Labor: Vorschaltskript fuer den eingebauten PHP-Webserver (php -S ... router.php).
 *
 * phpMyAdmin meldet sich ohne Passwortabfrage an. Damit eine fremde Webseite
 * das nicht per DNS-Rebinding ausnutzen kann (ihr Name zeigt ploetzlich auf
 * 127.0.0.1, der Browser schickt dann ihren Namen im Host-Kopf), nimmt der
 * Server nur Anfragen an, die ihn unter 127.0.0.1 oder localhost ansprechen.
 * Alles andere gibt 403. Danach liefert der Server die Datei wie ohne Router aus.
 */

declare(strict_types=1);

$port = (string) ($_SERVER['SERVER_PORT'] ?? '');
$host = strtolower((string) ($_SERVER['HTTP_HOST'] ?? ''));
$erlaubt = array('127.0.0.1:' . $port, 'localhost:' . $port);

if (!in_array($host, $erlaubt, true)) {
	http_response_code(403);
	header('Content-Type: text/plain; charset=utf-8');
	echo "SQL-Labor: Zugriff nur ueber http://127.0.0.1:$port/\n";
	return true;
}

return false;
