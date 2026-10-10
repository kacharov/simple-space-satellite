#!/usr/bin/env python3
"""
verify_satellite.py — verification & validation of the Simple Space Satellite SysML v2 model.

The SysML v2 pilot implementation (Jupyter kernel) cannot evaluate expressions
that carry units, so it can state "satisfy satelliteSpecification by design" but
cannot tell whether the claim is true. This script closes that gap.

It reads the model files in ./model directly — it does NOT duplicate any numbers:
  * design values             <- `part sputnik1 : Satellite { ... }`        (03_SatelliteStructure)
  * mass roll-up formula      <- `attribute totalMass ... = ...;`            (03_SatelliteStructure)
  * lifetime calculation      <- `calc def BatteryLifetime` + the calc usages
                                 in `analysis def BeaconLifetimeAnalysis`     (01 + 06)
  * requirement constraints   <- `requirement def ... { require constraint { ... } }`
  * requirement limits        <- `requirement <'SAT-n'> ... { attribute :>> ... = ...; }` (04)

and then evaluates everything with units converted to SI.

Usage:
    python verify_satellite.py                       # print the verification report
    python verify_satellite.py --measured-mass 83.6  # also run the weighing test (SAT-1) with a measurement in kg
    python verify_satellite.py --sysml-out results.sysml
                                                     # also write the verdicts as a SysML package that can be
                                                     # pasted into a cell of the SysML notebook and visualised
Exit code: 0 if no requirement fails, 1 otherwise.

Scope: this is a teaching tool, not a general SysML evaluator. It understands the
subset of SysML v2 expressions used in this model (arithmetic, comparisons,
and/or/not, if-?-else, quantities with units, enumeration literals, feature chains).
"""

from __future__ import annotations

import argparse
import ast
import math
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

# ---------------------------------------------------------------------------
# Units: factor to convert a value in that unit to SI base units
# (only the units used in this model; extend as needed)
# ---------------------------------------------------------------------------
UNITS = {
    "kg": 1.0, "g": 1e-3,
    "m": 1.0, "cm": 1e-2, "mm": 1e-3, "km": 1e3,
    "s": 1.0, "min": 60.0, "h": 3600.0, "d": 86400.0,
    "Hz": 1.0, "kHz": 1e3, "MHz": 1e6,
    "W": 1.0, "kW": 1e3,
    "J": 1.0, "kJ": 1e3, "MJ": 1e6,
    "K": 1.0, "Pa": 1.0,
    "°": math.pi / 180.0,
}

# How to display a quantity, chosen from the unit it was written in
# (computed quantities get a unit explicitly)
DISPLAY = {u: u for u in UNITS}
DISPLAY["Hz"] = "MHz"        # frequencies read better in MHz


@dataclass
class Quantity:
    """A value in SI base units plus the unit used to display it."""
    si: float | str | bool
    unit: str = ""

    def show(self) -> str:
        if isinstance(self.si, (str, bool)) or not self.unit:
            return str(self.si)
        v = self.si / UNITS[self.unit]
        return f"{v:.6g} {self.unit}"


# ---------------------------------------------------------------------------
# Reading the SysML text
# ---------------------------------------------------------------------------
def strip_comments(text: str) -> str:
    text = re.sub(r"\bdoc\s*/\*.*?\*/", " ", text, flags=re.S)   # documentation
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)           # block comments
    text = re.sub(r"//[^\n]*", " ", text)                         # line notes
    return text


def find_block(text: str, header_regex: str) -> tuple[re.Match, str]:
    """Find `header {` and return (match, body) with balanced braces."""
    m = re.search(header_regex + r"\s*\{", text, flags=re.S)
    if not m:
        raise ValueError(f"Model element not found: {header_regex}")
    depth, i = 1, m.end()
    while depth:
        c = text[i]
        depth += c == "{"
        depth -= c == "}"
        i += 1
    return m, text[m.end(): i - 1]


def split_statements(body: str) -> list[str]:
    """Split a block body into top-level statements (`...;` or `... { ... }`)."""
    out, depth, start = [], 0, 0
    for i, c in enumerate(body):
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                out.append(body[start: i + 1].strip())
                start = i + 1
        elif c == ";" and depth == 0:
            out.append(body[start:i].strip())
            start = i + 1
    rest = body[start:].strip()
    if rest:
        out.append(rest)
    return [s for s in out if s]


QTY = re.compile(r"(?<![\w.])(\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)\s*\[\s*'?([^\]']+?)'?\s*\]")


