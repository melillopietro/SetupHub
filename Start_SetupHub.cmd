:: SPDX-License-Identifier: GPL-3.0-only
:: Copyright (C) 2026 Pietro Melillo
@echo off
chcp 65001 >nul
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0SetupHub_Setup.ps1"
pause
