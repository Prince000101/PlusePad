# -*- mode: python ; coding: utf-8 -*-
# PyInstaller spec for the PulsePad Control Center.
#
# OneFile build: produces a SINGLE, standalone, double-clickable app with no
# Python required on the target machine. You can drop it on the Desktop or
# anywhere and run it.
#   - Linux   -> a single executable  (dist/PulsePad)
#   - Windows -> a single .exe        (dist/PulsePad.exe)
#   - macOS   -> a single .app bundle (dist/PulsePad.app)
#   (macOS produces a bundle because that's how PyInstaller onefile works there)
#
# Build (run on each OS separately to produce that OS's binary):
#   pyinstaller packaging/pulsepad_gui.spec

import os

# PyInstaller exec()s this spec, so os.path.dirname(__file__) is unavailable.
# SPECPATH is defined by PyInstaller and points to the spec file's directory.
here = os.path.abspath(SPECPATH)
daemon = os.path.abspath(os.path.join(here, "..", "daemon"))

a = Analysis(
    [os.path.join(daemon, "pulsepad_gui.py")],
    pathex=[daemon],
    binaries=[],
    datas=[],
    hiddenimports=[
        "pulsepad.protocol",
        "pulsepad.server",
        "pulsepad.virtual_device",
        "pulsepad.qr_config",
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=["tests", "unittest", "pytest"],
    noarchive=False,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name="PulsePad",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,   # windowed: no console window on Windows
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
