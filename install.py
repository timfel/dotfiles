from glob import glob
from os import makedirs, chdir, system, walk, getcwd
from os.path import join, basename, isdir, expanduser, relpath, dirname, exists, islink, remove, symlink


chdir(dirname(__file__))
system("git submodule update --init --recursive")
dotfiles = glob(".*") + ["bin", "texmf"]


for dotfile in dotfiles:
    dst = join(expanduser("~"), dotfile)
    if isdir(dotfile) and (
            basename(dotfile).startswith(".") or
            isdir(dst)
    ):
        for dirpath, dirnames, filenames in walk(dotfile):
            dirpath = relpath(dirpath, getcwd())
            makedirs(join(expanduser("~"), dirpath), exist_ok=True)
            for filename in filenames:
                dst = join(expanduser("~"), dirpath, filename)
                src = join(dirpath, filename)
                src = relpath(src, dirname(dst))
                if exists(dst) or islink(dst):
                    remove(dst)
                print(dst, "->", src)
                symlink(src, dst)
    else:
        dst = join(expanduser("~"), dotfile)
        src = relpath(dotfile, dirname(dst))
        if exists(dst) or islink(dst):
            remove(dst)
        print(dst, "->", src)
        symlink(src, dst)
