#!/usr/bin/env python3
import datetime
import os
import shlex
import subprocess
import sys


def get_ps():
    winpath = subprocess.check_output(["wslvar", "PATH"]).decode().strip()
    for p in winpath.split(";"):
        wslpath = subprocess.check_output(["wslpath", "-u", p]).decode().strip()
        ps = os.path.join(wslpath, "powershell.exe")
        if os.path.exists(ps):
            break
    assert ps
    return shlex.quote(ps)


if __name__ == "__main__":
    output = subprocess.check_output(["wslpath", "-m", sys.argv[1]]).decode().strip()

    cmd = f"""{get_ps()} \"
            Add-Type -AssemblyName System.Windows.Forms
            \$result = [System.Windows.Forms.MessageBox]::Show(\\\"Done?\\\", \\\"Use Win+Shift+s\\\", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::None)
            \$img = [Windows.Forms.Clipboard]::GetImage()
            \$img.Save(\\\"{output}\\\", [Drawing.Imaging.ImageFormat]::PNG)\"
    """
    os.system(cmd)
