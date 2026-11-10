# App Privacy – Arbeitsblatt, noch nicht in Apple veröffentlicht

Stand: 10. November 2026 · Build 5 · Google Mobile Ads 13.11.0 / UMP 3.1.0.

Die App speichert XP, Rekorde und Einstellungen lokal. Daraus folgt NICHT „Keine Daten erfasst“, sobald das Werbe-SDK läuft. Kein Firebase Analytics und keine eigene Spielstand-API sind eingebunden. StoreKit prüft verifizierte Käufe; Kartendaten gehen nicht an Toastyy.

## Vor dem Ausfüllen verbindlich abgleichen

1. AdMob → Privacy & messaging: veröffentlichte Nachrichten und Anbieter/Zwecke ansehen. Auswahl von personalisierter/nicht personalisierter Werbung sowie etwaige Mediation dokumentieren.
2. Aktuelle Google-Offenlegung und die tatsächlich gebündelten SDK-Manifeste gemeinsam prüfen. Googles aktuelle Online-Seite kann sich auf eine neuere SDK-Version beziehen.
3. In App Store Connect → App Privacy Zwecke, Nutzerverknüpfung und Tracking pro Datentyp wahrheitsgemäß beantworten. Fehlende ATT-Abfrage beweist keine Tracking-Freiheit.
4. Datenschutzerklärung und App-Privacy-Einträge an dieselbe Endkonfiguration anpassen. Erst danach veröffentlichen.

## Zu prüfende Datentypen

- Ungefährer Standort (z. B. aus IP-Adresse)
- Geräte-/App-Kennungen
- Werbedaten und Produktinteraktion
- Absturz-, Leistungs- und andere Diagnosedaten

Die gebündelten Angaben stehen in ../sdk-privacy-manifests.json. Angaben wie linked/tracking und Zwecke nicht pauschal für alle Typen übernehmen. Google nennt für das SDK Werbung und Analytics-Zwecke; die finale App-Konfiguration muss berücksichtigt werden.

Quellen:
- https://developers.google.com/admob/ios/privacy/data-disclosure
- https://developers.google.com/admob/ios/privacy
- https://developer.apple.com/app-store/app-privacy-details/

Status: vorbereitet; Kontoanmeldung und finale Werbekonfiguration fehlen. Keine Datenschutzangaben wurden verändert oder veröffentlicht.
