# SetupHub

**SetupHub** is a lightweight Windows workstation setup tool built around WinGet, Microsoft Store packages, software profiles, bloatware cleanup, and deployment reporting.

It was created for a very practical IT scenario: a fresh or recently reinstalled Windows machine, a list of applications to install, a few unwanted preinstalled apps to remove, and the need to leave behind a clear report of what was done.

<p align="center">
  <img src="./assets/screenshots/setuphub-main.png" alt="SetupHub main interface" width="900">
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

> The image files are stored in `assets/screenshots/`. Keep the filenames exactly as shown below.

### Main interface

<p align="center">
  <img src="./assets/screenshots/setuphub-main.png" alt="SetupHub main interface" width="900">
</p>

### Profile selection and custom profiles

<p align="center">
  <img src="./assets/screenshots/setuphub-profiles.png" alt="SetupHub profile selection and custom profiles" width="900">
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
