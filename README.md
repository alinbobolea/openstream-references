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
- MATLAB R2026b on the GitHub-hosted `ubuntu-24.04` runner image.
- CoolProp 8.0.0, installed from upstream's
  `+CoolPropWrapper/requirements.txt`.

## Layout

| Path | Contents |
|---|---|
| `cases/` | Case lists (JSON). Input-file cases name the upstream input files and IDs; dataset cases name a database dataset, a record (`testID`), a solver and model/option overrides; `input-fixture.json` lists the input-parsing cases, and `input-fixture/` holds the input files written for them |
| `matlab/` | Scripts that run the cases and export the results |
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

Every results folder also has an `environment.json` recording the MATLAB and
CoolProp versions, the upstream commits, the runner image and the processor
model (`cpuModel`, read from `/proc/cpuinfo`; empty where that file does not
exist).

## Running

A push to `main` runs the MATLAB unit tests. **Actions → references → Run
workflow** also runs one target and opens a pull request with the results:

| Target | Cases | Results folder |
|---|---|---|
| `tutorial1` | `cases/tutorial1.json`: upstream's TUTORIAL1 input files, four solvers, plus a re-export of upstream's saved references | `results/tutorial1/`, `results/tutorial1-upstream/` |
| `nuthos15-bartolomey` | `cases/nuthos15-bartolomey.json`: Bartolomey records 22 and 35 from OpenSTREAM-database, Mixture solver | `results/nuthos15-bartolomey/` |
| `input-fixture` | `cases/input-fixture.json`: what OpenSTREAM's input classes and the MATLAB functions they rely on do with given input files and values, including invalid ones | `results/input-fixture/` |

## Input fixture

The `input-fixture` target records behaviour rather than a solution. Each
entry of `cases/input-fixture.json` has a unique `name`, a `kind` and the
fields its kind needs; file paths are relative to the repository root, and
numeric arguments are given as text lists, `{"double": ["0.2", "NaN", "-0"]}`,
converted with `str2double`, so that values JSON numbers cannot carry (NaN,
Inf, -0) can be written. The kinds are: `read` and `convert2json`
(upstream's input-file parser), `model`, `options`, `geometry`, `bc`,
`default`, `listprops` and `write` (the input classes), `inputset` (a full
input set and its solver-dependent properties), and `handle`, `textscan`,
`upper`, `sprintf`, `num2str`, `readlines`, `ismembertol`, `uint8`, `sum`,
`sumsweep` and `legalpath` (single functions the input code relies on:
MATLAB built-ins and upstream's `Session.isLegalPath`). Some cases fail on
purpose: the error is part of the record.

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
