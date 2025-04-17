#!/usr/bin/env python3
import datetime
import os
import shlex
import subprocess
import sys


def get_ps():
    if sys.platform == "win32":
        winpath = os.environ.get("PATH")
    else:
        winpath = subprocess.check_output(["wslvar", "PATH"]).decode().strip()
    for p in winpath.split(";"):
        if sys.platform == "win32":
            wslpath = p
        else:
            wslpath = subprocess.check_output(["wslpath", "-u", p]).decode().strip()
        ps = os.path.join(wslpath, "powershell.exe")
        if os.path.exists(ps):
            break
    assert ps
    if sys.platform == "win32":
        return ps.replace("\\", "/")
    else:
        return shlex.quote(ps)


if __name__ == "__main__":
    if sys.platform == "win32":
        output = os.path.abspath(sys.argv[1].replace("\\", "/"))
        with open(output + ".ps1", "w") as f:
            f.write(f"""
            Add-Type -AssemblyName System.Windows.Forms
            $result = [System.Windows.Forms.MessageBox]::Show("Done?", "Use Win+Shift+s", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::None)
            $img = [Windows.Forms.Clipboard]::GetImage()
            $img.Save("{output}", [Drawing.Imaging.ImageFormat]::PNG)
            """)
        os.system(get_ps() + " " + output + ".ps1")
        os.unlink(output + ".ps1")
    else:
        output = subprocess.check_output(["wslpath", "-m", sys.argv[1]]).decode().strip()
        cmd = f"""{get_ps()} \"
                Add-Type -AssemblyName System.Windows.Forms
                \\$result = [System.Windows.Forms.MessageBox]::Show(\\\"Done?\\\", \\\"Use Win+Shift+s\\\", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::None)
                \\$img = [Windows.Forms.Clipboard]::GetImage()
                \\$img.Save(\\\"{output}\\\", [Drawing.Imaging.ImageFormat]::PNG)\"
        """
        os.system(cmd)
