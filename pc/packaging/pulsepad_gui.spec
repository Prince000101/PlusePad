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

import glob
import os
import site
import sysconfig

# PyInstaller exec()s this spec, so os.path.dirname(__file__) is unavailable.
# SPECPATH is defined by PyInstaller and points to the spec file's directory.
here = os.path.abspath(SPECPATH)
daemon = os.path.abspath(os.path.join(here, ".."))

# python-uinput 1.x loads its C core "_libsuinput" via ctypes.CDLL() from the
# SITE-PACKAGES ROOT (see uinput/__init__.py:get_libsuinput_path), NOT from
# inside the uinput/ package dir. PyInstaller does not collect top-level .so
# modules, so bundle it explicitly. In the one-file app ctypes resolves it to
# the bundle root (the /tmp/_MEI* dir), so it must land there; the copy under
# uinput/ is a safety net for environments where __file__ resolves differently.
_suinput_libs = []
for _dir in {sysconfig.get_paths().get("purelib"),
             sysconfig.get_paths().get("platlib"),
             getattr(site, "USER_SITE", None)}:
    if not _dir:
        continue
    for _so in glob.glob(os.path.join(os.path.abspath(_dir), "_libsuinput*")):
        _suinput_libs.append((_so, "."))
        _suinput_libs.append((_so, "uinput"))

a = Analysis(
    [os.path.join(daemon, "pulsepad_gui.py")],
    pathex=[daemon],
    binaries=_suinput_libs,
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
    excludes=[
        "tests",
        "unittest",  # safely re-importable from stdlib if ever needed
        "pytest",
        "pydoc_data",
        "pydoc",
        "doctest",
        "pdb",
        "http.server",
        "tkinter.test",
    ],
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
    strip=True,      # drop debug symbols -> noticeably smaller binary
    upx=False,       # upx not required; strips already shrink enough
    console=False,   # windowed: no console window on Windows
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
