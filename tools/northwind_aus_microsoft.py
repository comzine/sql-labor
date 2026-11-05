#!/usr/bin/env python3
"""Erzeugt die MySQL/MariaDB-Fassung der Beispieldatenbank northwind aus Microsofts instnwnd.sql.

Quelle: Microsoft SQL Server Samples, https://github.com/microsoft/sql-server-samples,
Datei samples/databases/northwind-pubs/instnwnd.sql (fester Commit, siehe QUELLE_COMMIT),
MIT-Lizenz, Copyright (c) Microsoft Corporation.

Aufruf (im Wurzelverzeichnis des Repos):

    python3 tools/northwind_aus_microsoft.py kit/app/sql/northwind.sql
    python3 tools/northwind_aus_microsoft.py kit/app/sql/northwind.sql --quelle /pfad/instnwnd.sql

Ohne --quelle laedt das Skript instnwnd.sql in ein temporaeres Verzeichnis. In beiden
Faellen prueft es die SHA-256 und bricht bei Abweichung ab. Aus der Quelle wird nichts
ausgefuehrt: das Skript zerlegt die T-SQL-Datei in Token und liest nur die Spaltenlisten
der CREATE-TABLE-Anweisungen und die Werte der INSERT-Anweisungen. Die Tabellenstruktur
fuer MySQL/MariaDB (Typen, Schluessel, MyISAM, utf8) steht unten in TABELLEN.

Nur Python-Standardbibliothek.
"""

import argparse
import datetime
import functools
import hashlib
import os
import re
import struct
import sys
import tempfile
import urllib.request
from decimal import Decimal

QUELLE_REPO = "https://github.com/microsoft/sql-server-samples"
QUELLE_PFAD = "samples/databases/northwind-pubs/instnwnd.sql"
QUELLE_COMMIT = "2f85f3724ee45776a5183ed34d064488a6e1dc53"
QUELLE_URL = (
    "https://raw.githubusercontent.com/microsoft/sql-server-samples/"
    + QUELLE_COMMIT + "/" + QUELLE_PFAD
)
QUELLE_SHA256 = "3cc62b3fca6d244a47dbde698b809331e4f85988a0685b2b370717d431e94871"

# Wortlaut von license.txt im Repository microsoft/sql-server-samples (gleicher Commit).
LIZENZ = """\
Microsoft SQL Server Sample Code

Copyright (c) Microsoft Corporation

All rights reserved.

MIT License.

Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
"""


# --------------------------------------------------------------------------
# Zielstruktur
# --------------------------------------------------------------------------
# Spalte: (Name in MySQL, Typ-DDL, Spalte im Original oder None, Art)
# Art: int, dec4 (money -> decimal(19,4)), float (real), bool (bit), datum,
#      text, blob. Spalte None: im Original nicht vorhanden, Wert NULL.
# Die Typen folgen dem Original (nvarchar -> varchar mit utf8, ntext -> longtext,
# image -> longblob, money -> decimal(19,4), smallint -> int(11), real -> float,
# bit -> tinyint(1)); Spaltenreihenfolge, Schluessel und AUTO_INCREMENT entsprechen
# der bisherigen Fassung dieses Projekts. Keine Fremdschluessel (MyISAM).

