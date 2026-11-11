# Toastyy · Release-Paket

Stand: 11. November 2026. TestFlight 1.0.0 (6) wurde erfolgreich hochgeladen.
Apple-Verarbeitungsstatus und Testgruppen sind ohne erneute Anmeldung nicht geprüft.

## Vorbereitet

- `../listing.en-US.json`: Store-Beschreibung und Review-Hinweise passend zum 720-ms-Fenster.
- `testflight-notes.en.txt`: kopierfertige TestFlight-Testhinweise.
- `device-test.de.md`: Abnahme auf einem echten iPhone.
- `app-privacy.de.md`: Arbeitsblatt zur App-Privacy-Deklaration.
- `website/toastyy-support.html`: fertige Support-Seite, ohne Tracking oder externe Assets.
- `website/app-ads.txt`: AdMob-Publisher-Eintrag für die Domain-Wurzel.
- `../privacy-addition.de.md`: vorhandener Entwurf; erst mit der finalen Werbekonfiguration abgleichen.
- `../screenshots/`: aktuelle, unveränderte 1206 × 2622 PNGs aus erfolgreichen UI-Tests.
  Keine Alpha-Kanäle; `screenshot-manifest.json` enthält Prüfsummen. Noch nicht hochgeladen.
- `todo.html`: persönliche Checkliste mit lokal gespeicherten Häkchen und Export.

## Website ist live · 11. November 2026

- Support: https://toasty.app.miomideal.com/support.html
- App-Datenschutz: https://toasty.app.miomideal.com/privacy.html
- Publisher-Datei: https://toasty.app.miomideal.com/app-ads.txt
- Crawler-Einstieg: https://miomideal.com/app-ads.txt

Alle vier URLs liefern HTTP 200 mit dem erwarteten Inhalt. Support/Marketing-URL
und Privacy Policy URL sind in App Store Connect gespeichert. Der Webserver
behält `.html`-Adressen, damit die Spiel-Fallbackroute diese Seiten nicht ersetzt.

Google crawlt bei verschachtelten Subdomains höchstens die erste Subdomain und
anschließend die Hauptdomain. Daher wurde auf der Hauptdomain ausschließlich
`public/app-ads.txt` ergänzt (mio_page Commit 4729be2). Die übrigen Mio-Seiten und
nicht committeten Arbeiten im ursprünglichen Checkout bleiben unverändert.
Quelle: https://support.google.com/admob/answer/9363762?hl=en

## Aktueller Apple-Status

Direkt geprüft am 11. November: Paid Apps Agreement = Pending User Info;
W-8BEN = Missing Tax Info; Banking = Processing; DSA = In Review.
Remove Ads ist angelegt, weltweit verfügbar und kostet in Deutschland EUR 2.99.
Der steuerliche Abschluss und ein erfolgreicher Kauf-/Restore-Test auf dem
Gerät stehen aus. Keine Steuerangaben wurden stellvertretend bestätigt.

## Finale Veröffentlichung

Build 6 nutzt weiterhin **Testanzeigen**. Er wurde nicht zur öffentlichen App-Prüfung eingereicht.
Nach Konto-, Datenschutz-, UMP- und Gerätetests einen neuen Produktionsbuild mit
neuer Buildnummer erstellen; Testanzeigen erst nach vollständiger Konfiguration
abschalten. Produktionswerbung beim Test nur mit registrierten Testgeräten prüfen.
Den ersten Remove-Ads-In-App-Kauf mit der ersten App-Version einreichen.
Manuelle Freigabe in App Store Connect beibehalten.

## Zugriffe

App Store Connect ist angemeldet. Store-Texte und Screenshots wurden aktualisiert.
AdMob benötigt noch Anmeldung; finale App-Privacy-Antworten und öffentliche
Einreichung sind offen. Coolify wurde per privater API-Eingabe genutzt.
Keine privaten Schlüssel oder Zugangsdaten liegen im Paket.
