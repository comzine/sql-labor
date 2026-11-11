<?php
// Startseite deines Webordners im SQL-Labor. Du darfst sie ändern oder löschen;
// START.bat legt sie nur an, wenn der Ordner neu ist.

// Verbindung zur Datenbank des SQL-Labors (gilt für alle eigenen Seiten):
//   Host 127.0.0.1, Port 13306, Benutzer sus, Passwort sus
$db_status = '';
try {
    $db = new PDO('mysql:host=127.0.0.1;port=13306;dbname=northwind;charset=utf8mb4', 'sus', 'sus');
    $anzahl = $db->query('SELECT COUNT(*) FROM customers')->fetchColumn();
    $db_status = "Datenbank erreichbar: northwind hat $anzahl Kunden.";
} catch (PDOException $e) {
    $db_status = 'Datenbank nicht erreichbar: ' . $e->getMessage();
}

$dateien = array_values(array_filter(scandir(__DIR__), function ($n) {
    return $n[0] !== '.';
}));
?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <title>Mein Webordner</title>
    <style>
        body { font: 16px/1.5 system-ui, sans-serif; max-width: 46rem; margin: 2rem auto; padding: 0 1rem; color: #222; }
        code, pre { background: #f2f2f2; padding: 0 .25rem; }
        pre { padding: .6rem; overflow-x: auto; }
        a { color: #0b5cad; }
        .hinweis { color: #555; font-size: .9rem; }
    </style>
</head>
<body>
    <h1>Mein Webordner im SQL-Labor</h1>
    <p>Diese Seite ist <code><?= htmlspecialchars(__FILE__) ?></code>.
       Alles, was du in diesen Ordner legst, erreichst du unter
       <code>http://127.0.0.1:18000/</code> und dem Dateinamen.</p>

    <h2>Dateien</h2>
    <ul>
        <?php foreach ($dateien as $name): ?>
            <li><a href="<?= htmlspecialchars(rawurlencode($name)) ?><?= is_dir(__DIR__ . '/' . $name) ? '/' : '' ?>"><?= htmlspecialchars($name) ?></a></li>
        <?php endforeach; ?>
    </ul>

    <h2>Datenbank</h2>
    <p><?= htmlspecialchars($db_status) ?></p>
    <pre>$db = new PDO('mysql:host=127.0.0.1;port=13306;dbname=northwind;charset=utf8mb4', 'sus', 'sus');</pre>
    <p>Beispiel mit einer Abfrage: <a href="northwind_kunden.php">northwind_kunden.php</a>.
       Tabellen ansehen und SQL ausprobieren: <a href="http://127.0.0.1:18080/">phpMyAdmin</a>.</p>

    <p class="hinweis">PHP <?= PHP_VERSION ?> · Fehlermeldungen werden angezeigt · SQL-Labor von Tobias Weber</p>
</body>
</html>