def parse_literal(expr: str) -> Quantity | None:
    """Parse `58 [cm]`, `20.005E6 [Hz]`, `FrequencyBand::HF` or a plain number."""
    expr = expr.strip()
    m = QTY.fullmatch(expr)
    if m:
        unit = m.group(2).strip()
        return Quantity(float(m.group(1)) * UNITS[unit], DISPLAY[unit])
    if re.fullmatch(r"[\w:]+::(\w+)", expr):
        return Quantity(expr.split("::")[-1])
    if re.fullmatch(r"[\d.eE+-]+", expr):
        return Quantity(float(expr))
    return None


def collect_redefinitions(body: str, prefix: str, values: dict[str, Quantity]) -> None:
    """Walk `part :>> x { :>> y = 5 [kg]; }` blocks and collect 'x.y' -> value."""
    for st in split_statements(body):
        m = re.match(r"(?:(?:part|attribute|item|port)\s+)?:>>\s*(\w+)\s*(.*)$", st, flags=re.S)
        if not m:
            continue
        name, rest = m.group(1), m.group(2).strip()
        path = f"{prefix}{name}"
        if rest.startswith("{"):
            collect_redefinitions(rest[1:-1], path + ".", values)
        elif rest.startswith("="):
            lit = parse_literal(rest[1:])
            if lit is not None:
                values[path] = lit


# ---------------------------------------------------------------------------
# Evaluating SysML expressions (safe subset, via Python's ast)
# ---------------------------------------------------------------------------
KEYWORDS = {"and", "or", "not", "if", "else", "true", "false", "xor", "implies"}
NAME = re.compile(r"(?<![\w'])([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)")
ALLOWED = (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.UnaryOp, ast.Not, ast.USub,
           ast.BinOp, ast.Add, ast.Sub, ast.Mult, ast.Div, ast.Pow, ast.Compare, ast.Eq,
           ast.NotEq, ast.Lt, ast.LtE, ast.Gt, ast.GtE, ast.IfExp, ast.Constant, ast.Name,
           ast.Load)


def evaluate(expr: str, resolve) -> tuple[object, dict[str, Quantity]]:
    """Evaluate a SysML expression. `resolve(name)` returns a Quantity for a feature chain.
    Returns (result, {name: value used})."""
    used: dict[str, Quantity] = {}
    py = " ".join(expr.split())
    # if c ? a else b   ->   (a if c else b)
    py = re.sub(r"\bif\s+(.+?)\s*\?\s*(.+?)\s+else\s+(.+)", r"((\2) if (\1) else (\3))", py)
    # quantities with units -> SI numbers
    py = QTY.sub(lambda m: repr(float(m.group(1)) * UNITS[m.group(2).strip()]), py)
    # enumeration literals  A::B::C -> 'C'
    py = re.sub(r"\b[\w]+(?:::[\w]+)+", lambda m: repr(m.group(0).split("::")[-1]), py)
    py = py.replace("true", "True").replace("false", "False")
    env: dict[str, object] = {}

    def sub_name(m: re.Match) -> str:
        name = m.group(1)
        if name in KEYWORDS or name in ("True", "False"):
            return name
        q = resolve(name)
        used[name] = q
        var = f"_v{len(env)}"
        env[var] = q.si
        return var

    py = NAME.sub(sub_name, py)
    tree = ast.parse(py, mode="eval")
    for node in ast.walk(tree):
        if not isinstance(node, ALLOWED):
            raise ValueError(f"Unsupported expression element {type(node).__name__} in: {expr}")
    return eval(compile(tree, "<sysml>", "eval"), {"__builtins__": {}}, env), used


# ---------------------------------------------------------------------------
# The verification
# ---------------------------------------------------------------------------
@dataclass
class Result:
    rid: str
    name: str
    text: str
    verdict: str                 # pass | fail | inconclusive  (VerificationCases::VerdictKind)
    method: str                  # analyze | test | inspect
    constraint: str = ""
    used: dict[str, Quantity] = field(default_factory=dict)


def load_model(model_dir: Path) -> dict[str, str]:
    files = sorted(model_dir.glob("0*.sysml"))
    if not files:
        sys.exit(f"No model files found in {model_dir}")
    return {f.stem: strip_comments(f.read_text(encoding="utf-8")) for f in files}


