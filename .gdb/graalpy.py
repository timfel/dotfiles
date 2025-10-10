import gdb


def eval_safely(s):
    try:
        return gdb.parse_and_eval(s)
    finally:
        gdb.parse_and_eval("PyErr_Clear()")


class PyObjectPtrPrinter(object):
    indent = 1

    def __init__(self, val):
        self.val = val

    def to_string(self):
        ptrval = int(self.val)
        if ptrval != 0:
            if ptrval & (1 << 63):
                handle_type = "managed handle"
            else:
                handle_type = "native memory"
            pytype = gdb.lookup_type('PyObject').pointer()
            obj = gdb.Value(ptrval).cast(pytype)
            try:
                tp = eval_safely(f"Py_TYPE((PyObject *) 0x{ptrval:x})")
                tptype = tp.dereference()
                tpname = tptype['tp_name'].string()
                printstring = f"({self.val.type}) 0x{ptrval:x} ({handle_type}, type: {tpname}"
                if tpname == "tuple":
                    size = int(eval_safely(f"PyObject_Size((PyObject *) 0x{ptrval:x})"))
                    if size < 5:
                        printstring += ", [\n"
                        for i in range(size):
                            item = eval_safely(f"PyTuple_GetItem((PyObject *) 0x{ptrval:x}, {i})")
                            PyObjectPtrPrinter.indent += 1
                            try:
                                itemstring = PyObjectPtrPrinter(item).to_string()
                            finally:
                                PyObjectPtrPrinter.indent -= 1
                            printstring += "    " * PyObjectPtrPrinter.indent
                            printstring += f"{itemstring}\n"
                        printstring += "    " * (PyObjectPtrPrinter.indent - 1)
                        printstring += "])"
                    else:
                        printstring += f", size: {size}"
                elif tpname == "str":
                    printstring += ", `" + str(eval_safely(f"PyUnicode_AsUTF8((PyObject *) 0x{ptrval:x})")) + "'"
                elif tpname == "float":
                    printstring += ", `" + str(eval_safely(f"PyFloat_AsDouble((PyObject *) 0x{ptrval:x})")) + "'"
                elif tpname == "type" or eval_safely(f"PyType_Check((PyObject *) 0x{ptrval:x})") == 1:
                    printstring += ", `" + str(eval_safely(f"PyUnicode_AsUTF8(PyType_GetName((PyObject *) 0x{ptrval:x}))")) + "'"
                return printstring + ")"
            except Exception as e:
                return f"({self.val.type}) 0x{ptrval:x} ({handle_type}, error reading type: {e})"
        return f"({self.val.type}) 0x{ptrval:x}"


def pyobject_ptr_lookup(val):
    import re
    type_ = val.type
    typename = str(type_.strip_typedefs())
    if re.match(r"Py([A-Z][a-zA-Z_]+)?Object \*", typename) or typename == 'struct _object *':
        return PyObjectPtrPrinter(val)
    return None


def register_graalpy_printers(objfile):
    if objfile is None:
        objfile = gdb
    gdb.printing.register_pretty_printer(objfile, pyobject_ptr_lookup)


def unregister_graalpy_printers(objfile):
    if objfile is None:
        objfile = gdb
    gdb.printing.unregister_pretty_printer(objfile, pyobject_ptr_lookup)


class PpCommand(gdb.Command):
    """
    Pretty print a GraalPy PyObject pointer value.
    Usage: pp <expr>
    """
    def __init__(self):
        super().__init__("pp", gdb.COMMAND_DATA)

    def invoke(self, arg, from_tty):
        val = gdb.parse_and_eval(arg)
        printer = PyObjectPtrPrinter(val)
        print(printer.to_string())


class EnableGraalpyPrintersCommand(gdb.Command):
    """
    Enable GraalPy pretty-printers.
    """
    def __init__(self):
        super().__init__("enable-graalpy-printers", gdb.COMMAND_DATA)

    def invoke(self, arg, from_tty):
        register_graalpy_printers(None)
        print("GraalPy pretty-printers enabled.")


class DisableGraalpyPrintersCommand(gdb.Command):
    """
    Disable GraalPy pretty-printers.
    """
    def __init__(self):
        super().__init__("disable-graalpy-printers", gdb.COMMAND_DATA)

    def invoke(self, arg, from_tty):
        unregister_graalpy_printers(None)
        print("GraalPy pretty-printers disabled.")


# Register GDB commands on load
PpCommand()
EnableGraalpyPrintersCommand()
DisableGraalpyPrintersCommand()
