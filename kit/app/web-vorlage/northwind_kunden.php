<?php
// Beispiel: Kunden aus der Datenbank northwind nach Land anzeigen.
// Die Eingabe aus dem Formular kommt nie direkt in das SQL, sondern als
// Parameter einer vorbereiteten Anweisung (Prepared Statement). So kann
// niemand eigenes SQL einschleusen (SQL-Injection).

$db = new PDO('mysql:host=127.0.0.1;port=13306;dbname=northwind;charset=utf8mb4', 'sus', 'sus');
$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

$land = $_GET['land'] ?? 'Germany';

$abfrage = $db->prepare('SELECT CompanyName, City FROM customers WHERE Country = ? ORDER BY CompanyName');
$abfrage->execute([$land]);
$kunden = $abfrage->fetchAll(PDO::FETCH_ASSOC);

$laender = $db->query('SELECT DISTINCT Country FROM customers ORDER BY Country')->fetchAll(PDO::FETCH_COLUMN);
?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <title>Kunden nach Land</title>
    <style>
        body { font: 16px/1.5 system-ui, sans-serif; max-width: 46rem; margin: 2rem auto; padding: 0 1rem; }
        table { border-collapse: collapse; }
        th, td { border: 1px solid #ccc; padding: .25rem .6rem; text-align: left; }
    </style>
</head>
<body>
    <h1>Kunden nach Land</h1>
    <form method="get">
        <label>Land:
            <select name="land">
                <?php foreach ($laender as $l): ?>
                    <option <?= $l === $land ? 'selected' : '' ?>><?= htmlspecialchars($l) ?></option>
                <?php endforeach; ?>
            </select>
        </label>
        <button>Anzeigen</button>
    </form>

    <p><?= count($kunden) ?> Kunden in <?= htmlspecialchars($land) ?>:</p>
    <table>
        <tr><th>Firma</th><th>Stadt</th></tr>
        <?php foreach ($kunden as $k): ?>
            <tr><td><?= htmlspecialchars($k['CompanyName']) ?></td><td><?= htmlspecialchars($k['City']) ?></td></tr>
        <?php endforeach; ?>
    </table>
    <p><a href="./">Zurück zur Startseite</a></p>
</body>
</html>
