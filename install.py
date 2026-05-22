from glob import glob
from os import makedirs, chdir, system, walk, getcwd, unlink, symlink, readlink
from os.path import join, basename, isdir, expanduser, relpath, dirname, exists, islink



chdir(dirname(__file__))
system("git submodule update --init --recursive")
dotfiles = glob(".*") + ["bin", "texmf"]


def install_link(src, dst):
    if islink(src):
        src = readlink(src)
    else:
        src = relpath(src, dirname(dst))
    if exists(dst) or islink(dst):
        unlink(dst)
    print(dst, "->", src)
    symlink(src, dst)


for dotfile in dotfiles:
    dst = join(expanduser("~"), dotfile)
    if not islink(dotfile) and isdir(dotfile) and (
            basename(dotfile).startswith(".") or
            isdir(dst)
    ):
        for dirpath, dirnames, filenames in walk(dotfile):
            dirpath = relpath(dirpath, getcwd())
            if dirpath.startswith(".git"):
                continue
            makedirs(join(expanduser("~"), dirpath), exist_ok=True)
            for dirname_ in list(dirnames):
                src = join(dirpath, dirname_)
                if islink(src):
                    dst = join(expanduser("~"), dirpath, dirname_)
                    install_link(src, dst)
                    dirnames.remove(dirname_)
            for filename in filenames:
                dst = join(expanduser("~"), dirpath, filename)
                src = join(dirpath, filename)
                install_link(src, dst)
    else:
        dst = join(expanduser("~"), dotfile)
        install_link(dotfile, dst)