TABELLEN = [
    {
        "name": "categories", "original": "Categories", "auto_increment": 9,
        "spalten": [
            ("CategoryID", "int(11) NOT NULL AUTO_INCREMENT", "CategoryID", "int"),
            ("CategoryName", "varchar(15) NOT NULL", "CategoryName", "text"),
            ("Description", "longtext", "Description", "text"),
            ("Picture", "longblob", "Picture", "blob"),
        ],
        "schluessel": [
            "PRIMARY KEY (`CategoryID`)",
            "UNIQUE KEY `CategoryName` (`CategoryName`)",
        ],
        "zeilen": 8,
    },
    {
        "name": "customers", "original": "Customers", "auto_increment": None,
        "spalten": [
            ("CustomerID", "varchar(5) NOT NULL", "CustomerID", "text"),
            ("CompanyName", "varchar(40) NOT NULL", "CompanyName", "text"),
            ("ContactName", "varchar(30) DEFAULT NULL", "ContactName", "text"),
            ("ContactTitle", "varchar(30) DEFAULT NULL", "ContactTitle", "text"),
            ("Address", "varchar(60) DEFAULT NULL", "Address", "text"),
            ("City", "varchar(15) DEFAULT NULL", "City", "text"),
            ("Region", "varchar(15) DEFAULT NULL", "Region", "text"),
            ("PostalCode", "varchar(10) DEFAULT NULL", "PostalCode", "text"),
            ("Country", "varchar(15) DEFAULT NULL", "Country", "text"),
            ("Phone", "varchar(24) DEFAULT NULL", "Phone", "text"),
            ("Fax", "varchar(24) DEFAULT NULL", "Fax", "text"),
            ("Image", "longblob", None, "blob"),
            ("ImageThumbnail", "longblob", None, "blob"),
        ],
        "schluessel": [
            "PRIMARY KEY (`CustomerID`)",
            "KEY `City` (`City`)",
            "KEY `CompanyName` (`CompanyName`)",
            "KEY `PostalCode` (`PostalCode`)",
            "KEY `Region` (`Region`)",
        ],
        "zeilen": 91,
    },
    {
        "name": "employees", "original": "Employees", "auto_increment": 10,
        "spalten": [
            ("EmployeeID", "int(11) NOT NULL AUTO_INCREMENT", "EmployeeID", "int"),
            ("LastName", "varchar(20) NOT NULL", "LastName", "text"),
            ("FirstName", "varchar(10) NOT NULL", "FirstName", "text"),
            ("Title", "varchar(30) DEFAULT NULL", "Title", "text"),
            ("TitleOfCourtesy", "varchar(25) DEFAULT NULL", "TitleOfCourtesy", "text"),
            ("BirthDate", "datetime DEFAULT NULL", "BirthDate", "datum"),
            ("HireDate", "datetime DEFAULT NULL", "HireDate", "datum"),
            ("Address", "varchar(60) DEFAULT NULL", "Address", "text"),
            ("City", "varchar(15) DEFAULT NULL", "City", "text"),
            ("Region", "varchar(15) DEFAULT NULL", "Region", "text"),
            ("PostalCode", "varchar(10) DEFAULT NULL", "PostalCode", "text"),
            ("Country", "varchar(15) DEFAULT NULL", "Country", "text"),
            ("HomePhone", "varchar(24) DEFAULT NULL", "HomePhone", "text"),
            ("Extension", "varchar(4) DEFAULT NULL", "Extension", "text"),
            ("Photo", "longblob", "Photo", "blob"),
            ("Notes", "longtext", "Notes", "text"),
            ("ReportsTo", "int(11) DEFAULT NULL", "ReportsTo", "int"),
            # PhotoPath aus dem Original entfaellt.
        ],
        "schluessel": [
            "PRIMARY KEY (`EmployeeID`)",
            "KEY `LastName` (`LastName`)",
            "KEY `PostalCode` (`PostalCode`)",
        ],
        "zeilen": 9,
    },
    {
        "name": "orderdetails", "original": "Order Details", "auto_increment": None,
        "spalten": [
            ("OrderID", "int(11) NOT NULL", "OrderID", "int"),
            ("ProductID", "int(11) NOT NULL", "ProductID", "int"),
            ("UnitPrice", "decimal(19,4) NOT NULL DEFAULT '0.0000'", "UnitPrice", "dec4"),
            ("Quantity", "int(11) NOT NULL DEFAULT '1'", "Quantity", "int"),
            ("Discount", "float NOT NULL DEFAULT '0'", "Discount", "float"),
        ],
        "schluessel": [
            "PRIMARY KEY (`OrderID`,`ProductID`)",
            "KEY `OrderID` (`OrderID`)",
            "KEY `ProductID` (`ProductID`)",
        ],
        "zeilen": 2155,
    },
    {
        "name": "orders", "original": "Orders", "auto_increment": 11078,
        "spalten": [
            ("OrderID", "int(11) NOT NULL AUTO_INCREMENT", "OrderID", "int"),
            ("CustomerID", "varchar(5) DEFAULT NULL", "CustomerID", "text"),
            ("EmployeeID", "int(11) DEFAULT NULL", "EmployeeID", "int"),
            ("OrderDate", "datetime DEFAULT NULL", "OrderDate", "datum"),
            ("RequiredDate", "datetime DEFAULT NULL", "RequiredDate", "datum"),
            ("ShippedDate", "datetime DEFAULT NULL", "ShippedDate", "datum"),
            ("ShipVia", "int(11) DEFAULT NULL", "ShipVia", "int"),
            ("Freight", "decimal(19,4) DEFAULT '0.0000'", "Freight", "dec4"),
            ("ShipName", "varchar(40) DEFAULT NULL", "ShipName", "text"),
            ("ShipAddress", "varchar(60) DEFAULT NULL", "ShipAddress", "text"),
            ("ShipCity", "varchar(15) DEFAULT NULL", "ShipCity", "text"),
            ("ShipRegion", "varchar(15) DEFAULT NULL", "ShipRegion", "text"),
            ("ShipPostalCode", "varchar(10) DEFAULT NULL", "ShipPostalCode", "text"),
            ("ShipCountry", "varchar(15) DEFAULT NULL", "ShipCountry", "text"),
        ],
        "schluessel": [
            "PRIMARY KEY (`OrderID`)",
            "KEY `CustomerID` (`CustomerID`)",
            "KEY `EmployeeID` (`EmployeeID`)",
            "KEY `OrderDate` (`OrderDate`)",
            "KEY `ShippedDate` (`ShippedDate`)",
            "KEY `ShipPostalCode` (`ShipPostalCode`)",
        ],
        "zeilen": 830,
    },
    {
        "name": "products", "original": "Products", "auto_increment": 78,
        "spalten": [
            ("ProductID", "int(11) NOT NULL AUTO_INCREMENT", "ProductID", "int"),
            ("ProductName", "varchar(40) NOT NULL", "ProductName", "text"),
            ("SupplierID", "int(11) DEFAULT NULL", "SupplierID", "int"),
            ("CategoryID", "int(11) DEFAULT NULL", "CategoryID", "int"),
            ("QuantityPerUnit", "varchar(20) DEFAULT NULL", "QuantityPerUnit", "text"),
            ("UnitPrice", "decimal(19,4) DEFAULT '0.0000'", "UnitPrice", "dec4"),
            ("UnitsInStock", "int(11) DEFAULT '0'", "UnitsInStock", "int"),
            ("UnitsOnOrder", "int(11) DEFAULT '0'", "UnitsOnOrder", "int"),
            ("ReorderLevel", "int(11) DEFAULT '0'", "ReorderLevel", "int"),
            ("Discontinued", "tinyint(1) DEFAULT '0'", "Discontinued", "bool"),
        ],
        "schluessel": [
            "PRIMARY KEY (`ProductID`)",
            "KEY `CategoryID` (`CategoryID`)",
            "KEY `ProductName` (`ProductName`)",
            "KEY `SupplierID` (`SupplierID`)",
        ],
        "zeilen": 77,
    },
    {
        "name": "shippers", "original": "Shippers", "auto_increment": 4,
        "spalten": [
            ("ShipperID", "int(11) NOT NULL AUTO_INCREMENT", "ShipperID", "int"),
            ("CompanyName", "varchar(40) NOT NULL", "CompanyName", "text"),
            ("Phone", "varchar(24) DEFAULT NULL", "Phone", "text"),
        ],
        "schluessel": ["PRIMARY KEY (`ShipperID`)"],
        "zeilen": 3,
    },
    {
        "name": "suppliers", "original": "Suppliers", "auto_increment": 30,
        "spalten": [
            ("SupplierID", "int(11) NOT NULL AUTO_INCREMENT", "SupplierID", "int"),
            ("CompanyName", "varchar(40) NOT NULL", "CompanyName", "text"),
            ("ContactName", "varchar(30) DEFAULT NULL", "ContactName", "text"),
            ("ContactTitle", "varchar(30) DEFAULT NULL", "ContactTitle", "text"),
            ("Address", "varchar(60) DEFAULT NULL", "Address", "text"),
            ("City", "varchar(15) DEFAULT NULL", "City", "text"),
            ("Region", "varchar(15) DEFAULT NULL", "Region", "text"),
            ("PostalCode", "varchar(10) DEFAULT NULL", "PostalCode", "text"),
            ("Country", "varchar(15) DEFAULT NULL", "Country", "text"),
            ("Phone", "varchar(24) DEFAULT NULL", "Phone", "text"),
            ("Fax", "varchar(24) DEFAULT NULL", "Fax", "text"),
            ("HomePage", "longtext", "HomePage", "text"),
        ],
        "schluessel": [
            "PRIMARY KEY (`SupplierID`)",
            "KEY `CompanyName` (`CompanyName`)",
            "KEY `PostalCode` (`PostalCode`)",
        ],
        "zeilen": 29,
    },
]


