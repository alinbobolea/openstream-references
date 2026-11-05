"""Write facts about the machine and about CoolProp to a text file.

Usage: python support/runnerDiagnostics.py OUTFILE

Run by the workflow on the runner before MATLAB starts, with plain Python and
the CoolProp that pip installed. It records what could make the numbers of
CoolProp differ between two machines: the Python and CoolProp versions, the
CoolProp extension module and the libraries it loads (with sha256), the wheel
pip downloads for the installed version (with sha256), the processor, the C
library, and the values CoolProp gives for water at three system pressures,
as exact hexadecimal floats and as repr.

The values follow the calls the fluid property class makes for one pressure,
in its order: on a state with the saturation flag set, the saturation
temperature, densities, viscosities and enthalpies; the surface tension on a
new exact-backend state; on a new state without the flag, the conductivities,
specific heats and Prandtl numbers; then the minimum and maximum enthalpies
(pressure-temperature lookups at the minimum temperature plus 1 K and the maximum
temperature minus 1 K) and the critical, triple and limiting values. Not
recorded: the first state the class builds (replaced at once), the loops of
the class over the whole pressure vector (here one pressure at a time), and
the search for the largest characteristic heat flux over pressure (fminbnd).
The exact backend is also run through the same sequence, for comparison; the
class does not use it for these values.

Every part is run on its own: an error in one writes an ERROR line into the
file and the others still run; so does a command that exits with a code other
than 0, that does not finish in time or that cannot start. The script always
exits 0. It points HOME at a throwaway folder, so the tables CoolProp builds
are not the ones a later MATLAB session uses, and the tables built here are
listed in the file.
"""

import base64
import hashlib
import importlib.metadata
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
from collections.abc import Callable
from pathlib import Path

FLUID = "WATER"
PRESSURES = (6000000.0, 4410000.0, 6950000.0)
BACKENDS = ("BICUBIC&HEOS", "HEOS")
CLASS_BACKEND = "BICUBIC&HEOS"

lines: list[str] = []


def emit(text: str = "") -> None:
    lines.append(text)


def part(title: str, body: Callable[[], None]) -> None:
    """Run BODY under a heading; an error becomes a line of the file."""
    emit()
    emit(f"== {title}")
    try:
        body()
    except BaseException as error:  # noqa: BLE001 - every error is data here
        emit(f"ERROR {type(error).__name__}: {error}")


