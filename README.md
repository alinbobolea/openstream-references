# openstream-references

MATLAB reference results for [OpenSTREAM](https://github.com/OpenSTREAM-solvers/openstream)
cases, computed with the unmodified upstream code on GitHub-hosted runners.

This repository stores no OpenSTREAM code. Each run checks out OpenSTREAM at
a pinned commit, runs the cases listed in `cases/`, and saves the results in
a plain format that any MAT-file reader can open.

## What runs

- OpenSTREAM commit `a614c7173822a93c1e64ac28d1541cbac028cbd8` (tag
  `v2026.0`), with its `+CoolPropWrapper` submodule.
- MATLAB R2026b on the GitHub-hosted `ubuntu-24.04` runner image.
- CoolProp 8.0.0, installed from upstream's
  `+CoolPropWrapper/requirements.txt`.

## Layout

| Path | Contents |
|---|---|
| `cases/` | Case lists (JSON): solver class and the upstream input files and IDs for each case |
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
  converted to plain types. Enumerations become their member names and
  function handles become their text. A handle already exported is written
  as `<cycle:CLASS>`, and an object from outside OpenSTREAM as
  `<skipped:CLASS>`.
- `compared`: the mass flow rate `W`, velocity `U` and enthalpy `H` for each
  field object and stored state, read the way upstream's integration test
  reads them.

Every results folder also has an `environment.json` recording the MATLAB and
CoolProp versions, the upstream commits and the runner image.

## Running

A push to `main` runs the MATLAB unit tests. **Actions → references → Run
workflow** also runs the cases and opens a pull request with the results.

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