# --------------------------------------------------------------------------
# Angleichung an die aeltere Access-Fassung von Northwind
# --------------------------------------------------------------------------
# instnwnd.sql ist die SQL-Server-2000-Fassung. Die bisherige Fassung dieses
# Projekts beruht auf der aelteren Access-Fassung derselben Microsoft-Daten;
# Abfrageergebnisse sollen gleich bleiben. Darum gleicht das Skript diese Stellen an:
#
# 1. Bestelldaten (orders.OrderDate, RequiredDate, ShippedDate) liegen in der
#    Access-Fassung genau 700 Tage (100 Wochen, gleiche Wochentage) frueher:
#    1994-08-04 bis 1996-06-05 statt 1996-07-04 bis 1998-05-06.
DATUM_VERSCHIEBUNG = {
    ("orders", "OrderDate"): -700,
    ("orders", "RequiredDate"): -700,
    ("orders", "ShippedDate"): -700,
}

# 2. Zeilenumbrueche in Texten: Windows-Zeilenende CRLF wie in der Datenbank
#    (die Quelldatei im Git-Repository hat nur LF). Siehe zeilenumbruch_crlf().

# 3. Werte, die in instnwnd.sql ohne Sonderzeichen, mit Leerzeichen statt
#    Zeilenumbruch oder mit Tippfehler stehen. In der Access-Fassung stehen
#    sie so wie rechts (einschliesslich der Leerzeichen am Ende einiger Werte,
#    die in Vergleichen mit LIKE, LENGTH() und CONCAT() sichtbar sind).
FIRMEN = {
    "Blondesddsl père et fils": "Blondel père et fils",
    "HILARION-Abastos": "HILARIÓN-Abastos",
    "Tradiçao Hipermercados": "Tradição Hipermercados",
}
ORTE = {
    "Sao Paulo": "São Paulo",
    "Kobenhavn": "København",
    "Frankfurt a.M.": "Frankfurt a.M. ",
}
ADRESSEN = {
    "Berkeley Gardens 12  Brewery": "Berkeley Gardens\r\n12  Brewery ",
    "City Center Plaza 516 Main St.": "City Center Plaza\r\n516 Main St.",
    "Garden House Crowther Way": "Garden House\r\nCrowther Way",
    "87 Polk St. Suite 5": "87 Polk St.\r\nSuite 5",
    "South House 300 Queensbridge": "South House\r\n300 Queensbridge",
    "Ing. Gustavo Moncada 8585 Piso 20-A": "Ing. Gustavo Moncada 8585\r\nPiso 20-A",
    "89 Jefferson Way Suite 2": "89 Jefferson Way\r\nSuite 2",
    "Smagsloget 45": "Smagsløget 45",
    "305 - 14th Ave. S. Suite 3B": "305 - 14th Ave. S.\r\nSuite 3B",
    "Brook Farm Stratford St. Mary": "Brook Farm\r\nStratford St. Mary",
    "507 - 20th Ave. E.Apt. 2A": "507 - 20th Ave. E.\r\nApt. 2A",
    "9-8 Sekimai Musashino-shi": "9-8 Sekimai\r\nMusashino-shi",
    "92 Setsuko Chuo-ku": "92 Setsuko\r\nChuo-ku",
    "74 Rose St. Moonie Ponds": "74 Rose St.\r\nMoonie Ponds",
    "3400 - 8th Avenue Suite 210": "3400 - 8th Avenue\r\nSuite 210",
    "Order Processing Dept. 2100 Paul Revere Blvd.":
        "Order Processing Dept.\r\n2100 Paul Revere Blvd.",
    "Lyngbysild Fiskebakken 10": "Lyngbysild\r\nFiskebakken 10",
    "Verkoop Rijnweg 22": "Verkoop\r\nRijnweg 22",
    "170 Prince Edward Parade Hunter's Hill": "170 Prince Edward Parade\r\nHunter's Hill",
    "Bat. B 3, rue des Alpes": "Bat. B\r\n3, rue des Alpes",
}
PERSONEN = {
    "Lino Rodriguez": "Lino Rodriguez ",
    "Antonio del Valle Saavedra": "Antonio del Valle Saavedra ",
}
PRODUKTE = {
    "Rogede sild": "Røgede sild",
    "Flotemysost": "Fløtemysost",
}
WERTKORREKTUREN = {
    ("customers", "CompanyName"): FIRMEN,
    ("orders", "ShipName"): FIRMEN,
    ("customers", "City"): ORTE,
    ("orders", "ShipCity"): ORTE,
    ("suppliers", "City"): ORTE,
    ("customers", "Address"): ADRESSEN,
    ("orders", "ShipAddress"): ADRESSEN,
    ("employees", "Address"): ADRESSEN,
    ("suppliers", "Address"): ADRESSEN,
    ("customers", "ContactName"): PERSONEN,
    ("suppliers", "ContactName"): PERSONEN,
    ("products", "ProductName"): PRODUKTE,
}
# Einzelne Zeile (Tabelle, Primaerschluessel, Spalte, Wert im Original, neuer Wert):
# Lieferant 9 hat als einziger der beiden schwedischen Lieferanten "Sweden ".
ZEILENKORREKTUREN = [
    ("suppliers", 9, "Country", "Sweden", "Sweden "),
]

