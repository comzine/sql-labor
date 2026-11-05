-- Laeuft bei jedem Start von mariadbd (--init-file) mit vollen Rechten.
-- Legt den Benutzer an, mit dem phpMyAdmin, MySQL Workbench und die Skripte
-- des Kits arbeiten. mysql_native_password, weil MySQL Workbench (Client
-- libmysqlclient 8.x) die neueren MariaDB-Verfahren (ed25519, PARSEC) nicht kennt.
CREATE USER IF NOT EXISTS 'sus'@'127.0.0.1' IDENTIFIED VIA mysql_native_password USING PASSWORD('sus');
CREATE USER IF NOT EXISTS 'sus'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('sus');
ALTER USER 'sus'@'127.0.0.1' IDENTIFIED VIA mysql_native_password USING PASSWORD('sus');
ALTER USER 'sus'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('sus');
GRANT ALL PRIVILEGES ON *.* TO 'sus'@'127.0.0.1' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'sus'@'localhost' WITH GRANT OPTION;
