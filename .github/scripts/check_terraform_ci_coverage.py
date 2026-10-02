#!/usr/bin/env python3
"""Assert every Terraform directory in this repository is actually linted by CI.

INVARIANT: every directory under environments/ or modules/ with Terraform is linted
directly by an unfiltered workflow, driven by this script's own --list-dirs output.

Why: a directory no workflow points at passes CI by never being looked at (issue #38).
And planning an environment does NOT lint the modules it consumes -- measured with
duplicate map keys reintroduced into modules/mgn-replication-baseline:

    tflint from environments/ad (which consumes it)   exit 0
    tflint in the module directory                     exit 2

tflint's module support only checks what's tied to passed variables; syntax rules don't
descend. So a module is linted only in its own directory -- the `lint` job in
ci-coverage.yaml does that, unconditionally, for every directory this script lists. No AWS
credentials, no `uses:` wiring, covers everything regardless of which repo plans it.

(This script used to also verify a reusable workflow was wired up to PLAN each environment,
by tracing `uses:` into a specific file. That broke once the plan/apply pipelines moved to
a separate shared repo this one can't see into. Dropped 2026-10-02 per Ryan/Warrick -- keep
only direct lint coverage, which needs nothing from any other repo.)

TWO CHECKS:

  1. CONFIG      every tflint step resolves TFLINT_CONFIG_FILE to the root .tflint.hcl.
                 tflint never walks up to find it, so without the explicit path the AWS
                 ruleset silently doesn't load while the step still passes.
  2. DIRECT LINT an unfiltered workflow runs tflint in each directory this script lists.

Anything this script cannot parse or cannot model is a FAILURE, never a skip. A checker has
three outcomes -- verified pass, verified fail, and could-not-verify -- and the third one
silently joining the first is the defect class this whole file exists to prevent.

Run: python .github/scripts/check_terraform_ci_coverage.py [repo_root]
Exit 0 = every check passed. Exit 1 = at least one failed, each printed with its reason.
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    import yaml
except ModuleNotFoundError:  # pragma: no cover - environment problem, not a repo problem
    sys.exit("FATAL: PyYAML is required to read the workflow files (pip install pyyaml)")

TF_ROOTS = ("environments", "modules")
WORKFLOW_DIR = Path(".github/workflows")
TFLINT_CONFIG = ".tflint.hcl"

# The ONE accepted spelling of "the repository-root tflint config".
#
# A suffix test was the first attempt and was a real hole: `/tmp/.tflint.hcl` ends in the
# right basename and loads a completely different config, with no AWS plugin, while the
# check reported success. The second attempt then allowed two more spellings that DO NOT
# WORK, which is the same defect in a new place:
#
#   ".tflint.hcl"                  relative, so it resolves against the step's
#                                  working-directory (environments/ad), not the root
#   "$GITHUB_WORKSPACE/.tflint.hcl"  a workflow `env:` value is not shell-expanded, so
#                                  tflint receives that dollar sign literally
#
# Only the GitHub expression form is substituted before the process sees it, so only it
# is accepted. A legitimate new spelling must be added here deliberately, with evidence
# that it resolves to the root.
ROOT_CONFIG_VALUES = ("${{ github.workspace }}/" + TFLINT_CONFIG,)


class Unsupported(Exception):
    """A construct this script has not modelled. Always fatal, never skipped."""


# --------------------------------------------------------------------------------------
# Inventory
# --------------------------------------------------------------------------------------

def discover_terraform_dirs(repo: Path) -> tuple[list[str], list[str]]:
    """Inventory from disk. Returns (directories, problems).

    Only IMMEDIATE children of each root are modelled. A Terraform directory nested
    deeper is reported as a failure rather than ignored -- ignoring it would let a
    directory be added that --list-dirs never lists while the stated invariant claims
    to cover every Terraform directory.
    """
    found: list[str] = []
    problems: list[str] = []
    for root_name in TF_ROOTS:
        root = repo / root_name
        if not root.is_dir():
            problems.append(
                f"inventory root {root_name}/ does not exist -- either the repository was "
                f"restructured (update TF_ROOTS) or this check is now vacuous"
            )
            continue
        here = sorted(
            f"{root_name}/{d.name}"
            for d in root.iterdir()
            if d.is_dir() and not d.name.startswith(".") and any(d.glob("*.tf"))
        )
        if not here:
            problems.append(
                f"inventory root {root_name}/ matched no directory containing .tf -- an "
                f"empty inventory agrees with any manifest, so this is a failure, not a pass"
            )
        found.extend(here)

        for child in sorted(root.iterdir()):
            if not child.is_dir() or child.name.startswith("."):
                continue
            for deeper in sorted(child.rglob("*.tf")):
                rel_dir = deeper.parent.relative_to(repo)
                if any(part.startswith(".") for part in rel_dir.parts):
                    continue  # .terraform/ and friends are build output, not source
                if str(rel_dir) != f"{root_name}/{child.name}":
                    problems.append(
                        f"{rel_dir}: Terraform nested below {root_name}/{child.name}. This "
                        f"script models only immediate children of {'/, '.join(TF_ROOTS)}/, "
                        f"so this directory would never be listed by --list-dirs. Decide "
                        f"deliberately: flatten it, or teach discover_terraform_dirs() how "
                        f"nested directories are linted"
                    )
                    break
    return found, problems


# --------------------------------------------------------------------------------------
# Workflows
# --------------------------------------------------------------------------------------

def load_workflows(repo: Path) -> tuple[list[dict], list[str]]:
    """Parse every workflow file. A file that will not parse is a failure, not a skip."""
    workflows: list[dict] = []
    problems: list[str] = []
    wf_dir = repo / WORKFLOW_DIR
    if not wf_dir.is_dir():
        return [], [f"{WORKFLOW_DIR}/ does not exist -- nothing runs, nothing is covered"]
    paths = sorted(p for p in wf_dir.iterdir() if p.suffix in (".yml", ".yaml"))
    if not paths:
        return [], [f"{WORKFLOW_DIR}/ contains no workflow files -- check is vacuous"]
    for path in paths:
        text = path.read_text(encoding="utf-8")
        try:
            doc = yaml.safe_load(text)
        except yaml.YAMLError as exc:
            problems.append(f"{path.relative_to(repo)}: will not parse as YAML "
                            f"({exc.__class__.__name__}); an unreadable workflow is COULD "
                            f"NOT VERIFY, not clean")
            continue
        if not isinstance(doc, dict):
            problems.append(f"{path.relative_to(repo)}: top level is {type(doc).__name__}, "
                            f"expected a mapping")
            continue
        workflows.append({"path": path, "rel": str(path.relative_to(repo)), "doc": doc,
                          "text": text})
    return workflows, problems


def triggers(doc: dict) -> dict:
    """The `on:` block.

    PyYAML implements YAML 1.1, where the bare key `on` is the BOOLEAN True -- so
    doc["on"] is a KeyError on every real GitHub workflow and reading it that way
    reports "no triggers" for a file full of them. Look for both spellings.
    """
    for key in (True, "on"):
        if key in doc:
            value = doc[key]
            return value if isinstance(value, dict) else {}
    return {}


def trigger_filters(doc: dict, trigger: str) -> tuple[bool, list[str]]:
    """Return (trigger_present, path_filters). No `paths:` means every path."""
    on = triggers(doc)
    if trigger not in on:
        return False, []
    block = on[trigger]
    if block is None:
        return True, []
    if not isinstance(block, dict):
        raise Unsupported(f"on.{trigger} is {type(block).__name__}, expected a mapping")
    if "paths-ignore" in block:
        raise Unsupported(
            f"on.{trigger}.paths-ignore is not modelled by this script; it inverts the "
            f"matching rule, so treating it as a `paths` list would report coverage that "
            f"does not exist"
        )
    paths = block.get("paths")
    if paths is None:
        return True, []
    if not isinstance(paths, list) or not all(isinstance(p, str) for p in paths):
        raise Unsupported(f"on.{trigger}.paths must be a list of strings")
    return True, paths


# --------------------------------------------------------------------------------------
# tflint invocations
# --------------------------------------------------------------------------------------
#
# What counts as "this step runs tflint". Stated once, here, because two independent
# answers to that question WILL diverge -- and the first version of this file had exactly
# that, with `startswith("tflint")` in both. That prefix test also matched the workflow
# INPUT declaration `tflint_version:`, so terraform-plan.yaml counted as lint-capable even
# with every tflint command deleted from it. A prefix test is not a grammar.
#
# The grammar this models, deliberately small and stated rather than guessed:
#   * a `run:` block is split into lines, then into segments on ; && || |
#   * leading NAME=VALUE environment assignments are skipped
#   * a segment invokes tflint iff the first word after those is exactly "tflint"
#
# A tflint reached any other way -- `sudo tflint`, a wrapper script, a Makefile target --
# is NOT recognised as an invocation, and is NOT silently read as "no tflint here" either:
# a run block that mentions tflint as a bare word without yielding a recognised invocation
# is reported as UNCLASSIFIABLE and fails the build. "Could not parse" is not a pass.

_SEPARATORS = (";", "&&", "||", "|")


def _segments(run_block: str) -> list[list[str]]:
    out = []
    for line in run_block.splitlines():
        segment = line.strip()
        for sep in _SEPARATORS:
            segment = segment.replace(sep, "\n")
        for part in segment.split("\n"):
            words = part.split()
            if words:
                out.append(words)
    return out


def _is_tflint_invocation(words: list[str]) -> bool:
    i = 0
    while i < len(words) and "=" in words[i] and not words[i].startswith("-") \
            and words[i].split("=", 1)[0].isidentifier():
        i += 1  # leading NAME=VALUE environment assignment
    return i < len(words) and words[i] == "tflint"


def _mentions_tflint(words: list[str]) -> bool:
    return any(w == "tflint" or w.endswith("/tflint") for w in words)


def classify_run_block(run_block: str) -> tuple[bool, list[str]]:
    """Return (invokes_tflint, unclassifiable_segments)."""
    invokes = False
    unclear: list[str] = []
    for words in _segments(run_block):
        if _is_tflint_invocation(words):
            invokes = True
        elif _mentions_tflint(words):
            unclear.append(" ".join(words))
    return invokes, unclear


def tflint_run_steps(workflows: list[dict]):
    """Yield (workflow, job name, step label, env scopes, unclassifiable segments).

    The single derivation of "runs tflint". Every other check reads this, so they cannot
    disagree about which steps exist. `envs` is ordered most-specific first.
    """
    for wf in workflows:
        doc = wf["doc"]
        jobs = doc.get("jobs")
        if not isinstance(jobs, dict):
            continue
        wf_env = doc.get("env") if isinstance(doc.get("env"), dict) else {}
        for job_name, job in jobs.items():
            if not isinstance(job, dict):
                continue
            job_env = job.get("env") if isinstance(job.get("env"), dict) else {}
            steps = job.get("steps")
            if not isinstance(steps, list):
                continue
            for index, step in enumerate(steps):
                if not isinstance(step, dict):
                    continue
                run = step.get("run")
                if not isinstance(run, str):
                    continue
                invokes, unclear = classify_run_block(run)
                if not invokes and not unclear:
                    continue
                step_env = step.get("env") if isinstance(step.get("env"), dict) else {}
                label = step.get("name") or f"steps[{index}]"
                # `if: false` on a tflint step would disable linting silently. Reported,
                # not evaluated -- no caller context to resolve it against here.
                conditions = [c for c in (job.get("if"), step.get("if")) if c is not None]
                yield wf, job_name, label, (step_env, job_env, wf_env), unclear, conditions


def resolve_env(envs: tuple[dict, ...], name: str):
    """First definition wins, scopes ordered most-specific first. Returns None if unset.

    Precedence matters: a step-level `TFLINT_CONFIG_FILE: ""` overrides a valid job- or
    workflow-level value, so merely asking whether the name appears in ANY scope reports
    a configured step that is in fact unconfigured.
    """
    for scope in envs:
        if name in scope:
            return scope[name]
    return None


def tflint_config_problems(workflows: list[dict]) -> list[str]:
    """Every step that runs tflint must resolve TFLINT_CONFIG_FILE to the root config."""
    problems = []
    for wf, job_name, label, envs, unclear, conditions in tflint_run_steps(workflows):
        where = f"{wf['rel']}: job {job_name!r} step {label!r}"
        if conditions:
            problems.append(
                f"{where} runs tflint under a condition ({conditions!r}). A conditional "
                f"lint can be skipped while this directory still reads as covered -- "
                f"`if: false` alone would disable linting repository-wide. Make the lint "
                f"unconditional, or model the condition deliberately"
            )
            continue
        if unclear:
            problems.append(
                f"{where} mentions tflint in a form this script cannot classify as an "
                f"invocation: {unclear!r}. Rewrite it as a plain `tflint ...` command, or "
                f"teach _is_tflint_invocation() the form -- an unclassifiable command is "
                f"not evidence that no tflint runs"
            )
            continue
        value = resolve_env(envs, "TFLINT_CONFIG_FILE")
        if value is None:
            problems.append(
                f"{where} runs tflint without TFLINT_CONFIG_FILE. tflint looks for "
                f"{TFLINT_CONFIG} in its working directory only, so the root config is not "
                f"found and the AWS ruleset silently does not load"
            )
        elif not str(value).strip():
            problems.append(
                f"{where} sets TFLINT_CONFIG_FILE to an empty value, which leaves tflint "
                f"looking in its working directory exactly as if the variable were unset"
            )
        elif str(value).strip() not in ROOT_CONFIG_VALUES:
            problems.append(
                f"{where} sets TFLINT_CONFIG_FILE to {value!r}, which is not a recognised "
                f"spelling of the repository-root {TFLINT_CONFIG}. Only the root config "
                f"declares the AWS plugin, and a same-named file elsewhere would load a "
                f"different ruleset while looking correct. Accepted: "
                f"{', '.join(ROOT_CONFIG_VALUES)} -- add a spelling there if a legitimate "
                f"one is missing"
            )
    return problems


LIST_DIRS_FLAG = "--list-dirs"


def lint_job_problems(repo: Path, workflows: list[dict]) -> list[str]:
    """Some unfiltered workflow lints every directory, using OUR enumeration.

    The directory set isn't restated in YAML -- the workflow asks this script for it, so
    the two can't disagree about what exists.
    """
    for wf in workflows:
        try:
            has_pr, pr_paths = trigger_filters(wf["doc"], "pull_request")
        except Unsupported:
            continue
        if not has_pr or pr_paths:
            continue  # must be unfiltered, or a new directory could dodge the lint
        jobs = wf["doc"].get("jobs")
        if not isinstance(jobs, dict):
            continue
        for job in jobs.values():
            if not isinstance(job, dict) or not isinstance(job.get("steps"), list):
                continue
            for step in job["steps"]:
                if not isinstance(step, dict) or not isinstance(step.get("run"), str):
                    continue
                run = step["run"]
                if LIST_DIRS_FLAG in run and classify_run_block(run)[0]:
                    return []
    return [
        f"no unfiltered workflow runs tflint in each directory listed by "
        f"`{Path(__file__).name} {LIST_DIRS_FLAG}`. Planning an environment does NOT lint "
        f"the modules it consumes -- measured: reintroducing duplicate map keys into "
        f"modules/mgn-replication-baseline leaves tflint from environments/ad at exit 0 "
        f"while tflint in the module exits 2. Without that loop, module regressions ship "
        f"with CI green"
    ]


def run(repo: Path) -> list[str]:
    failures: list[str] = []

    _, root_problems = discover_terraform_dirs(repo)
    failures.extend(root_problems)

    workflows, wf_problems = load_workflows(repo)
    failures.extend(wf_problems)
    if not workflows:
        return failures

    failures.extend(tflint_config_problems(workflows))
    failures.extend(lint_job_problems(repo, workflows))

    return failures


def main(argv: list[str]) -> int:
    if LIST_DIRS_FLAG in argv:
        rest = [a for a in argv[1:] if a != LIST_DIRS_FLAG]
        repo = Path(rest[0]).resolve() if rest else Path(__file__).resolve().parents[2]
        dirs, problems = discover_terraform_dirs(repo)
        if problems:
            for problem in problems:
                print(f"FAIL  {problem}", file=sys.stderr)
            return 1
        if not dirs:
            print("FAIL  no Terraform directories found", file=sys.stderr)
            return 1
        print("\n".join(dirs))
        return 0

    repo = Path(argv[1]).resolve() if len(argv) > 1 else Path(__file__).resolve().parents[2]
    failures = run(repo)
    if failures:
        print(f"Terraform CI coverage: {len(failures)} problem(s) in {repo}\n")
        for failure in failures:
            print(f"  FAIL  {failure}\n")
        return 1
    print(f"Terraform CI coverage: all checks passed in {repo}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