# 4. Mitarbeiterfotos: In den Fotos der Mitarbeiter 1 bis 5 steht im Kopf der
#    eingebetteten BMP-Datei eine um 10 zu grosse Dateigroesse (bfSize). Das
#    Skript setzt bfSize auf bfOffBits + biSizeImage wie bei den Fotos 6 bis 9
#    und fuehrt das Pruefbyte der OLE-Huelle nach. Siehe bmp_groesse_angleichen().
BMP_KORREKTUR = {("employees", "Photo")}


# --------------------------------------------------------------------------
# Quelle holen
# --------------------------------------------------------------------------

def quelle_lesen(pfad):
    """Liest instnwnd.sql (lokal oder per Download) und prueft die SHA-256."""
    if pfad:
        with open(pfad, "rb") as f:
            daten = f.read()
    else:
        with tempfile.TemporaryDirectory(prefix="northwind-") as tmp:
            ziel = os.path.join(tmp, "instnwnd.sql")
            print(f"Lade {QUELLE_URL}", file=sys.stderr)
            with urllib.request.urlopen(QUELLE_URL, timeout=60) as antwort, open(ziel, "wb") as f:
                f.write(antwort.read())
            with open(ziel, "rb") as f:
                daten = f.read()
    ist = hashlib.sha256(daten).hexdigest()
    if ist != QUELLE_SHA256:
        sys.exit(f"FEHLER: SHA-256 von instnwnd.sql ist {ist}, erwartet {QUELLE_SHA256}")
    return daten.decode("utf-8")


