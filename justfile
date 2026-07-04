# Vocalinux dev shortcuts — run `just` to list recipes

venv := justfile_directory() + "/venv/bin"

# List available recipes
default:
    @just --list

# Run the app via the installed launcher (input-group elevation + env fixes)
vocalinux *args:
    ~/.local/bin/vocalinux {{args}}

# Run the GUI launcher (same as the desktop entry)
gui *args:
    ~/.local/bin/vocalinux-gui {{args}}

# Run straight from the venv with debug logging (no input-group elevation)
debug:
    {{venv}}/vocalinux --debug

# Run the test suite (4 ibus_engine_core failures are a known Python 3.14 mock artifact)
test *args:
    {{venv}}/python -m pytest tests/ {{args}}

# Reinstall the package editable into the venv (required after pulling packaging changes)
install:
    {{venv}}/pip install -e .