def sha256(path: str | Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def command(arguments: list[str], timeout: float = 60) -> str:
    """Output (stdout, then stderr) of a command, stripped.

    An exit code other than 0, a command that is not finished after TIMEOUT
    seconds and a command that cannot start each write an ERROR line; the
    text is then what the command printed, or empty.
    """
    label = " ".join(arguments)
    try:
        done = subprocess.run(
            arguments, capture_output=True, text=True, timeout=timeout, check=False
        )
    except subprocess.TimeoutExpired:
        emit(f"ERROR command timed out after {timeout} s: {label}")
        return ""
    except OSError as error:
        emit(f"ERROR command could not start: {label}: {error}")
        return ""
    if done.returncode != 0:
        emit(f"ERROR command exited with code {done.returncode}: {label}")
    return f"{done.stdout}{done.stderr}".strip()


def value(label: str, getter: Callable[[], float]) -> None:
    """One number as an exact hexadecimal float and as repr; or its error."""
    try:
        number = float(getter())
        emit(f"{label}: {number.hex()}  {number!r}")
    except BaseException as error:  # noqa: BLE001 - every error is data here
        emit(f"{label}: ERROR {type(error).__name__}: {error}")


def python_facts() -> None:
    emit(f"python: {sys.version}")
    emit(f"executable: {sys.executable}")
    emit(f"platform: {platform.platform()}")
    emit(f"machine: {platform.machine()}")


def uname_facts() -> None:
    emit(command(["uname", "-a"]) or "uname: no output")


def cpu_facts() -> None:
    text = Path("/proc/cpuinfo").read_text(encoding="utf-8", errors="replace")
    for key in ("model name", "flags"):
        found = re.search(rf"^{key}[ \t]*:.*$", text, re.MULTILINE)
        emit(found.group(0) if found else f"{key}: not found")


def glibc_facts() -> None:
    output = command(["ldd", "--version"]).splitlines()
    emit("ldd --version: " + (output[0] if output else "no output"))


def library_facts(module_file: str) -> None:
    listing = command(["ldd", module_file])
    emit("ldd of the extension module (load addresses removed):")
    for line in listing.splitlines():
        emit("  " + re.sub(r"\s*\(0x[0-9a-fA-F]+\)", "", line))
    emit("libraries as loaded, with sha256 of the file:")
    for line in listing.splitlines():
        found = re.match(r"\s*(\S+)\s+=>\s+(/\S+)", line)
        if found:
            real = os.path.realpath(found.group(2))
            emit(f"  {found.group(1)} -> {real}  {sha256(real)}")


def coolprop_facts() -> None:
    import CoolProp
    import CoolProp.CoolProp as module

    emit(f"CoolProp.__version__: {CoolProp.__version__}")
    emit("version (library): " + str(module.get_global_param_string("version")))
    module_file = module.__file__
    emit(f"extension module: {module_file}")
    emit(f"extension module sha256: {sha256(module_file)}")
    part("libraries of the extension module", lambda: library_facts(module_file))
    part("record of the installed package", lambda: record_facts(module_file))
    part("wheel of the installed version", wheel_facts)


def record_facts(module_file: str) -> None:
    """The hash the installed package's RECORD lists for the module file."""
    distribution = importlib.metadata.distribution("CoolProp")
    name = distribution.metadata["Name"]
    emit(f"installed distribution: {name} {distribution.version}")
    for entry in distribution.files or []:
        if str(distribution.locate_file(entry)) == module_file and entry.hash:
            emit(f"RECORD entry: {entry}  {entry.hash.mode}={entry.hash.value}")
            digest = hashlib.sha256(Path(module_file).read_bytes()).digest()
            encoded = base64.urlsafe_b64encode(digest).decode().rstrip("=")
            same = encoded == entry.hash.value
            emit(f"RECORD hash equals the hash of the file: {same}")
            return
    emit("RECORD entry for the module file: not found")


def wheel_facts() -> None:
    version = importlib.metadata.version("CoolProp")
    emit(command([sys.executable, "-m", "pip", "--version"]))
    folder = tempfile.mkdtemp(prefix="wheel-")
    try:
        output = command(
            [
                sys.executable,
                "-m",
                "pip",
                "download",
                "--no-deps",
                "--only-binary=:all:",
                "--dest",
                folder,
                f"CoolProp=={version}",
            ],
            timeout=180,
        )
        emit("pip download, last lines:")
        for line in output.splitlines()[-3:]:
            emit("  " + line)
        names = sorted(os.listdir(folder))
        for name in names:
            digest = sha256(os.path.join(folder, name))
            emit(f"downloaded wheel: {name}  sha256 {digest}")
        if not names:
            emit("no wheel was downloaded")
    finally:
        shutil.rmtree(folder, ignore_errors=True)


def class_sequence(backend: str, pressure: float) -> None:
    """The calls of the fluid property class for one pressure, in its order."""
    import CoolProp

    tag = f"{backend} P={pressure!r}"
    emit(f"-- {tag}")

    def new_state() -> "CoolProp.AbstractState":
        return CoolProp.AbstractState(backend, FLUID)

    def read(
        state: "CoolProp.AbstractState",
        label: str,
        quality: float,
        getter: Callable[[], float],
    ) -> None:
        def get() -> float:
            state.update(CoolProp.PQ_INPUTS, pressure, quality)
            return getter()

        value(f"{tag} {label} (Q={quality})", get)

    # The state with the saturation flag set.
    try:
        state = new_state()
        state.specify_phase(CoolProp.iphase_twophase)
    except BaseException as error:  # noqa: BLE001 - data
        emit(f"{tag}: ERROR {type(error).__name__}: {error}")
        return
    read(state, "TSAT", 1.0, state.T)
    read(state, "RHOF", 0.0, state.rhomass)
    read(state, "RHOG", 1.0, state.rhomass)
    read(state, "MUF", 0.0, state.viscosity)
    read(state, "MUG", 1.0, state.viscosity)
    read(state, "HF", 0.0, state.hmass)
    read(state, "HG", 1.0, state.hmass)

    # The surface tension, on a new exact-backend state.
    if backend == CLASS_BACKEND:

        def sigma() -> float:
            exact = CoolProp.AbstractState("HEOS", FLUID)
            exact.update(CoolProp.PQ_INPUTS, pressure, 1.0)
            return exact.surface_tension()

        value(f"{tag} SIGMA (Q=1.0, new HEOS state)", sigma)

    # A new state of the backend, without the saturation flag.
    try:
        state = new_state()
    except BaseException as error:  # noqa: BLE001 - data
        emit(f"{tag}: ERROR {type(error).__name__}: {error}")
        return
    read(state, "KF", 0.0, state.conductivity)
    read(state, "KG", 1.0, state.conductivity)
    read(state, "CPF", 0.0, state.cpmass)
    read(state, "CPG", 1.0, state.cpmass)
    read(state, "PRANDTLF", 0.0, state.Prandtl)
    read(state, "PRANDTLG", 1.0, state.Prandtl)

    # The flag is cleared, then pressure-temperature lookups at the limits.
    try:
        state.specify_phase(CoolProp.iphase_not_imposed)
    except BaseException as error:  # noqa: BLE001 - data
        emit(f"{tag}: ERROR {type(error).__name__}: {error}")

    def limit(offset: float, which: Callable[[], float]) -> Callable[[], float]:
        def get() -> float:
            state.update(CoolProp.PT_INPUTS, pressure, which() + offset)
            return state.hmass()

        return get

    value(f"{tag} HMIN (PT_INPUTS, T=Tmin+1 K)", limit(1.0, state.Tmin))
    value(f"{tag} HMAX (PT_INPUTS, T=Tmax-1 K)", limit(-1.0, state.Tmax))


def saturation_values() -> None:
    import CoolProp
    import CoolProp.CoolProp as module

    emit("Sequence of the fluid property class for one pressure (see the top")
    emit("of runnerDiagnostics.py). Not recorded: the class's first state, its")
    emit("loops over a whole pressure vector, and its fminbnd search over pressure.")
    for backend in BACKENDS:
        if backend != CLASS_BACKEND:
            emit(f"(the same sequence on {backend}, for comparison only)")
        for pressure in PRESSURES:
            try:
                class_sequence(backend, pressure)
            except BaseException as error:  # noqa: BLE001 - data
                emit(f"{backend} P={pressure!r}: ERROR {type(error).__name__}: {error}")

    state = CoolProp.AbstractState(CLASS_BACKEND, FLUID)
    value("PCRIT", state.p_critical)
    value("TMIN", state.Tmin)
    value("TMAX", state.Tmax)
    value("PTRIPLE", lambda: module.PropsSI("ptriple", FLUID))


def table_facts(home: str) -> None:
    root = Path(home) / ".CoolProp"
    emit(f"tables built by this run, under {root} (relative path, bytes, sha256):")
    found = sorted(p for p in root.rglob("*") if p.is_file())
    for path in found:
        emit(f"  {path.relative_to(root)}  {path.stat().st_size}  {sha256(path)}")
    if not found:
        emit("  none")


def main() -> None:
    target = sys.argv[1] if len(sys.argv) > 1 else "runner-diagnostics.txt"
    home = tempfile.mkdtemp(prefix="diagnostics-home-")
    os.environ["HOME"] = home
    os.environ["USERPROFILE"] = home
    emit("runner diagnostics (plain Python, no MATLAB)")
    emit(f"HOME for this run: a throwaway folder ({home})")
    part("python", python_facts)
    part("uname", uname_facts)
    part("processor", cpu_facts)
    part("C library", glibc_facts)
    part("CoolProp", coolprop_facts)
    part("values of the fluid property class", saturation_values)
    part("tables", lambda: table_facts(home))
    try:
        Path(target).write_text("\n".join(lines) + "\n", encoding="utf-8")
    except BaseException as error:  # noqa: BLE001 - the step must not fail
        print(f"could not write {target}: {error}", file=sys.stderr)
        print("\n".join(lines))
    shutil.rmtree(home, ignore_errors=True)


if __name__ == "__main__":
    try:
        main()
    except BaseException as error:  # noqa: BLE001 - the step must not fail
        print(f"runner diagnostics failed: {error}", file=sys.stderr)
    sys.exit(0)