# --------------------------------------------------------------------------
# T-SQL zerlegen (nur lesen, nichts ausfuehren)
# --------------------------------------------------------------------------

_ZAHL = re.compile(r"\d+(?:\.\d*)?(?:[eE][-+]?\d+)?|\.\d+(?:[eE][-+]?\d+)?")
_WORT = re.compile(r"[A-Za-z_@#][A-Za-z0-9_@#$]*")
_HEX = re.compile(r"0[xX]([0-9A-Fa-f]*)")


def token(text):
    """Zerlegt T-SQL in (Art, Wert). Arten: str, num, hex, ident, word, punct.

    Zeichenketten: '...' und N'...' mit '' als Maskierung des Apostrophs.
    Kommentare (-- und /* */) werden uebersprungen.
    """
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c.isspace():
            i += 1
            continue
        if text.startswith("--", i):
            j = text.find("\n", i)
            i = n if j < 0 else j + 1
            continue
        if text.startswith("/*", i):
            j = text.find("*/", i + 2)
            if j < 0:
                raise ValueError("Kommentar /* ohne Ende")
            i = j + 2
            continue
        if c in "Nn" and i + 1 < n and text[i + 1] == "'":
            i += 1
            c = "'"
        if c == "'":
            teile, j = [], i + 1
            while True:
                k = text.find("'", j)
                if k < 0:
                    raise ValueError(f"Zeichenkette ohne Ende ab Zeichen {i}")
                teile.append(text[j:k])
                if k + 1 < n and text[k + 1] == "'":
                    teile.append("'")
                    j = k + 2
                else:
                    i = k + 1
                    break
            yield ("str", "".join(teile))
            continue
        if c == '"' or c == "[":
            ende = '"' if c == '"' else "]"
            k = text.find(ende, i + 1)
            if k < 0:
                raise ValueError(f"Bezeichner ohne Ende ab Zeichen {i}")
            yield ("ident", text[i + 1:k])
            i = k + 1
            continue
        m = _HEX.match(text, i)
        if m:
            yield ("hex", m.group(1))
            i = m.end()
            continue
        m = _ZAHL.match(text, i)
        if m:
            yield ("num", m.group(0))
            i = m.end()
            continue
        m = _WORT.match(text, i)
        if m:
            yield ("word", m.group(0))
            i = m.end()
            continue
        yield ("punct", c)
        i += 1


def _ist_wort(tk, wort):
    return tk[0] == "word" and tk[1].upper() == wort


def _name(tk):
    if tk[0] not in ("ident", "word"):
        raise ValueError(f"Tabellenname erwartet, gefunden {tk}")
    name = tk[1]
    return name.split(".")[-1]


