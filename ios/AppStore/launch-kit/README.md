# Toastyy · Release-Paket

Stand: 10. November 2026. TestFlight 1.0.0 (5) wurde erfolgreich hochgeladen.
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

## Website veröffentlichen

Das lokale Website-Projekt liegt unter `/Users/heroine/ras/dev/mio/mio_page`.
Dort liegen fremde, noch nicht committete Änderungen. Deshalb wurde keine
Website-Veröffentlichung oder Änderung an diesen Arbeiten vorgenommen.

1. `website/toastyy-support.html` nach `mio_page/public/toastyy-support.html` kopieren.
2. `website/app-ads.txt` nach `mio_page/public/app-ads.txt` kopieren. Vorhandene Publisher-Zeilen erhalten.
3. Die geprüfte Toastyy-Ergänzung in `mio_page/src/app/privacy-policy/page.tsx` einbauen.
   Die Aussage zu fehlenden Marketing-Cookies ausdrücklich auf die Website begrenzen.
4. Gezielt Website-Änderungen prüfen und deployen; keine fremden Änderungen blind mit veröffentlichen.
5. Öffentlich prüfen:
   - `https://miomideal.com/toastyy-support.html` zeigt die Support-Seite.
   - `https://miomideal.com/app-ads.txt` liefert den Publisher-Eintrag als Text.
   - `https://miomideal.com/privacy-policy` enthält die geprüfte Toastyy-Ergänzung.
6. Erst dann in App Store Connect die Support-URL auf die neue Seite ändern.
   In AdMob die Store-App und Entwicklerwebsite korrekt zuordnen und Verifizierung anstoßen.

## Finale Veröffentlichung

Build 5 nutzt weiterhin **Testanzeigen**. Er wurde nicht zur öffentlichen App-Prüfung eingereicht.
Nach Konto-, Datenschutz-, UMP- und Gerätetests einen neuen Produktionsbuild mit
neuer Buildnummer erstellen; Testanzeigen erst nach vollständiger Konfiguration
abschalten. Produktionswerbung beim Test nur mit registrierten Testgeräten prüfen.
Den ersten Remove-Ads-In-App-Kauf mit der ersten App-Version einreichen.
Manuelle Freigabe in App Store Connect beibehalten.

## Zugriffe

App Store Connect und AdMob zeigten beim heutigen Check jeweils die Anmeldeseite.
Kein Accountstatus, Vertrag, Datenschutzeintrag oder Store-Screenshot wurde in
App Store Connect verändert. Keine privaten Schlüssel oder Zugangsdaten liegen im Paket.
