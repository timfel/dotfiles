set history save on
handle SIGSEGV nostop print pass
directory ..
set substitute-path ./graalpython/mxbuild/linux-amd64-jdk25/com.oracle.graal.python.cext/amd64/ .
source ~/.gdb/graalpy.py