def original_lesen(text):
    """Liefert ({Tabelle: [Spalten]}, {Tabelle: [Zeilen als dict]}) aus instnwnd.sql."""
    toks = list(token(text))
    if not any(_ist_wort(toks[i], "DATEFORMAT") and toks[i + 1] == ("word", "mdy")
               for i in range(len(toks) - 1)):
        raise ValueError("SET DATEFORMAT mdy nicht gefunden; Datumsformat unklar")
    spalten, zeilen = {}, {}
    i = 0
    while i < len(toks):
        tk = toks[i]
        if _ist_wort(tk, "CREATE") and _ist_wort(toks[i + 1], "TABLE"):
            j = i + 2
            # [dbo].[Name] oder "Name"
            while toks[j + 1] == ("punct", "."):
                j += 2
            tabelle = _name(toks[j])
            j += 1
            if toks[j] != ("punct", "("):
                raise ValueError(f"CREATE TABLE {tabelle}: '(' erwartet")
            j += 1
            tiefe, liste, anfang = 1, [], True
            while tiefe:
                t = toks[j]
                if t == ("punct", "("):
                    tiefe += 1
                elif t == ("punct", ")"):
                    tiefe -= 1
                elif t == ("punct", ",") and tiefe == 1:
                    anfang = True
                    j += 1
                    continue
                if anfang and tiefe == 1:
                    if t[0] == "ident":
                        liste.append(t[1])
                    elif not (t[0] == "word" and t[1].upper() in
                              ("CONSTRAINT", "PRIMARY", "FOREIGN", "CHECK", "UNIQUE")):
                        raise ValueError(f"CREATE TABLE {tabelle}: unerwartet {t}")
                    anfang = False
                j += 1
            spalten[tabelle] = liste
            i = j
            continue
        if _ist_wort(tk, "INSERT"):
            j = i + 1
            if _ist_wort(toks[j], "INTO"):
                j += 1
            tabelle = _name(toks[j])
            j += 1
            namen = None
            if toks[j] == ("punct", "("):
                namen = []
                j += 1
                while toks[j] != ("punct", ")"):
                    if toks[j][0] == "ident":
                        namen.append(toks[j][1])
                    elif toks[j] != ("punct", ","):
                        raise ValueError(f"INSERT {tabelle}: Spaltenliste unklar bei {toks[j]}")
                    j += 1
                j += 1
            if not _ist_wort(toks[j], "VALUES") or toks[j + 1] != ("punct", "("):
                raise ValueError(f"INSERT {tabelle}: VALUES( erwartet, gefunden {toks[j]}")
            j += 2
            werte, erwarte_wert = [], True
            while True:
                t = toks[j]
                if erwarte_wert:
                    if t[0] == "str":
                        werte.append(t[1])
                    elif t[0] == "num":
                        werte.append(Decimal(t[1]))
                    elif t[0] == "hex":
                        if len(t[1]) % 2:
                            raise ValueError(f"INSERT {tabelle}: Hex-Literal mit ungerader Laenge")
                        werte.append(bytes.fromhex(t[1]))
                    elif _ist_wort(t, "NULL"):
                        werte.append(None)
                    else:
                        # Ausdruecke (convert(...), Vorzeichen, Funktionen) kommen in
                        # dieser Quelle nicht vor; lieber abbrechen als raten.
                        raise ValueError(f"INSERT {tabelle}: Wert nicht unterstuetzt: {t}")
                    erwarte_wert = False
                elif t == ("punct", ","):
                    erwarte_wert = True
                elif t == ("punct", ")"):
                    break
                else:
                    raise ValueError(f"INSERT {tabelle}: ',' oder ')' erwartet, gefunden {t}")
                j += 1
            if namen is None:
                if tabelle not in spalten:
                    raise ValueError(f"INSERT {tabelle} ohne Spaltenliste vor CREATE TABLE")
                namen = spalten[tabelle]
            if len(namen) != len(werte):
                raise ValueError(f"INSERT {tabelle}: {len(namen)} Spalten, {len(werte)} Werte")
            zeilen.setdefault(tabelle, []).append(dict(zip(namen, werte)))
            i = j + 1
            continue
        i += 1
    return spalten, zeilen


# --------------------------------------------------------------------------
# Werte umwandeln
# --------------------------------------------------------------------------

def zeilenumbruch_crlf(s):
    return re.sub(r"\r?\n", "\r\n", s)


def _xor(daten):
    return functools.reduce(lambda a, b: a ^ b, daten, 0)


def bmp_groesse_angleichen(ole):
    """Setzt bfSize der in die OLE-Huelle eingebetteten BMP-Datei auf bfOffBits + biSizeImage.

    Aufbau (Access-OLE-Objekt "Bitmap Image" / Paint.Picture): 78 Byte Kopf, ab Byte 78
    die BMP-Datei, am Ende ein Nachspann; das viertletzte Byte ist das XOR aller Bytes
    ab Byte 47 bis davor. Gibt (Bytes, geaendert) zurueck.
    """
    if ole[78:80] != b"BM":
        raise ValueError("Foto: keine BMP-Datei ab Byte 78")
    if _xor(ole[47:-4]) != ole[-4]:
        raise ValueError("Foto: Pruefbyte der OLE-Huelle stimmt nicht; Aufbau unbekannt")
    bf_size = struct.unpack_from("<I", ole, 80)[0]
    off_bits = struct.unpack_from("<I", ole, 88)[0]
    size_image = struct.unpack_from("<I", ole, 112)[0]
    soll = off_bits + size_image
    if size_image == 0 or bf_size == soll:
        return ole, False
    neu = bytearray(ole)
    struct.pack_into("<I", neu, 80, soll)
    neu[-4] = _xor(neu[47:-4])
    return bytes(neu), True


def _text(s):
    for ch in s:
        if ord(ch) > 0xFFFF:
            raise ValueError(f"Zeichen ausserhalb utf8 (3 Byte): {s!r}")
    s = (s.replace("\\", "\\\\").replace("'", "\\'").replace("\r", "\\r")
         .replace("\n", "\\n").replace("\0", "\\0").replace("\x1a", "\\Z"))
    return "'" + s + "'"


_DATUM = re.compile(r"(\d{1,2})/(\d{1,2})/(\d{4})")


