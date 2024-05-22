import glob
import os


os.chdir(os.path.dirname(__file__))
os.system("git submodule update --init --recursive")
dotfiles = glob.glob(".*") + ["bin", "texmf"]


for dotfile in dotfiles:
    if os.path.isdir(dotfile):
        for dirpath, dirnames, filenames in os.walk(dotfile):
            dirpath = os.path.relpath(dirpath, os.getcwd())
            os.makedirs(os.path.join(os.path.expanduser("~"), dirpath), exist_ok=True)
            for filename in filenames:
                dst = os.path.join(os.path.expanduser("~"), dirpath, filename)
                src = os.path.join(dirpath, filename)
                src = os.path.relpath(src, os.path.dirname(dst))
                if os.path.exists(dst) or os.path.islink(dst):
                    os.remove(dst)
                print(dst, "->", src)
                os.symlink(src, dst)
    else:
        dst = os.path.join(os.path.expanduser("~"), dotfile)
        src = os.path.relpath(dotfile, os.path.dirname(dst))
        if os.path.exists(dst) or os.path.islink(dst):
            os.remove(dst)
        print(dst, "->", src)
        os.symlink(src, dst)
