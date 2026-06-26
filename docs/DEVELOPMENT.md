# Development Notes

Practical notes for working on Vocalinux from a source checkout. These cover
non-obvious gotchas that are easy to lose time on.

## Install editable when developing

Install the package in editable mode so edits under `src/` take effect at
runtime:

```bash
venv/bin/pip install -e .
```

If the package is installed as a **non-editable copy**, both the running app
and the test suite import the stale copy from `site-packages/vocalinux/...`,
so changes you make in `src/` silently do nothing until you reinstall. The
`./install.sh --dev` flow installs editable for this reason — if you installed
without `--dev` (or copied the package in some other way), re-run the editable
install above.

Quick check of which copy is live:

```bash
venv/bin/python -c "import vocalinux.ui.first_run_dialog as m; print(m.__file__)"
# should print a path under src/, not under site-packages/
```

## Running the tests

```bash
venv/bin/pip install -e ".[dev]"   # pytest + plugins
pytest
```

### Python version caveat (3.13+)

Four tests in `tests/test_ibus_engine_core.py::TestVocalinuxEngine`
(`do_enable`, `do_disable`, `do_focus_in`, `do_focus_out`) fail on
**Python 3.14** with:

```
TypeError: VocalinuxEngine.__init__() got an unexpected keyword argument 'name'
```

This is a **test-harness artifact, not a product bug**. Those tests mock
`IBus.Engine` as a `MagicMock`, so `VocalinuxEngine` ends up subclassing
`MagicMock`. Python 3.14's `unittest.mock` now passes `name=` into the parent
type when it synthesizes magic methods (e.g. `__eq__`, exercised by
`assertEqual`), and the engine's no-argument `__init__` rejects it. The same
tests pass on Python ≤3.12. The real runtime is unaffected because in
production `IBus.Engine` is the genuine GObject base class, not a mock.

## Launcher wrappers and the `sg input` elevation

The generated launcher wrappers (`~/.local/bin/vocalinux` and
`vocalinux-gui`) need access to `/dev/input/event*` for the evdev keyboard
shortcut backend on Wayland. When the current session is not yet in the
`input` group, the wrapper re-execs itself under that group:

```bash
exec sg input -c "... \"$VENV_DIR/bin/vocalinux\" $*"
```

`sg` is a setuid binary (a symlink to `newgrp`). When glibc execs a setuid
binary it enters **secure-execution mode** and strips `LD_*` variables from
the environment. That silently removes `LD_LIBRARY_PATH`, which can break
loading of native libraries (e.g. whisper.cpp's `libwhisper`/`libggml`) when
they are resolved via that path rather than an embedded RPATH.

The wrappers therefore **re-inject the needed variables inside the `sg -c`
command string** so they survive the group switch:

```bash
exec sg input -c "GI_TYPELIB_PATH=\"$GI_TYPELIB_PATH\" LD_LIBRARY_PATH=\"$LD_LIBRARY_PATH\" \"$VENV_DIR/bin/vocalinux\" $*"
```

(`GI_TYPELIB_PATH` is not actually stripped by `sg`, but is passed for safety;
`LD_LIBRARY_PATH` is the one that matters.) If you edit this logic, edit it in
the `install.sh` wrapper templates — the files in `~/.local/bin` are generated
from them.

`detect_typelib_path()` in `install.sh` collects **all** matching
`girepository-1.0` directories into a `:`-separated list rather than returning
only the first, for better cross-distro coverage.

## GTK first-run dialog

`FirstRunDialog.do_response` must **not** chain up via
`Gtk.Dialog.do_response(self, response_id)`. On some PyGObject/GTK builds
`response` is exposed only as a signal, not as an invokable class vfunc, and
chaining up raises `Class GtkDialog doesn't implement response`. The dialog is
driven by `run()` + `destroy()`, so the default handler is not needed.