def wert_sql(wert, art, tag_verschiebung=0):
    if wert is None:
        return "NULL"
    if art == "int":
        if not isinstance(wert, Decimal) or wert != wert.to_integral_value() or "." in str(wert):
            raise ValueError(f"Ganzzahl erwartet: {wert!r}")
        return str(int(wert))
    if art == "dec4":
        if not isinstance(wert, Decimal):
            raise ValueError(f"Zahl erwartet: {wert!r}")
        d = wert.quantize(Decimal("0.0001"))
        if d != wert:
            raise ValueError(f"mehr als 4 Nachkommastellen: {wert!r}")
        return str(d)
    if art == "float":
        if not isinstance(wert, Decimal):
            raise ValueError(f"Zahl erwartet: {wert!r}")
        return format(wert, "f")
    if art == "bool":
        if wert not in (Decimal(0), Decimal(1)):
            raise ValueError(f"bit 0/1 erwartet: {wert!r}")
        return str(int(wert))
    if art == "datum":
        m = _DATUM.fullmatch(wert) if isinstance(wert, str) else None
        if not m:
            raise ValueError(f"Datum m/d/yyyy erwartet: {wert!r}")
        d = datetime.date(int(m.group(3)), int(m.group(1)), int(m.group(2)))
        d += datetime.timedelta(days=tag_verschiebung)
        return "'" + d.isoformat() + " 00:00:00'"
    if art == "text":
        if not isinstance(wert, str):
            raise ValueError(f"Zeichenkette erwartet: {wert!r}")
        return _text(wert)
    if art == "blob":
        if not isinstance(wert, bytes):
            raise ValueError(f"Binaerwert erwartet: {wert!r}")
        return "0x" + wert.hex().upper() if wert else "''"
    raise ValueError(f"unbekannte Art {art}")


# --------------------------------------------------------------------------
# Ausgabe
# --------------------------------------------------------------------------

def kopf():
    zeilen = [
        "-- Northwind fuer MySQL/MariaDB",
        "--",
        "-- Quelle: Microsoft SQL Server Samples, " + QUELLE_REPO,
        "--         Datei " + QUELLE_PFAD,
        "--         Commit " + QUELLE_COMMIT,
        "--         SHA-256 der Datei " + QUELLE_SHA256,
        "--         Kopfvermerk der Datei: Copyright Microsoft, Inc. 1994 - 2000",
        "-- Lizenz: MIT License, Copyright (c) Microsoft Corporation (Wortlaut unten).",
        "--",
        "-- Umgewandelt mit tools/northwind_aus_microsoft.py: das Skript liest nur die",
        "-- INSERT-Daten der Quelle, die Tabellenstruktur fuer MySQL/MariaDB legt es selbst fest.",
        "-- Abweichungen vom Original:",
        "--   - Tabelle \"Order Details\" heisst `orderdetails`, alle Tabellennamen klein.",
        "--   - nur die Tabellen categories, customers, employees, orderdetails, orders,",
        "--     products, shippers, suppliers; keine Sichten, Prozeduren, CHECK-Regeln und",
        "--     Fremdschluessel; ENGINE=MyISAM, DEFAULT CHARSET=utf8.",
        "--   - Typen: nvarchar -> varchar, ntext -> longtext, image -> longblob,",
        "--     money -> decimal(19,4), smallint -> int, real -> float, bit -> tinyint(1).",
        "--   - employees ohne Spalte PhotoPath; customers mit den leeren Spalten Image und",
        "--     ImageThumbnail.",
        "--   - Daten angeglichen an die aeltere Access-Fassung von Northwind: Bestelldaten",
        "--     700 Tage frueher (1994-1996 statt 1996-1998), Zeilenumbrueche (CRLF) und",
        "--     Sonderzeichen in Adressen und Namen, Groessenfeld in 5 Mitarbeiterfotos.",
        "--     Die einzelnen Werte stehen im Skript.",
        "--",
        "-- Import: in phpMyAdmin ueber \"Importieren\" oder",
        "--         mysql -u root --default-character-set=utf8mb4 < northwind.sql",
        "-- Das Skript legt die Datenbank `northwind` an und ersetzt vorhandene Tabellen.",
        "--",
        "-- Lizenz der Quelle (license.txt im Repository microsoft/sql-server-samples):",
        "--",
    ]
    for z in LIZENZ.splitlines():
        zeilen.append(("--   " + z).rstrip())
    for z in zeilen:
        if not z.isascii():
            raise ValueError(f"Kopf nicht ASCII: {z}")
    return "\n".join(zeilen) + "\n"


