# Simple Space Satellite — a SysML v2 teaching model

A small but complete **SysML v2** model of a Sputnik‑1‑like satellite. It has a pressurised
aluminium sphere, three batteries, two beacon transmitters (20 and 40 MHz), four whip antennas and
a fan for thermal control. The system is simple enough to keep in your head, and the model still
uses the main SysML v2 concepts: structure, interfaces, behaviour, requirements, analysis and
verification.

The model loads without errors in the official
[SysML v2 Pilot Implementation](https://github.com/Systems-Modeling/SysML-v2-Release)
(Jupyter kernel 0.62.0, release 2026‑08). A small Python script evaluates the requirements, which the
pilot implementation cannot do.

## Repository contents

| Path | What it is |
|---|---|
| `model/01_SatelliteLibrary.sysml` … `model/06_SatelliteAnalysis.sysml` | The model, as six packages that build on each other (load them in order) |
| `SimpleSatellite_AllInOne.sysml` | The six packages concatenated into one file |
| `SimpleSatellite_Diagrams_v2.ipynb` | Jupyter notebook (SysML kernel): loads each package and draws its diagrams |
| `verify_satellite.py` | Python verification script: computes the derived values and gives a verdict for every requirement |

### The six packages

| Package | What it teaches |
|---|---|
| `SatelliteLibrary` | `enum def`, `attribute def`, signals, `item def`, `port def`, conjugated ports `~`, `interface def` with `flow`, `calc def` |
| `SatelliteBehavior` | `action def` with `in`/`out` items, action decomposition, `bind`, `flow`; `state def` with signal triggers and change triggers (`accept when …`) |
| `SatelliteStructure` | `part def` vs. `part` usage, composition, multiplicity, ports, `interface … connect … to …`, delegation with `bind`, a derived mass roll‑up, `perform`, `exhibit state`, redefinition `:>>`, quantities with units |
| `SatelliteRequirements` | `requirement def` with `subject` and `require constraint`, requirement usages with IDs `<'SAT-1'>`, textual requirements, requirement groups |
| `SatelliteMissionContext` | external systems, `send … via`, `use case def` with actors and objective, a mission context, subsetting `:>` |
| `SatelliteAnalysis` | `analysis def` with objective and calculations, `verification def` with `verify` and `PassIf`, `satisfy … by …` |

```
SatelliteLibrary        vocabulary: items, ports, interfaces, signals, calc
      ▲
SatelliteBehavior       TransmitBeacon action, MissionStates, ThermalStates
      ▲
SatelliteStructure      part defs, Satellite blueprint, sputnik1 configuration (all values)
      ▲
SatelliteRequirements   SAT-1 … SAT-6, grouped in satelliteSpecification
      ▲
SatelliteMissionContext rocket, ground stations, use case
SatelliteAnalysis       lifetime analysis, weighing test, satisfy claim
```

Inside `Satellite`:

```
txBatteryA ──PowerInterface──▶ transmitter20 ──RFFeed──▶ ┐
txBatteryB ──PowerInterface──▶ transmitter40 ──RFFeed──▶ ├ antennas ══bind══ beaconOut ──RadioLink──▶ ground stations
fanBattery ──PowerInterface──▶ thermalControl            ┘
sensors ──DataInterface──▶ transmitter20, transmitter40
```

## Getting started

### 1. Install the SysML v2 Jupyter kernel

You need Java 21+ and Miniconda/Anaconda. Then:

```bash
conda create -n sysml -c conda-forge python=3.12 "jupyterlab=4.*" "jupyter-sysml-kernel=0.62.0" "graphviz=2.*" nodejs -y
conda activate sysml
jupyter labextension install @systems-modeling/jupyterlab-sysml@0.62.0   # optional: syntax highlighting
```

(See also the official instructions in *SysML-v2-Release → install/jupyter*.)

### 2. Explore the model and diagrams

```bash
jupyter lab
```

Open `SimpleSatellite_Diagrams_v2.ipynb` and choose **Kernel → Restart Kernel and Run All Cells**.
Each package cell is followed by its diagrams: tree, interconnection, action, state and case views.

Useful kernel commands: `%show <name>`, `%list <name>::*`, `%viz --view=<view> [--style=<style>] <name>`, `%help`.

### 3. Verify the design against the requirements

The SysML v2 pilot implementation records formulas and the `satisfy` claim but cannot evaluate
expressions with units (`--style=EVAL` and `%eval` return `null`). `verify_satellite.py` does that
evaluation. It reads the values, formulas and requirement constraints **directly from the model
files**, converts all units to SI and evaluates them. It needs Python 3.9+ and only the standard library.

```bash
python verify_satellite.py                          # verification report
python verify_satellite.py --measured-mass 83.6     # also run the weighing test (SAT-1) with a measured mass in kg
python verify_satellite.py --sysml-out verification_results.sysml
                                                    # write the verdicts as a SysML package
```

The exit code is 0 if no requirement fails and 1 otherwise. You can paste the generated
`verification_results.sysml` into a cell of the notebook and show it with
`%viz --view=tree SatelliteVerificationResults::sputnik1Results`.

Current result for `sputnik1`: SAT‑1 to SAT‑5 **pass**. SAT‑6 (telemetry) is a textual requirement,
so it is **inconclusive** until verified by inspection, and so is the overall claim
`satisfy satelliteSpecification by design`.

## Sputnik 1 data used

Historical values: diameter 58 cm; total mass 83.6 kg; three silver‑zinc batteries (51 kg);
beacons at 20.005 MHz and 40.002 MHz, 1 W each, about 0.3 s pulses; four antennas of 2.4 m and 2.9 m;
nitrogen fill at about 1.3 atm; orbit 215 × 939 km, 65.1° inclination, 96.2 min period;
launched 4 Oct 1957; beacon silent after 22 days; re‑entered 4 Jan 1958.

Values marked `(approx.)` in the model are teaching estimates, not historical figures:

- the mass of each component;
- the battery energy (7 MJ each);
- the transmitter DC input power (3.5 W);
- the fan power.

The pairing of one battery per transmitter and the fan thresholds (36 °C on, 20 °C off) are also
simplifications. The estimates were chosen so the numbers are consistent:

- **Mass roll‑up:** 14 + 10 + 3×17 + 2×1.75 + 2 + 2.5 + 0.6 = **83.6 kg** (SAT‑1 limit: 90 kg)
- **Beacon lifetime:** 7 MJ / 3.5 W = 2.0×10⁶ s ≈ **23 days** (SAT‑4 minimum: 14 days; historically 22 days)

## Known limitations of the tooling

- **Values with units can't be calculated in the pilot implementation.** It reports derived values
  (`totalMass`, `beaconLifetime`) as formulas, and `--style=EVAL` shows `null` for them. Use
  `verify_satellite.py`.
- **Large views can be cut off.** Diagrams that traverse all of `sputnik1` may show an
  "EXCEEDS THE LIMIT" banner because the tool stops after 1000 elements. The content shown is
  complete for this model.
- **Port labels can overlap.** In interconnection views, labels may overlap where connected ports
  sit next to each other. This is a layout limitation of the diagram renderer.
- **The verification script is not a general SysML v2 evaluator.** It understands the expression
  subset used here: arithmetic, comparisons, `and`/`or`/`not`, `if ? else`, quantities with units,
  enumeration literals and feature chains.

## Ideas for exercises

1. Add a requirement that the antennas shall be at least 2 m long, and extend the check.
2. Create `sputnik2 : Satellite` with a larger battery and recompute the beacon lifetime.
3. Add a state for "deploying antennas" between `onLauncher` and `transmitting`.
4. Model a solar panel (`part def SolarPanel`) as a second power source, as on Vanguard 1 (1958).
5. Allocate the `TransmitBeacon` sub-actions to `Transmitter` and `AntennaSystem` with `allocate`.
6. Add verification cases for SAT‑2 (measure the diameter) and SAT‑6 (inspect the telemetry),
   annotated with `VerificationMethodKind`.

## License

[MIT](LICENSE)