def run(model_dir: Path, measured_mass: float | None) -> tuple[dict[str, Quantity], list[Result], str]:
    src = load_model(model_dir)
    lib = next(v for k, v in src.items() if "Library" in k)
    struct = next(v for k, v in src.items() if "Structure" in k)
    reqs = next(v for k, v in src.items() if "Requirements" in k)
    analysis = next(v for k, v in src.items() if "Analysis" in k)

    # 1. Design values of sputnik1 ------------------------------------------------
    design: dict[str, Quantity] = {}
    _, body = find_block(struct, r"part\s+sputnik1\s*:\s*Satellite")
    collect_redefinitions(body, "", design)

    def resolve_design(name: str) -> Quantity:
        name = name.removeprefix("sat.")
        if name not in design:
            raise KeyError(f"'{name}' has no value in sputnik1")
        return design[name]

    # 2. Derived attribute: totalMass (formula taken from part def Satellite) ------
    _, sat_def = find_block(struct, r"part\s+def\s+Satellite")
    m = re.search(r"attribute\s+totalMass\s*:\s*\w+\s*=\s*(.+?);", sat_def, flags=re.S)
    total, _ = evaluate(m.group(1), resolve_design)
    design["totalMass"] = Quantity(total, "kg")

    # 3. Analysis case: BeaconLifetimeAnalysis -------------------------------------
    calc_defs = {}
    for cm in re.finditer(r"calc\s+def\s+(\w+)", lib):
        _, cbody = find_block(lib, rf"calc\s+def\s+{cm.group(1)}")
        ret = re.search(r"return\s+(\w+)\s*:\s*\w+\s*=\s*(.+?);", cbody, flags=re.S)
        calc_defs[cm.group(1)] = (ret.group(1), ret.group(2))

    _, an_body = find_block(analysis, r"analysis\s+def\s+BeaconLifetimeAnalysis")
    calc_results: dict[str, Quantity] = {}
    for cu in re.finditer(r"calc\s+(\w+)\s*:\s*(\w+)", an_body):
        uname, cdef = cu.group(1), cu.group(2)
        _, ubody = find_block(an_body, rf"calc\s+{uname}\s*:\s*{cdef}")
        params = {p: evaluate(e, resolve_design)[0]
                  for p, e in re.findall(r"in\s+(\w+)\s*=\s*(.+?);", ubody)}
        rname, rexpr = calc_defs[cdef]
        val, _ = evaluate(rexpr, lambda n: Quantity(params[n]))
        calc_results[f"{uname}.{rname}"] = Quantity(val, "d")

    ret = re.search(r"return\s+(\w+)\s*:\s*\w+\s*=\s*(.+?);", an_body, flags=re.S)
    lifetime, _ = evaluate(ret.group(2), lambda n: calc_results[n])
    # The design context binds  design.beaconLifetime = lifetimeAnalysis.predictedLifetime
    design["beaconLifetime"] = Quantity(lifetime, "d")
    for k, v in calc_results.items():
        design[f"lifetimeAnalysis.{k}"] = v

    # 4. Requirements ---------------------------------------------------------------
    req_defs = {}
    for dm in re.finditer(r"requirement\s+def\s+(\w+)", reqs):
        _, dbody = find_block(reqs, rf"requirement\s+def\s+{dm.group(1)}")
        cons = re.search(r"require\s+constraint\s*\{(.*?)\}\s*$", dbody, flags=re.S)
        req_defs[dm.group(1)] = cons.group(1).strip() if cons else ""

    raw = (model_dir / next(f.name for f in model_dir.glob("04*.sysml"))).read_text(encoding="utf-8")
    results: list[Result] = []
    for um in re.finditer(r"requirement\s+<'([^']+)'>\s+(\w+)\s*:\s*(\w+)", reqs):
        rid, uname, dname = um.groups()
        _, ubody = find_block(reqs, rf"requirement\s+<'{re.escape(rid)}'>\s+{uname}\s*:\s*{dname}")
        limits: dict[str, Quantity] = {}
        collect_redefinitions(ubody, "", limits)
        # requirement text = doc of the requirement definition (read from the raw file)
        doc = re.search(rf"requirement\s+def\s+{dname}\s*\{{\s*doc\s*/\*(.*?)\*/", raw, flags=re.S)
        text = " ".join(doc.group(1).replace("*", " ").split()) if doc else ""
        constraint = req_defs.get(dname, "")
        if not constraint:
            results.append(Result(rid, uname, text, "inconclusive", "inspect"))
            continue

        def resolve(n: str, limits=limits) -> Quantity:
            return limits[n] if n in limits else resolve_design(n)

        ok, used = evaluate(constraint, resolve)
        results.append(Result(rid, uname, text, "pass" if ok else "fail", "analyze",
                              " ".join(constraint.split()), used))

    # 5. Verification case: weighing test for SAT-1 -------------------------------
    if measured_mass is not None:
        sat1 = next(r for r in results if r.name == "massLimit")
        limit = sat1.used["maxMass"]
        ok = measured_mass <= limit.si
        results.append(Result("SAT-1-T", "massLimitWeighingTest",
                              "Measured mass of the flight article <= maxMass", "pass" if ok else "fail",
                              "test", "measuredMass <= massLimit.maxMass",
                              {"measuredMass": Quantity(measured_mass, "kg"), "maxMass": limit}))

    # 6. The claim: satisfy satelliteSpecification by design ---------------------
    verdicts = {r.verdict for r in results}
    claim = "fail" if "fail" in verdicts else ("inconclusive" if "inconclusive" in verdicts else "pass")
    return design, results, claim


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
MARK = {"pass": "PASS", "fail": "FAIL", "inconclusive": "INCONCLUSIVE"}