def erzeugen(text):
    spalten_original, zeilen_original = original_lesen(text)
    genutzt = set()
    aus = [kopf(), "\nCREATE DATABASE IF NOT EXISTS northwind;\nUSE northwind;\n\nSET FOREIGN_KEY_CHECKS=0;\n"]
    bmp_geaendert = 0
    for t in TABELLEN:
        name, orig = t["name"], t["original"]
        if orig not in zeilen_original:
            raise ValueError(f"Tabelle {orig} hat in der Quelle keine Daten")
        rohzeilen = zeilen_original[orig]
        if len(rohzeilen) != t["zeilen"]:
            raise ValueError(f"{orig}: {len(rohzeilen)} Zeilen, erwartet {t['zeilen']}")
        for _, _, quelle, _ in t["spalten"]:
            if quelle is not None and quelle not in spalten_original[orig]:
                raise ValueError(f"{orig}: Spalte {quelle} fehlt in der Quelle")
        aus.append("-- ----------------------------\n")
        aus.append(f"-- Table structure for `{name}`\n")
        aus.append("-- ----------------------------\n")
        aus.append(f"DROP TABLE IF EXISTS `{name}`;\n")
        aus.append(f"CREATE TABLE `{name}` (\n")
        defs = [f"  `{s}` {typ}" for s, typ, _, _ in t["spalten"]]
        defs += ["  " + k for k in t["schluessel"]]
        aus.append(",\n".join(defs) + "\n")
        ai = f" AUTO_INCREMENT={t['auto_increment']}" if t["auto_increment"] else ""
        aus.append(f") ENGINE=MyISAM{ai} DEFAULT CHARSET=utf8;\n\n")
        aus.append("-- ----------------------------\n")
        aus.append(f"-- Records of {name}\n")
        aus.append("-- ----------------------------\n")
        schluessel_spalte = t["spalten"][0][2]
        gesehen = set()
        for roh in rohzeilen:
            pk = roh[schluessel_spalte]
            pk_vergleich = int(pk) if isinstance(pk, Decimal) else pk
            felder = []
            for s, _, quelle, art in t["spalten"]:
                wert = None if quelle is None else roh[quelle]
                if art == "text" and wert is not None:
                    wert = zeilenumbruch_crlf(wert)
                    tabelle_korr = WERTKORREKTUREN.get((name, s), {})
                    if wert in tabelle_korr:
                        genutzt.add((id(tabelle_korr), wert))
                        wert = tabelle_korr[wert]
                    for k in ZEILENKORREKTUREN:
                        if k[0] == name and k[1] == pk_vergleich and k[2] == s:
                            if wert != k[3]:
                                raise ValueError(f"Zeilenkorrektur {k}: Wert ist {wert!r}")
                            wert = k[4]
                            genutzt.add(k)
                if (name, s) in BMP_KORREKTUR and wert is not None:
                    wert, geaendert = bmp_groesse_angleichen(wert)
                    bmp_geaendert += geaendert
                felder.append(wert_sql(wert, art, DATUM_VERSCHIEBUNG.get((name, s), 0)))
            if name == "orderdetails":
                schluessel = (roh["OrderID"], roh["ProductID"])
            else:
                schluessel = pk_vergleich
            if schluessel in gesehen:
                raise ValueError(f"{name}: Schluessel doppelt: {schluessel}")
            gesehen.add(schluessel)
            aus.append(f"INSERT INTO `{name}` VALUES (" + ", ".join(felder) + ");\n")
        if t["auto_increment"]:
            naechster = max(gesehen) + 1
            if naechster != t["auto_increment"]:
                raise ValueError(f"{name}: AUTO_INCREMENT {t['auto_increment']}, Daten ergeben {naechster}")
        aus.append("\n")
    # Jede Korrektur muss gegriffen haben, sonst stimmt die Liste nicht.
    for korr in {id(v): v for v in WERTKORREKTUREN.values()}.values():
        for alt in korr:
            if (id(korr), alt) not in genutzt:
                raise ValueError(f"Wertkorrektur greift nicht: {alt!r}")
    for k in ZEILENKORREKTUREN:
        if k not in genutzt:
            raise ValueError(f"Zeilenkorrektur greift nicht: {k}")
    if bmp_geaendert != 5:
        raise ValueError(f"Fotokorrektur: {bmp_geaendert} Fotos geaendert, erwartet 5")
    return "".join(aus)


def main():
    p = argparse.ArgumentParser(description="northwind.sql (MySQL/MariaDB) aus Microsofts instnwnd.sql erzeugen")
    p.add_argument("ziel", help="Ausgabedatei, z. B. kit/app/sql/northwind.sql")
    p.add_argument("--quelle", help="bereits heruntergeladene instnwnd.sql (SHA-256 wird geprueft)")
    args = p.parse_args()
    sql = erzeugen(quelle_lesen(args.quelle))
    ziel = os.path.abspath(args.ziel)
    tmp = ziel + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as f:
        f.write(sql)
    os.replace(tmp, ziel)
    print(f"geschrieben: {args.ziel} ({os.path.getsize(ziel)} Byte)", file=sys.stderr)


if __name__ == "__main__":
    main()
