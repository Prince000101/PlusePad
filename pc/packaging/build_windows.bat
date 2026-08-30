@echo off
REM Build the PulsePad Control Center as a single .exe for Windows.
REM Run this on a Windows machine. Produces: dist\PulsePad.exe
setlocal

REM --- optional: use a project-local venv to avoid polluting your Python ---
if not exist ".venv" (
    echo [1/3] Creating virtual environment...
    python -m venv .venv
)
call .venv\Scripts\activate.bat

echo [2/3] Installing build dependencies...
pip install --upgrade pip
pip install pyinstaller

echo [3/3] Building PulsePad.exe...
pyinstaller packaging\pulsepad_gui.spec --noconfirm --clean

echo.
echo Done! Your portable app is at:
echo   dist\PulsePad.exe
echo Copy it to your Desktop or anywhere and double-click to run.
pause
