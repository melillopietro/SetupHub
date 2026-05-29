# SetupHub

**SetupHub** is a lightweight Windows workstation setup tool built around WinGet, Microsoft Store packages, software profiles, bloatware cleanup, and deployment reporting.

It was created for a practical IT scenario: a fresh or recently reinstalled Windows machine, a list of applications to install, a few unwanted preinstalled apps to remove, and the need to leave behind a clear report of what was done.

<p align="center">
  <img src="./assets/screenshots/setuphub-main.png.PNG" alt="SetupHub main interface" width="900">
</p>

<p align="center">
  <a href="./LICENSE">
    <img alt="License: GPL-3.0-only" src="https://img.shields.io/badge/license-GPL--3.0--only-blue">
  </a>
  <img alt="Windows 10/11" src="https://img.shields.io/badge/platform-Windows%2010%20%2F%2011-lightgrey">
  <img alt="PowerShell" src="https://img.shields.io/badge/PowerShell-5.1%2B-blue">
  <img alt="WinGet" src="https://img.shields.io/badge/package%20manager-WinGet-green">
</p>

---

## What SetupHub does

SetupHub provides a graphical interface for preparing Windows 10 and Windows 11 workstations.

It helps you:

- install commonly used applications through WinGet and Microsoft Store sources;
- apply predefined or custom software profiles;
- remove selected Windows preinstalled apps;
- validate the software catalog before installation;
- collect hardware and software inventory from the machine;
- generate a final deployment report in multiple formats.

SetupHub does **not** bundle third-party installers. Package resolution and installation are handled by the package sources configured on the target machine. This keeps the repository small, easier to review, and more transparent from an operational point of view.

---

## Main features

- **Windows 10 and Windows 11 support**  
  Designed for modern Windows workstations with PowerShell and WinGet available.

- **Bilingual interface**  
  The GUI supports both English and Italian.

- **Curated software catalog**  
  Applications are grouped by category, including browsers, office tools, developer tools, cybersecurity utilities, remote support tools, multimedia applications, virtualization tools, and system utilities.

- **Live package validation**  
  Before starting the deployment, SetupHub checks whether each supported package can actually be resolved from the configured WinGet or Microsoft Store source.

- **Predefined profiles**  
  Ready-to-use profiles are available for common workstation scenarios such as essential setup, business, developer, cybersecurity, multimedia, gaming, home, clean, and complete.

- **Custom profiles**  
  New profiles can be created directly from the GUI and saved for later use.

- **Bloatware cleanup**  
  SetupHub can remove selected Windows Appx and provisioned packages when present. If a package is already absent, it is recorded as skipped rather than treated as an error.

- **Hardware and software inventory**  
  The final report includes information about the operating system, CPU, memory, disks, volumes, GPU, network adapters, TPM, Secure Boot, Microsoft Defender status, PowerShell, WinGet, and installed software.

- **Deployment reporting**  
  Each run produces HTML, CSV, JSON, and text logs.

- **Manual / unsupported software tracking**  
  Some applications are intentionally excluded from automatic installation when their WinGet package is unavailable, unstable, vendor-restricted, or better handled manually.

---

## Screenshots

The screenshots below show the main workflow: selecting a software profile, validating the catalog, running the deployment, and reviewing the generated report and inventory.

### Main interface

<p align="center">
  <img src="./assets/screenshots/setuphub-main.png.PNG" alt="SetupHub main interface" width="900">
</p>

### Profile selection and custom profiles

<p align="center">
  <img src="./assets/screenshots/setuphub-profiles.png.png" alt="SetupHub profile selection and custom profiles" width="900">
</p>

### Catalog validation

<p align="center">
  <img src="./assets/screenshots/setuphub-catalog-validation.png" alt="SetupHub catalog validation" width="900">
</p>

### Deployment report

<p align="center">
  <img src="./assets/screenshots/setuphub-report.png" alt="SetupHub deployment report" width="900">
</p>

### Hardware and software inventory

<p align="center">
  <img src="./assets/screenshots/setuphub-inventory.png" alt="SetupHub hardware and software inventory" width="900">
</p>

Before publishing screenshots, remove or blur private information such as serial numbers, internal hostnames, public IP addresses, private IP addresses, MAC addresses, usernames, and local report paths.

---

## Requirements

SetupHub is designed for:

- Windows 10 build 18363 or newer;
- Windows 11;
- PowerShell 5.1 or newer;
- administrator privileges;
- WinGet / Windows Package Manager;
- Microsoft Store source, when Store-based packages are selected;
- internet access for package validation and download.

Some packages may require additional conditions, such as a Microsoft account, Microsoft 365 license, vendor account, or an installer flow controlled by the publisher.

---

## Quick start

