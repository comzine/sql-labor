<?php
/**
 * SQL-Labor: Vorschaltskript fuer die eingebauten PHP-Webserver (php -S ... router.php),
 * fuer phpMyAdmin (Port 18080) und fuer die Webseiten der SuS (Port 18000).
 *
 * 1. Host-Pruefung: Damit eine fremde Webseite die Server nicht per DNS-Rebinding
 *    ansprechen kann (ihr Name zeigt ploetzlich auf 127.0.0.1, der Browser schickt
 *    dann ihren Namen im Host-Kopf), gilt nur 127.0.0.1 oder localhost. Sonst 403.
 * 2. Ordner ohne index.php/index.html bekommen eine Dateiliste, statt dass der
 *    Server still die index.php eines uebergeordneten Ordners ausliefert.
 * Alles andere liefert der Server aus wie ohne Router.
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

$wurzel = realpath((string) ($_SERVER['DOCUMENT_ROOT'] ?? ''));
$pfad = rawurldecode((string) (parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/'), PHP_URL_PATH) ?? '/'));
$ziel = $wurzel === false ? false : realpath($wurzel . DIRECTORY_SEPARATOR . ltrim($pfad, '/'));

if ($ziel === false || !is_dir($ziel) || !sqllabor_innerhalb($ziel, $wurzel)) {
	return false;
}
foreach (array('index.php', 'index.html', 'index.htm') as $index) {
	if (is_file($ziel . DIRECTORY_SEPARATOR . $index)) {
		return false;
	}
}
if (substr($pfad, -1) !== '/') {
	header('Location: ' . $pfad . '/', true, 301);
	return true;
}
sqllabor_dateiliste($ziel, $pfad);
return true;

function sqllabor_innerhalb(string $pfad, string $wurzel): bool
{
	$a = rtrim($pfad, '\\/') . DIRECTORY_SEPARATOR;
	$b = rtrim($wurzel, '\\/') . DIRECTORY_SEPARATOR;
	return PHP_OS_FAMILY === 'Windows'
		? strncasecmp($a, $b, strlen($b)) === 0
		: strncmp($a, $b, strlen($b)) === 0;
}

function sqllabor_dateiliste(string $ordner, string $pfad): void
{
	$eintraege = array_values(array_filter(scandir($ordner) ?: array(), function (string $n): bool {
		return $n !== '.' && $n !== '..' && $n[0] !== '.';
	}));
	usort($eintraege, function (string $a, string $b) use ($ordner): int {
		$da = is_dir($ordner . DIRECTORY_SEPARATOR . $a);
		$db = is_dir($ordner . DIRECTORY_SEPARATOR . $b);
		return $da === $db ? strnatcasecmp($a, $b) : ($da ? -1 : 1);
	});
	$h = function (string $s): string {
		return htmlspecialchars($s, ENT_QUOTES, 'UTF-8');
	};
	header('Content-Type: text/html; charset=utf-8');
	echo "<!DOCTYPE html>\n<html lang=\"de\"><head><meta charset=\"utf-8\">"
		. "<title>Inhalt von " . $h($pfad) . "</title>"
		. "<style>body{font:16px/1.5 system-ui,sans-serif;max-width:46rem;margin:2rem auto;padding:0 1rem}"
		. "li{margin:.2rem 0}a{color:#0b5cad}small{color:#666}</style></head><body>\n"
		. "<h1>Inhalt von " . $h($pfad) . "</h1>\n<ul>\n";
	if ($pfad !== '/') {
		echo "<li><a href=\"../\">..</a> <small>(eine Ebene höher)</small></li>\n";
	}
	foreach ($eintraege as $name) {
		$ist_ordner = is_dir($ordner . DIRECTORY_SEPARATOR . $name);
		$link = rawurlencode($name) . ($ist_ordner ? '/' : '');
		echo '<li><a href="' . $h($link) . '">' . $h($name) . ($ist_ordner ? '/' : '') . "</a></li>\n";
	}
	if (!$eintraege) {
		echo "<li><small>(leer)</small></li>\n";
	}
	echo "</ul>\n<p><small>SQL-Labor von Tobias Weber</small></p>\n</body></html>\n";
}