def report(design: dict[str, Quantity], results: list[Result], claim: str) -> None:
    print("=" * 78)
    print(" Verification report — sputnik1 against satelliteSpecification")
    print("=" * 78)
    print("\nComputed values (not evaluable in the SysML pilot implementation):")
    print(f"  totalMass        = {design['totalMass'].show()}   (mass roll-up, part def Satellite)")
    for k, v in design.items():
        if k.startswith("lifetimeAnalysis."):
            print(f"  {k:<33}= {v.show()}")
    print(f"  beaconLifetime   = {design['beaconLifetime'].show()}   "
          f"(BeaconLifetimeAnalysis, {design['beaconLifetime'].si:.4g} s)")

    print("\nRequirements:")
    for r in results:
        print(f"\n  [{MARK[r.verdict]:^12}] {r.rid}  {r.name}   (method: {r.method})")
        if r.text:
            print(f"                 \"{r.text}\"")
        if r.constraint:
            print(f"                 constraint: {r.constraint}")
            for n, q in r.used.items():
                print(f"                   {n} = {q.show()}")
        elif r.verdict == "inconclusive":
            print("                 textual requirement: no formal constraint — verify by inspection")

    print("\n" + "-" * 78)
    print(f" Claim  'satisfy satelliteSpecification by design'  ->  {claim.upper()}")
    if claim == "inconclusive":
        print("  (no requirement fails; textual requirements still need inspection)")
    print("-" * 78)


def sysml_package(design: dict[str, Quantity], results: list[Result], claim: str) -> str:
    """The verdicts as a SysML v2 package that can be pasted into the notebook."""
    def q(v: Quantity) -> str:
        return f"{v.si / UNITS[v.unit]:.6g} [{v.unit}]"

    lines = [
        "package SatelliteVerificationResults {",
        "\tdoc /* Generated by verify_satellite.py — results of evaluating the model outside the pilot tool. */",
        "\tprivate import ISQ::*;",
        "\tprivate import SI::*;",
        "\tprivate import VerificationCases::*;",
        "",
        "\tpart sputnik1Results {",
        f"\t\tattribute totalMass : MassValue = {q(design['totalMass'])};",
        f"\t\tattribute beaconLifetime : DurationValue = {q(design['beaconLifetime'])};",
        "",
    ]
    for r in results:
        ident = r.name
        lines.append(f"\t\tattribute <'{r.rid}'> {ident}Verdict : VerdictKind = VerdictKind::{r.verdict};")
    lines += ["", f"\t\tattribute specificationVerdict : VerdictKind = VerdictKind::{claim};", "\t}", "}", ""]
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--model", type=Path, default=Path(__file__).resolve().parent / "model",
                    help="folder containing the 0*.sysml model files (default: ./model)")
    ap.add_argument("--measured-mass", type=float, metavar="KG",
                    help="measured mass in kg: also run the weighing test (verification of SAT-1)")
    ap.add_argument("--sysml-out", type=Path, metavar="FILE",
                    help="write the verdicts as a SysML package to FILE")
    args = ap.parse_args()

    design, results, claim = run(args.model, args.measured_mass)
    report(design, results, claim)
    if args.sysml_out:
        args.sysml_out.write_text(sysml_package(design, results, claim), encoding="utf-8")
        print(f"\nSysML results written to {args.sysml_out} — paste it into a cell of the SysML notebook.")
    return 1 if any(r.verdict == "fail" for r in results) else 0


if __name__ == "__main__":
    sys.exit(main())
