# openstream-references

MATLAB reference results for [OpenSTREAM](https://github.com/OpenSTREAM-solvers/openstream)
cases, computed with the unmodified upstream code on GitHub-hosted runners.

This repository stores no OpenSTREAM code. Each run checks out OpenSTREAM at
a pinned commit, runs the cases listed in `cases/`, and saves the results in
a plain format that any MAT-file reader can open.

## What runs

- OpenSTREAM commit `a614c7173822a93c1e64ac28d1541cbac028cbd8` (tag
  `v2026.0`), with its `+CoolPropWrapper` submodule.
- OpenSTREAM-database commit `b48541e6438a92b4c0ddc83cf0ceda3f71a59b22`
  (tag `v2026.0.0`), for the dataset-driven cases.
- MATLAB R2026b on the GitHub-hosted `ubuntu-24.04` runner image; the
  `input-fixture-windows` cases also run on the `windows-2025` image (see
  [Windows job](#windows-job)).
- CoolProp 8.0.0, installed from upstream's
  `+CoolPropWrapper/requirements.txt`.

## Layout

| Path | Contents |
|---|---|
| `cases/` | Case lists (JSON). Input-file cases name the upstream input files and IDs; dataset cases name a database dataset, a record (`testID`), a solver and model/option overrides; `input-fixture.json` lists the input-parsing cases, and `input-fixture/` holds the input files written for them; `input-fixture-windows.json` lists the path cases that also run on Windows |
| `matlab/` | Scripts that run the cases and export the results |
| `support/` | `runnerDiagnostics.py`, run by the workflow on the runner before MATLAB starts (see [Runner diagnostics](#runner-diagnostics)); `warningRecorder/`, a function file used while the session cases record warnings |
| `tests/` | MATLAB unit tests for the export scripts |
| `results/` | Exported results, one folder per case list |
| `fixtures/` | A format fixture with known values, for checking MAT-file readers |
| `.github/workflows/references.yml` | The workflow that runs the tests and the cases |

## Output format

Results contain plain MATLAB types only (numeric, logical, char, cell and
struct arrays; no classdef objects) and are saved with `save(..., "-v7")`.
Each result file holds one variable, `result`, with these fields:

- `caseDef`: the case-list entry.
- `solverClass`: the solver class name.
- `state`: the final solver state, e.g. `INITIALSTEPCONVERGED`.
- `solver`: every stored property of the solver and of its field objects
  (the properties MATLAB itself saves: not dependent, transient or constant),
  converted to plain types. Each solver property is exported in full, even
  when it shares objects with another property. Enumerations become their
  member names and function handles become their text. Within one solver
  property, a handle already exported is written as `<cycle:CLASS>`; an
  object from outside OpenSTREAM is written as `<skipped:CLASS>`.
- `compared`: the mass flow rate `W`, velocity `U` and enthalpy `H` for each
  field object and stored state, read the way upstream's integration test
  reads them.

Every results folder that the case scripts write (`results/tutorial1/`,
`results/tutorial1-upstream/`, `results/nuthos15-bartolomey/`,
`results/input-fixture/`, `results/semantics-fixture/` and
`results/input-fixture-windows/`) also has an `environment.json` recording
the MATLAB and CoolProp versions, the upstream commits, the runner image and the processor
model (`cpuModel`: the first `model name` of `/proc/cpuinfo` where that file
exists; on Windows, where it does not, the value of the environment variable
`PROCESSOR_IDENTIFIER`, empty if that is not set).

## Running

A push to `main` runs the MATLAB unit tests. **Actions → references → Run
workflow** also runs one target and opens a pull request with the results:

| Target | Cases | Results folder |
|---|---|---|
| `tutorial1` | `cases/tutorial1.json`: upstream's TUTORIAL1 input files, four solvers, plus a re-export of upstream's saved references | `results/tutorial1/`, `results/tutorial1-upstream/` |
| `nuthos15-bartolomey` | `cases/nuthos15-bartolomey.json`: Bartolomey records 22 and 35 from OpenSTREAM-database, Mixture solver | `results/nuthos15-bartolomey/` |
| `input-fixture` | `cases/input-fixture.json`: what OpenSTREAM's input classes and the MATLAB functions they rely on do with given input files and values, including invalid ones | `results/input-fixture/` |
| `semantics-fixture` | `cases/semantics-fixture.json`: what MATLAB functions and the CoolProp fluid properties do with given arguments, including invalid ones | `results/semantics-fixture/` |
| `extension` | `semantics-fixture` and then `input-fixture`, in one MATLAB session (if the first fails, the second still runs and the target then fails), plus the Windows job below | `results/semantics-fixture/`, `results/input-fixture/`, `results/input-fixture-windows/` |

The workflow also writes `results/<target>/pip-freeze.txt` (the Python
packages installed) and `results/<target>/runner-diagnostics.txt` (see
below), where `<target>` is the chosen target. Results from runs made before
these files were added lack them, and `results/tutorial1-upstream/` is never
one of those folders. For `extension` the folder is `results/extension/`: it
holds only these two files and has no `environment.json`; the records of that
run are in `results/semantics-fixture/`, `results/input-fixture/` and
`results/input-fixture-windows/`.

### Windows job

The target `input-fixture-windows` is not a choice of the workflow input:
only the job `windows` runs it, when the target `extension` is chosen. It runs
`exportInputFixture` over `cases/input-fixture-windows.json`, 17 `legalpath`
cases (`win_legalpath_01` to `win_legalpath_17`) whose paths are those of the
Linux cases `ext_session_01` to `ext_session_12` and `ext_session_29` to
`ext_session_33`, which stay in `cases/input-fixture.json` (their answer on
Linux is recorded too). The job runs on the `windows-2025` image with the
same upstream commits, Python and CoolProp as the Linux job, and uploads
`results/input-fixture-windows/` as the artifact `windows-results-<run id>`.
It is marked `continue-on-error`, and the `references` job runs whether it
succeeded, failed or was skipped, so a Windows failure does not lose the Linux
record; the `references` job then downloads the artifact (if there is one)
into `results/input-fixture-windows/` before it opens the pull request. The
run therefore shows as successful even when the Windows job failed: look for
`results/input-fixture-windows/` in the pull request.

### Runner diagnostics

A step of the `references` job runs `support/runnerDiagnostics.py` after the
packages are installed and before MATLAB starts, with plain Python 3.13 (no
MATLAB), and writes `results/<target>/runner-diagnostics.txt`. It records the
Python version; the CoolProp version, the path and sha256 of its extension
module, the libraries that module loads (including `libm`) with their sha256,
the hash the installed package lists for the module and the sha256 of the
wheel pip downloads for the installed version; the processor `model name` and
`flags` lines of `/proc/cpuinfo`; the C library version and `uname -a`; the
values CoolProp gives for the calls the fluid property class makes for water
at 6.0, 4.41 and 6.95 MPa, one pressure at a time, in the class's order (on
the tabulated backend it uses and, for comparison, on the exact backend; as
exact hexadecimal floats and as `repr`): the saturation values, the surface
tension from a new exact-backend state, the conductivities, specific heats
and Prandtl numbers from a new state, the minimum and maximum enthalpies
(pressure-temperature lookups at the minimum temperature plus 1 K and the maximum
temperature minus 1 K), and the critical, triple and limiting values. The file
says what is not recorded: the class's first state, its loops over a whole
pressure vector and its search for the largest heat flux over pressure.
Finally the sha256 of the tables that Python run built (in a throwaway `HOME`,
so the tables a later MATLAB session uses are not touched). Each part runs on
its own: a part that fails, and a command that exits with a code other than 0,
does not finish in time or cannot start, writes an `ERROR` line into the file,
and the step still succeeds.

## Input fixture

The `input-fixture` target records behaviour rather than a solution. Each
entry of `cases/input-fixture.json` has a unique `name`, a `kind` and the
fields its kind needs; file paths are relative to the repository root, and
numeric arguments are given as text lists, `{"double": ["0.2", "NaN", "-0"]}`,
converted with `str2double`, so that values JSON numbers cannot carry (NaN,
Inf, -0) can be written. The kinds are:

- `read` and `convert2json`: upstream's input-file parser, reading a file and
  converting it to JSON;
- `model`, `options`, `geometry` and `bc`: an input object built from a file
  and an ID (`bc` also names a geometry), with its properties recorded;
- `default` and `listprops`: an input class built without arguments, and the
  lists of its input properties;
- `write`: successive `writeInputFile` calls of an input class into one file;
  a call may give `mode`, the `fopen` mode (`w`, `a`, `r+` or `a+`), and is
  then written with that mode;
- `inputset`: a full input set and its solver-dependent properties;
- `inputsetcall`: a direct call of the input set with given name-value pairs
  (session names, folders, log mode), recording the error, the warnings and the
  files made;
- `inputsetwarnings`: an input set built while its warnings are recorded,
  taken from the console or from the files it wrote (`capture`);
- `logcalls`: a session log set up with a log mode, then a list of calls
  (`log`, `warning`, `openLog`, `openLogKeep`, `closeLog`, `readLog`,
  `readLogFilePath`, `removeFolder`), recording the error and the warnings of
  each call;
- `sessionfs`: a session folder created with what exists beforehand (nothing,
  a folder, a folder with a file, a file, a log of its own still open) and a
  parent folder (existing, missing, a file, empty), recording the files left;
- `handle`, `textscan`, `upper`, `sprintf`, `num2str`, `strcat`, `readlines`,
  `uint8`, `sum` and `sumsweep`: single MATLAB built-ins the input code
  relies on;
- `ismembertol`: one call of `ismembertol`; `ismembertolsweep`: a list of
  such calls `{a, b, tol}` in one entry, each with its own result or error,
  with the numbers given as texts;
- `legalpath`: upstream's `Session.isLegalPath`.

Some cases fail on purpose: the error is part of the record.

Arguments of `sprintf` and `strcat` (and of `write` calls) are objects with
one key: `double`, `logical`, `text`, `handle`, `strings`, `uint8` (a text
list converted with `str2double`, then `uint8`) or `matrix`
(`{"rows": 2, "double": ["1", "3", "2", "4"]}`, filled column by column).
Every list of numbers is a list of texts, as in `double`. Optional fields
select other forms of a call: `upper` takes `"as"` `char`, `string`,
`double` or `uint8` (with `values` given as `{"double": [...]}` or
`{"uint8": [...]}`) or `textscan` (upper of what `textscan(text, '%f')`
reads); `num2str` takes `values` as `{"double": [...]}` or as
`{"text": ...}`, an empty `format` for the one-argument call, `"shape"`
`row` or `column`, and `"valuesClass"` `uint8` or `string`; `sprintf` and
`num2str` take `"formatClass": "string"` to pass the format as a string.
`matlab/functionCall.m` documents each of these calls and how its result is
stored. A text field `exporterChange` on an entry only describes the form
of call it needs; the scripts ignore it. Before any case starts, the run
stops on a field an entry's kind does not use (`exporterChange` aside), a
`class` of a `default`, `listprops` or `write` entry other than `Model`,
`Options`, `Geometry` or `BoundaryConditions`, a key a `write` call does not
use (`id` and `values`, or `time`, `pressure`, `hin`, `mflow` and `values`
for `BoundaryConditions`), and the other malformed fields listed in
`matlab/validateInputFixtureList.m`. The arguments inside a `write` call are
converted only when its case runs. A badly shaped one (an argument that is
not an object with one known key, numbers that are not a list of texts, a
malformed matrix, a value list that is not `[key, argument]` pairs) then
fails the run after it saves its results, as described below. The values
themselves are not checked: a value of another type under `logical`, `text`,
`handle` or `strings`, or an unusual call `id`, is passed on, and whatever
follows, including an error from the conversion, is recorded as that case's
result or error.

`results/input-fixture/input_fixture.mat` holds one variable, `fixture`,
whose field `cases` is a cell array with one struct per manifest entry:
`name`, `kind`, `input` (the entry), `ok`, `errorId`, `errorMessage`,
`console` (everything printed, warnings included), `lastWarningId`,
`lastWarningMessage` and `result` (per kind, empty when the case failed).
For `inputset` cases the console is not captured because `evalc` disables
the diary the session log writes; their `console` is empty. The run fails
after saving its results if a case failed because of the manifest itself
(error identifier `References:InvalidInputFixture`), so that a typo in an
argument cannot pass for an intended failure.
Plain values in results go through `describeValue`, which keeps the class
and size of every level, so a string can be told from a char vector and a
row from a column; input objects are converted as in solver results.

## Dataset cases

A dataset case names a database dataset (`dataset`), a record in it
(`testID`), a solver and overrides for the dataset's default model and
numerical options (`model`, `options`). The run follows the `runBartolomey`
function of the database's NUTHOS-15 project: it generates the input files
with the dataset's `makeInputFiles`, solves with `runCase`, and exports the
solver as above. When a case has `relaxCondCoefficients = [c1 c2]`, it sets
`RELAXCONDCOEF = [c1/Re^c2, 1/3, 1.0e-4, 0.0]` with `Re` computed from the
record's mass flux and diameter and the saturated-liquid viscosity at its
pressure. Each result `<name>.mat` has a folder `<name>-inputs/` with the four
generated input files.

## Licence and credit

The scripts in this repository are released under the MIT License (see
`LICENSE`).

OpenSTREAM is developed by Jason Chan, Jean-Marie Le Corre, Roman Morse,
Elisabeth Walter, and other OpenSTREAM contributors, and is released under
the MIT License. If OpenSTREAM is used in research or published work, the
upstream project asks that the relevant OpenSTREAM publications be cited:

- J.-M. Le Corre, J. Chan, E. Walter, E. T. Hurlburt, and R. W. Morse,
  “OpenSTREAM: A new open-source platform for two-phase flow model
  development,” *12th International Conference on Multiphase Flow
  (ICMF 2025)*, Toulouse, France, May 12–16, 2025.

- J.-M. Le Corre, J. Chan, E. Walter, E. T. Hurlburt, and R. W. Morse,
  “OpenSTREAM: An open-source platform for two-phase flow modeling and
  simulation,” *21st International Topical Meeting on Nuclear Reactor
  Thermal Hydraulics (NURETH-21)*, Busan, Korea,
  August 31–September 5, 2025.
