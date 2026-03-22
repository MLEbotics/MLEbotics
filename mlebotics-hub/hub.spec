# PyInstaller spec for MLEbotics Hub
# Build:  pyinstaller hub.spec
# Output: dist\MLEbotics Hub\MLEbotics Hub.exe

import os
block_cipher = None

a = Analysis(
    ['hub.py'],
    pathex=['.'],
    binaries=[],
    datas=[
        ('../hey-girl',      'hey-girl'),
        ('../Computer-Use',  'Computer-Use'),
        ('../AutoFormFiller','AutoFormFiller'),
    ],
    hiddenimports=[
        # hey-girl
        'openai', 'pyttsx3', 'speech_recognition', 'pvporcupine',
        # computer-use
        'anthropic', 'pyautogui', 'PIL', 'mss',
        # autoformfiller / flask
        'flask', 'flask_cors', 'werkzeug', 'werkzeug.serving',
        'google.generativeai',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='MLEbotics Hub',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,          # no black console window
    disable_windowed_traceback=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='MLEbotics Hub',
)
