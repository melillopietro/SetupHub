# Changelog

All notable changes to SetupHub are tracked in this file.

---

## English

### v1.1.1 - WinGet Invoker & VCLibs Dependencies Fix

- **Multi-tier WinGet Invoker**: Fixed `ERROR_ACCESS_DENIED` under elevated Administrator UAC tokens by wrapping execution through the Windows shell and alias broker.
- **Official VCLibs & XAML Dependencies**: Added automatic download of `DesktopAppInstaller_Dependencies.zip` from Microsoft GitHub releases, installing `Microsoft.VCLibs.140.00` (>=14.0.33519.0) and `Microsoft.UI.Xaml.2.8` to permanently resolve `0x80073CF3`.
- **Runspace Functions Injection**: Fixed `Repair-AppXEnvironment` and helper functions scope in WPF background runspaces, enabling bloatware cleanup.
- **Package Binding & Discord Fix**: Fixed Discord metadata and bound UI entries directly to package hashtables.

### v1.1 - WinGet Bootstrap Fix & CLI Unattended Support

- **WinGet Bootstrap Fix**: Added automatic Microsoft Windows App Runtime 1.8+ dependency installer during WinGet bootstrap, resolving AppX deployment error `0x80073CF3`.
- **CLI / Unattended Mode**: Added `-NoGui` command line parameter supporting automated provisioning without GUI (ideal for Intune, MDM, SCCM, and remote scripts).
- **GUI Search & Filtering**: Added real-time search boxes for software and bloatware lists, plus a category filter dropdown.
- **System Restore Point**: Added option to automatically create a Windows System Restore Point (`Checkpoint-Computer`) before deployment.
- **Pending Reboot Detection**: Added automatic check for pending Windows updates and reboots with a warning banner.
- **Resilience**: Added automatic WinGet source reset and update (`winget source reset --force`) post-bootstrap.

### v1.0 - First public release

- First GitHub-ready release of SetupHub.
- Windows 10 and Windows 11 support.
- Bilingual interface: Italian and English.
- Software deployment through WinGet and Microsoft Store package sources.
- Built-in software catalog with live availability validation.
- Predefined workstation profiles.
- Custom profile creation from the GUI.
- Windows bloatware cleanup through Appx and provisioned package checks.
- Hardware and software inventory included in every report.
- HTML, CSV, JSON, and text report outputs.
- Manual / unsupported package tracking for software that should not be installed automatically.
- GPL-3.0-only licensing.

---

## Italiano

### v1.1.1 - Fix Invoker WinGet e Dipendenze VCLibs

- **Invoker WinGet Multi-Tier**: Risolto l'errore `ERROR_ACCESS_DENIED` sotto token UAC elevato incapsulando l'esecuzione attraverso la shell di sistema e il broker degli alias.
- **Dipendenze Ufficiali VCLibs e XAML**: Aggiunto il download automatico di `DesktopAppInstaller_Dependencies.zip` da Microsoft GitHub Releases, con installazione di `Microsoft.VCLibs.140.00` (>=14.0.33519.0) e `Microsoft.UI.Xaml.2.8` per risolvere in modo definitivo l'errore `0x80073CF3`.
- **Iniezione Funzioni nel Runspace**: Risolto lo scope di `Repair-AppXEnvironment` e delle funzioni ausiliarie nel runspace in background WPF, abilitando la rimozione corretta del bloatware.
- **Binding Pacchetti e Fix Discord**: Corretti i metadati di Discord e associati gli elementi dell'interfaccia direttamente alle tabelle hash dei pacchetti.

### v1.1 - Fix Bootstrap WinGet e Supporto CLI Unattended

- **Fix Bootstrap WinGet**: Aggiunta l'installazione automatica della dipendenza Microsoft Windows App Runtime 1.8+ durante il bootstrap di WinGet, risolvendo l'errore di deployment AppX `0x80073CF3`.
- **Modalità CLI / Unattended**: Aggiunto il parametro `-NoGui` per il deployment automatizzato senza interfaccia grafica (ideale per Intune, MDM, SCCM e script remoti).
- **Ricerca e Filtri in Tempo Reale nella GUI**: Aggiunte caselle di ricerca istantanea per software e bloatware, oltre a un menu a tendina per il filtraggio per categoria.
- **Punto di Ripristino di Sistema**: Aggiunta opzione per creare automaticamente un punto di ripristino di Windows (`Checkpoint-Computer`) prima dell'avvio.
- **Rilevamento Riavvio Pendente**: Aggiunto controllo automatico dei riavvii e aggiornamenti di Windows pendenti con avviso informativo.
- **Resilienza**: Aggiunto ripristino e aggiornamento automatico delle sorgenti WinGet (`winget source reset --force`) dopo il bootstrap.

### v1.0 - Prima release pubblica

- Prima versione di SetupHub pronta per GitHub.
- Supporto per Windows 10 e Windows 11.
- Interfaccia bilingue: italiano e inglese.
- Installazione software tramite WinGet e sorgenti Microsoft Store.
- Catalogo software integrato con validazione live della disponibilita'.
- Profili predefiniti per workstation.
- Creazione di profili personalizzati dalla GUI.
- Rimozione bloatware Windows tramite controllo Appx e pacchetti provisioned.
- Inventario hardware e software incluso in ogni report.
- Report in formato HTML, CSV, JSON e TXT.
- Tracciamento dei pacchetti manuali/non supportati per software non adatti all'installazione automatica.
- Licenza GPL-3.0-only.
