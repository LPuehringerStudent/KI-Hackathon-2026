---
title: "Luftgüte- und meteorologische Messwerte"
summary: "Rollierende Luft- und Wettermesswerte von fünf verfügbaren Stationen in und um Linz"
provider: "Land Oberösterreich, Abteilung Umweltschutz"
status: "optional"
format: "JSON-API"
license: "CC BY 4.0"
data_vintage: "Live-API mit rollierendem 24-Stunden-Fenster; zuletzt geprüft am 29. Juli 2026"
---

## Beschreibung

Die API des Landes Oberösterreich liefert je nach Station Luftschadstoffe und
Wetterkomponenten. Fünf der neun im Katalog gelisteten Endpunkte enthalten
aktuelle Messwerte. Die Stadt Linz veröffentlicht den Katalogeintrag, ist aber
nicht Betreiberin der Messstationen oder der API.

## Verfügbare Stationen

| Code | Station | Status am 29. Juli 2026 |
|---|---|---|
| [`S184`](https://www2.land-oberoesterreich.gv.at/imm/jaxrs/messwerte/json?stationcode=S184) | [Stadtpark](https://www.land-oberoesterreich.gv.at/Mediendateien/Formulare/Dokumente%20UWD%20Abt_US/S184_detail.pdf) | Messwerte verfügbar |
| [`S425`](https://www2.land-oberoesterreich.gv.at/imm/jaxrs/messwerte/json?stationcode=S425) | [Freinberg-Sender](https://www.land-oberoesterreich.gv.at/Mediendateien/Formulare/Dokumente%20UWD%20Abt_US/S425_detail.pdf) | Messwerte verfügbar |
| [`S415`](https://www2.land-oberoesterreich.gv.at/imm/jaxrs/messwerte/json?stationcode=S415) | [24er-Turm](https://www.land-oberoesterreich.gv.at/Mediendateien/Formulare/Dokumente%20UWD%20Abt_US/S415_detail.pdf) | Messwerte verfügbar |
| [`S416`](https://www2.land-oberoesterreich.gv.at/imm/jaxrs/messwerte/json?stationcode=S416) | [Neue Welt](https://www.land-oberoesterreich.gv.at/Mediendateien/Formulare/Dokumente%20UWD%20Abt_US/S416_detail.pdf) | Messwerte verfügbar |
| [`S431`](https://www2.land-oberoesterreich.gv.at/imm/jaxrs/messwerte/json?stationcode=S431) | [Römerberg](https://www.land-oberoesterreich.gv.at/Mediendateien/Formulare/Dokumente%20UWD%20Abt_US/S431_detail.pdf) | Messwerte verfügbar |
| `L001` | Goethestraße | Keine Messwerte; Lichtmessnetz wird erneuert |
| `L002` | Schlossmuseum | Keine Messwerte; Lichtmessnetz wird erneuert |
| `L003` | Sternwarte | Keine Messwerte; Lichtmessnetz wird erneuert |
| `C001` | Chemiepark | Keine Messwerte; kein Ersatzendpunkt bekannt |

Das Land Oberösterreich hat bestätigt, dass die Lichtmessdaten der mit `L`
beginnenden Stationen nicht mehr versendet werden, weil sie nicht mehr in der
zugrunde liegenden Datenbank liegen. Das oberösterreichische Lichtmessnetz wird
erneuert; währenddessen stehen keine Daten zur nächtlichen Himmelsaufhellung
bereit. Die Katalog-URLs für diese Stationen sind daher keine verwendbaren
Datenquellen. Für `C001` liefert die API ebenfalls keine Werte, die Rückmeldung
des Betreibers nennt dafür aber keinen Grund oder Ersatz.

## Datenformat

Eine erfolgreiche Antwort enthält ein Objekt mit dem Array `messwerte`:

```json
{
  "messwerte": [
    {
      "zeitpunkt": 1785254400000,
      "messwert": "3,09",
      "station": "S184",
      "komponente": "BOE",
      "mittelwert": "HMW",
      "einheit": "m/s"
    }
  ]
}
```

- `zeitpunkt` ist ein Unix-Zeitstempel in Millisekunden.
- `messwert` ist eine Zeichenkette mit deutschem Dezimalkomma.
- `komponente` bezeichnet die Messgröße; das Angebot unterscheidet sich je
  Station.
- `mittelwert` bezeichnet das Mittelungsintervall. Ein Messwert darf deshalb
  nicht allein anhand von Zeitpunkt und Komponente als eindeutig angenommen
  werden.
- Stationskoordinaten und ausgeschriebene Komponentenbezeichnungen fehlen in
  der Antwort. Die oben verlinkten amtlichen Stationsbeschreibungen enthalten
  Anschrift, Lageplan und Koordinaten in Grad, nennen aber das geodätische
  Bezugssystem dieser Gradangaben nicht. Sie sind deshalb nicht als
  vorbereitete WGS84-Koordinaten ausgewiesen.

So lassen sich Zeit und Zahlenwert in JavaScript normalisieren:

```js
const station = "S184";
const url =
  `https://www2.land-oberoesterreich.gv.at/imm/jaxrs/messwerte/json?stationcode=${station}`;
const response = await fetch(url);

if (!response.ok) {
  throw new Error(`Station ${station} ist nicht verfügbar: HTTP ${response.status}`);
}

const { messwerte } = await response.json();
const normalisiert = messwerte.map((wert) => ({
  ...wert,
  zeitpunkt: new Date(wert.zeitpunkt),
  messwert: Number(wert.messwert.replace(",", ".")),
}));
```

## Verwendungshinweise

Die API erlaubt bei der Prüfung direkte Browserzugriffe über CORS. Sie bietet
aber nur ein rollierendes 24-Stunden-Fenster und keinen historischen Download.
Benötigte Werte müssen deshalb regelmäßig gespeichert werden.

Jede Station muss einzeln mit HTTP-Statusprüfung, Timeout und Fehlerbehandlung
abgerufen werden. Ein HTTP-400-Text bedeutet bei den derzeit nicht verfügbaren
Stationen „keine Messwerte“ und ist keine JSON-Antwort. Bei der Prüfung trat
außerdem kurzzeitig ein HTTP-500-Fehler für alle Stationen auf. Für
Hackathon-Anwendungen sind daher Wiederholungsversuche, ein Cache der letzten
erfolgreichen Antwort und eine sichtbare Kennzeichnung fehlender oder veralteter
Werte nötig.

Der Datensatz bleibt `optional`: Die fünf funktionierenden Stationen sind für
Live-Prototypen nutzbar, aber ohne mitgeliefertes Archiv oder garantierte
Verfügbarkeit kein verlässlicher Standardbaustein.

## Quellen

- [data.gv.at-Katalogeintrag](https://www.data.gv.at/katalog/datasets/c312a9a9-fdbc-47e8-9da1-ad3be82dfbd6)
- [Land Oberösterreich: Oberösterreichisches Luftmessnetz](https://www.land-oberoesterreich.gv.at/14883.htm)
- [Land Oberösterreich: Beschreibungen der Messstationen](https://www.land-oberoesterreich.gv.at/17980.htm)