Clone or download the repository, then start SetupHub from an elevated shell.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\SetupHub_Setup.ps1
```

You can also use the launcher:

```cmd
Start_SetupHub.cmd
```

SetupHub will request elevation if it is not already running as administrator.

---

## Recommended workflow

1. Start SetupHub as administrator.
2. Choose the interface language.
3. Select a predefined profile or create a new custom profile.
4. Review the software selection.
5. Review the bloatware cleanup section.
6. Start the deployment.
7. Wait for catalog validation, installation, cleanup, and inventory collection.
8. Open the generated HTML report from the `reports` folder.
9. Keep the report internally if needed, but do not publish it without removing sensitive host information.

---

## Profiles

Profiles are simple software selections used to prepare different workstation types faster.

Typical profile scenarios include:

- a basic office workstation;
- a business workstation;
- a developer machine;
- a cybersecurity analysis workstation;
- a multimedia workstation;
- a gaming workstation;
- a clean Windows setup with only essential tools.

Custom profiles are stored in the `profiles` folder. They can be created directly from the GUI with the **New profile** button and updated with **Save profile**.

---

## Package validation

Every run includes a catalog validation phase.

SetupHub checks whether each supported package can be resolved through the configured source before treating it as installable. This helps avoid false deployment failures caused by package IDs that were renamed, removed, replaced, or temporarily unavailable.

Packages that cannot be resolved are not counted as failed installations. They are reported separately so the deployment report remains meaningful.

This is important because WinGet package identifiers and vendor installers can change over time.

---

## Bloatware cleanup

SetupHub handles selected Windows preinstalled apps through Appx and provisioned package checks.

When a selected package exists, SetupHub attempts to remove it. When it does not exist, the result is recorded as already absent instead of being treated as an error.

This avoids false failures on machines that are already clean, have been customized by OEM images, or use a Windows edition where certain apps are not present.

---

## Reports

Each run creates a timestamped report set under the `reports` folder.

Typical outputs include:

```text
SetupHub_Report_<timestamp>.html
SetupHub_Report_<timestamp>.csv
SetupHub_Report_<timestamp>.json
SetupHub_Log_<timestamp>.txt
SetupHub_SystemInventory_<timestamp>.json
SetupHub_InstalledSoftware_<timestamp>.csv
SetupHub_CatalogAudit_<timestamp>.json
SetupHub_CatalogAudit_<timestamp>.csv
SetupHub_ManualUnsupported_<timestamp>.json
SetupHub_ManualUnsupported_<timestamp>.csv
```

The report includes:

- installation results;
- package validation status;
- bloatware cleanup results;
- command executed for each operation;
- exit codes;
- WinGet logs where available;
- hardware inventory;
- operating system information;
- disks and volumes;
- network adapters;
- TPM and Secure Boot status;
- Microsoft Defender status, when available;
- installed desktop software inventory.

Do not commit generated reports to the repository. They may contain machine-specific data.

---

## Manual and unsupported packages

Some tools are intentionally kept out of the automatic installation catalog.

This can happen when:

- the package is not consistently available through WinGet;
- the vendor requires a portal login;
- the software is distributed as a portable archive rather than a standard installer;
- the package depends on specific hardware;
- the installation is better handled manually.

Examples may include products such as Ghidra, VMware Workstation, or GPU-vendor tools depending on the current package ecosystem and the target machine.

These applications are documented in the report but are not treated as deployment errors.

---

## Repository layout

```text
SetupHub/
├── SetupHub_Setup.ps1
├── Start_SetupHub.cmd
├── README.md
├── LICENSE
├── NOTICE.md
├── CHANGELOG.md
├── SECURITY.md
├── CONTRIBUTING.md
├── .gitignore
├── assets/
│   └── screenshots/
├── docs/
│   └── SCREENSHOTS.md
├── profiles/
└── reports/
```

The `reports` folder is ignored by Git except for placeholder files. Keep generated reports local unless you have removed sensitive data.

---

## Security model

SetupHub does not host third-party installers in this repository.

It asks WinGet or Microsoft Store to resolve and install packages from the target machine. This design has two practical consequences:

1. the repository remains small and reviewable;
2. package availability depends on the target machine, configured sources, vendor manifests, and network conditions.

Always test the tool on a non-critical machine before using it in production or on multiple endpoints.

---

## License

SetupHub is released under the **GNU General Public License v3.0 only**.

SPDX identifier:

```text
GPL-3.0-only
```

In simple terms, you may use, study, share, and modify the code. If you distribute a modified version, the modified version must remain under the same license and the corresponding source code must remain available under GPL-3.0-only.

See [`LICENSE`](./LICENSE) for the full license text.

---

## Credits

Created and maintained by **Pietro Melillo**.

- Email: `melillopietro@gmail.com`
- Website: `https://melillopietro.github.io/`
- LinkedIn: `https://it.linkedin.com/in/melillopietro`

---

## Disclaimer

SetupHub is provided without warranty.

It changes the state of the local machine by installing software and removing selected Windows apps. Review the selected items before running it, and test it before using it in managed environments.
