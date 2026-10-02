#!/usr/bin/env python3
"""Fail fast if an upstream sync silently drops TaliabuVPN customizations."""
from pathlib import Path
import hashlib
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []

def text(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")

def require(rel: str, needle: str) -> None:
    if needle not in text(rel):
        errors.append(f"{rel}: missing {needle!r}")

def forbid(rel: str, needle: str) -> None:
    if needle in text(rel):
        errors.append(f"{rel}: forbidden {needle!r}")

# Brand / shipped executable.
require("src/main.cpp", 'QApplication::setApplicationName("TaliabuVPN");')
require("src/ui/mainWindow/mainwindow_setup.cpp", 'software_name = "TaliabuVPN";')
require("script/deploy_windows.sh", '$DEST/TaliabuVPN.exe')
require("cmake/windows/windows.cmake", 'ORIGINAL_FILENAME "TaliabuVPN.exe"')
require("core/internal/parentcheck/parentcheck.go", '"TaliabuVPN.exe"')
require("src/ui/stats/RuntimeStatsWidget.cpp", '"TaliabuVPN"')
require("src/database/SettingsRepo.cpp", 'QStringLiteral("TaliabuVPN/")')
require("src/sys/windows/UrlScheme.cpp", '"FriendlyAppName", "TaliabuVPN"')
require("script/windows_installer.iss", "AppName=TaliabuVPN")
require("res/dashboard-bootstrap.html", "<title>TaliabuVPN</title>")
require("src/ui/setting/dialog_basic_settings.cpp", "TaliabuVPN-backup.thrbackup")

# Fresh-install defaults.
require("include/database/SettingsRepo.h", "bool fake_dns = true;")
require("include/database/SettingsRepo.h", "bool remember_tun = true;")
require("include/database/SettingsRepo.h", "bool remember_enable = true;")

# Application self-update must stay removed. Subscription/ruleset refreshers are intentionally untouched.
for rel in [
    "include/ui/mainwindow.h",
    "include/ui/mainwindow.ui",
    "src/ui/mainWindow/mainwindow_setup.cpp",
    "src/ui/mainWindow/mainwindow_system.cpp",
    "script/build_go.sh",
    "script/windows_installer.iss",
]:
    for needle in ["RunUpdater", "CheckUpdate", "mu_download_update", "updater.exe", "updater.old", "throneproj/updater"]:
        forbid(rel, needle)
for rel in [
    "include/database/SettingsRepo.h",
    "src/database/SettingsRepo.cpp",
    "src/ui/setting/dialog_basic_settings.cpp",
    "include/ui/setting/dialog_basic_settings.ui",
]:
    forbid(rel, "allow_beta_update")
    forbid(rel, "allow_beta")

# Bilingual portable documentation.
readme = text("README_TaliabuVPN_CN-ID.txt")
for needle in ["TaliabuVPN", "【中文】", "【Bahasa Indonesia】", "FakeIP", "TUN"]:
    if needle not in readme:
        errors.append(f"README_TaliabuVPN_CN-ID.txt: missing {needle!r}")
if "Throne" in readme:
    errors.append("README_TaliabuVPN_CN-ID.txt: original app brand leaked into user README")

# Exact customized icon assets.
expected_sha256 = {
    "res/Throne.ico": "5cedf2da29003e15454f234f7873de1a9e0b0407bedfd5db1058ac6079665720",
    "res/Throne.icns": "5a4c26e4eda290e03c99bbc7428ca27cdb66d7db16167d2cad12c369b08e61b6",
    "res/ThroneDel.ico": "5cedf2da29003e15454f234f7873de1a9e0b0407bedfd5db1058ac6079665720",
    "res/public/Dns.png": "df478bcecb751ff82c9afb4b01b09025e1b1f23832c23a62faeadba1967ceb37",
    "res/public/Off.png": "df478bcecb751ff82c9afb4b01b09025e1b1f23832c23a62faeadba1967ceb37",
    "res/public/Proxy-Dns.png": "df478bcecb751ff82c9afb4b01b09025e1b1f23832c23a62faeadba1967ceb37",
    "res/public/Proxy.png": "df478bcecb751ff82c9afb4b01b09025e1b1f23832c23a62faeadba1967ceb37",
    "res/public/Throne.png": "df478bcecb751ff82c9afb4b01b09025e1b1f23832c23a62faeadba1967ceb37",
    "res/public/Tun.png": "df478bcecb751ff82c9afb4b01b09025e1b1f23832c23a62faeadba1967ceb37",
}
for rel, expected in expected_sha256.items():
    actual = hashlib.sha256((ROOT / rel).read_bytes()).hexdigest()
    if actual != expected:
        errors.append(f"{rel}: icon SHA-256 changed: {actual}")

if errors:
    print("TaliabuVPN customization verification FAILED:", file=sys.stderr)
    for error in errors:
        print(f" - {error}", file=sys.stderr)
    sys.exit(1)

print("TaliabuVPN customization verification passed.")
