<?php
/**
 * SQL-Labor: phpMyAdmin meldet sich automatisch an der lokalen MariaDB des Kits an.
 * Server und PHP lauschen nur auf 127.0.0.1, von aussen ist nichts erreichbar.
 * Die Startskripte setzen SQLLABOR_TMP (Cache und Uploads je Benutzer).
 */

declare(strict_types=1);

$sqllaborTmp = getenv('SQLLABOR_TMP') ?: sys_get_temp_dir();

// Nur fuer die Cookie-Anmeldung noetig, die das Kit nicht nutzt. Trotzdem je
// Installation zufaellig (32 Zeichen), damit kein festes Geheimnis im Repo steht.
$sqllaborGeheimDatei = $sqllaborTmp . DIRECTORY_SEPARATOR . 'blowfish_secret.txt';
if (!is_file($sqllaborGeheimDatei)) {
    @file_put_contents($sqllaborGeheimDatei, bin2hex(random_bytes(16)), LOCK_EX);
}
$sqllaborGeheim = trim((string) @file_get_contents($sqllaborGeheimDatei));
$cfg['blowfish_secret'] = strlen($sqllaborGeheim) === 32 ? $sqllaborGeheim : bin2hex(random_bytes(16));

$i = 1;
$cfg['Servers'][$i]['verbose'] = 'SQL-Labor';
$cfg['Servers'][$i]['auth_type'] = 'config';
$cfg['Servers'][$i]['host'] = '127.0.0.1';
$cfg['Servers'][$i]['port'] = '13306';
$cfg['Servers'][$i]['user'] = 'sus';
$cfg['Servers'][$i]['password'] = 'sus';
$cfg['Servers'][$i]['compress'] = false;
$cfg['Servers'][$i]['AllowNoPassword'] = false;
// Systemdatenbanken in der Navigation ausblenden (per SQL bleiben sie erreichbar).
$cfg['Servers'][$i]['hide_db'] = '^(information_schema|mysql|performance_schema|sys|phpmyadmin)$';

// Konfigurationsspeicher in der Datenbank phpmyadmin (legt START.bat beim ersten Start an):
// Designer, Beziehungsansicht, SQL-Verlauf, Lesezeichen.
$cfg['Servers'][$i]['controluser'] = 'sus';
$cfg['Servers'][$i]['controlpass'] = 'sus';
$cfg['Servers'][$i]['pmadb'] = 'phpmyadmin';
$cfg['Servers'][$i]['bookmarktable'] = 'pma__bookmark';
$cfg['Servers'][$i]['relation'] = 'pma__relation';
$cfg['Servers'][$i]['table_info'] = 'pma__table_info';
$cfg['Servers'][$i]['table_coords'] = 'pma__table_coords';
$cfg['Servers'][$i]['pdf_pages'] = 'pma__pdf_pages';
$cfg['Servers'][$i]['column_info'] = 'pma__column_info';
$cfg['Servers'][$i]['history'] = 'pma__history';
$cfg['Servers'][$i]['table_uiprefs'] = 'pma__table_uiprefs';
$cfg['Servers'][$i]['tracking'] = 'pma__tracking';
$cfg['Servers'][$i]['userconfig'] = 'pma__userconfig';
$cfg['Servers'][$i]['recent'] = 'pma__recent';
$cfg['Servers'][$i]['favorite'] = 'pma__favorite';
$cfg['Servers'][$i]['users'] = 'pma__users';
$cfg['Servers'][$i]['usergroups'] = 'pma__usergroups';
$cfg['Servers'][$i]['navigationhiding'] = 'pma__navigationhiding';
$cfg['Servers'][$i]['savedsearches'] = 'pma__savedsearches';
$cfg['Servers'][$i]['central_columns'] = 'pma__central_columns';
$cfg['Servers'][$i]['designer_settings'] = 'pma__designer_settings';
$cfg['Servers'][$i]['export_templates'] = 'pma__export_templates';

$cfg['ServerDefault'] = 1;
$cfg['TempDir'] = $sqllaborTmp;
$cfg['UploadDir'] = '';
$cfg['SaveDir'] = '';

// Offline und ruhig: keine Versionsabfrage, keine Fehlerberichte nach aussen.
$cfg['VersionCheck'] = false;
$cfg['SendErrorReports'] = 'never';
$cfg['ShowPhpInfo'] = false;
$cfg['ShowChgPassword'] = false;
$cfg['ShowCreateDb'] = true;

$cfg['DefaultLang'] = 'de';
$cfg['ThemeDefault'] = 'pmahomme';
$cfg['QueryHistoryDB'] = true;
$cfg['QueryHistoryMax'] = 100;
