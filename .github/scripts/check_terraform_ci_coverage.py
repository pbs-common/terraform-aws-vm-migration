#!/usr/bin/env python3
"""Assert every Terraform directory in this repository is actually linted by CI.

THE INVARIANT, stated once, here, so no other file has to paraphrase it:

    Every directory under environments/ or modules/ that contains Terraform is
    planned-and-linted by a workflow that TRIGGERS when that directory changes,
    or is named in the exclusions manifest with a reason.

Why this exists (issue #38). CI runs tflint through .github/workflows/terraform-plan.yaml,
but that is a reusable workflow: it only ever runs for a directory some caller points it
at, and only when that caller's `paths:` filters fire. A new environments/* or modules/*
directory therefore passes CI by never being looked at. Measured on 2026-09-11: the only
caller (ad.yaml) filtered on three paths, and neither environments/org-delegation nor
modules/mgn-organizations-delegation matched any of them -- both merged unlinted while the
repository looked covered. The same sweep found modules/ssm-session-access-policy, which
environments/ad has consumed since before that, missing from those filters too.

FOUR CHECKS, and each direction matters:

  1. CONFIG      every workflow step that runs tflint exports TFLINT_CONFIG_FILE.
                 tflint reads .tflint.hcl from its OWN working directory and never walks
                 up to the repository root, and terraform-plan.yaml sets
                 defaults.run.working-directory to the environment being planned. Without
                 the explicit path the root config is invisible, `tflint --init` installs
                 nothing, the AWS ruleset silently does not run, and the step still passes.
  2. COVERAGE    every Terraform directory is covered, or excluded -- never neither, and
                 never both. "Both" matters: an excluded directory that has since been
                 wired into CI means the manifest's stated reason is now false.
  3. DEPENDENCY  a workflow that plans an environment filters on every module that
                 environment consumes. Otherwise editing the module changes the plan and
                 triggers nothing -- coverage of the environment without coverage of its
                 inputs.
  4. STALENESS   every path filter, every working_directory and every exclusion still
                 names something that exists. An allow-list checked only in the direction
                 "everything listed still exists" is blind to additions; one checked only
                 as "everything that exists is listed" rots into entries matching nothing.
                 Both directions are asserted.

Anything this script cannot parse or cannot model is a FAILURE, never a skip. A checker
has three outcomes -- verified pass, verified fail, and could-not-verify -- and the third
one silently joining the first is the defect class this whole file exists to prevent.

Run: python .github/scripts/check_terraform_ci_coverage.py [repo_root]
Exit 0 = every check passed. Exit 1 = at least one failed, each printed with its reason.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

try:
    import yaml
except ModuleNotFoundError:  # pragma: no cover - environment problem, not a repo problem
    sys.exit("FATAL: PyYAML is required to read the workflow files (pip install pyyaml)")

TF_ROOTS = ("environments", "modules")
WORKFLOW_DIR = Path(".github/workflows")
EXCLUSIONS_FILE = Path(".github/terraform-ci-coverage-exclusions.json")

# GitHub's path-filter syntax supports *, **, ?, +, ! and character ranges. This script
# deliberately implements only the two shapes the repository actually uses, and REFUSES
# anything else rather than guessing at semantics it has not modelled:
#
#     "a/b/**"   every path under a/b
#     "a/b"      exactly a/b
#
# A pattern outside that subset fails check 1 with a message saying to extend the matcher.
# Approximating someone else's grammar from examples of it is how a matcher acquires
# silent false negatives; a bounded subset that says so is honest, a wildcard heuristic
# is not.
_GLOB_CHARS = set("*?[]+!")


class Unsupported(Exception):
    """A construct this script has not modelled. Always fatal, never skipped."""


def _match_prefix(pattern: str) -> tuple[str, bool]:
    """Return (literal, is_recursive) for a supported pattern, or raise Unsupported."""
    if pattern.endswith("/**"):
        literal = pattern[: -len("/**")]
        recursive = True
    else:
        literal = pattern
        recursive = False
    if set(literal) & _GLOB_CHARS:
        raise Unsupported(
            f"path filter {pattern!r} uses glob syntax this script does not model; "
            f"extend _match_prefix() in {__file__} rather than loosening the check"
        )
    return literal, recursive


def matches(pattern: str, path: str) -> bool:
    """Does a supported GitHub path filter match this repo-relative path?"""
    literal, recursive = _match_prefix(pattern)
    return path.startswith(literal + "/") if recursive else path == literal


def covers_dir(pattern: str, directory: str) -> bool:
    """Does the filter fire for a change to any file inside `directory`?"""
    return matches(pattern, directory + "/probe.tf")


def discover_terraform_dirs(repo: Path) -> tuple[list[str], list[str]]:
    """Inventory from disk. Returns (directories, problems-with-the-roots-themselves)."""
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
            if d.is_dir() and any(d.glob("*.tf"))
        )
        if not here:
            problems.append(
                f"inventory root {root_name}/ matched no directory containing .tf -- an "
                f"empty inventory agrees with any manifest, so this is a failure, not a pass"
            )
        found.extend(here)
    return found, problems


def module_dependencies(repo: Path, env_dir: str) -> set[str]:
    """Modules an environment consumes, read from its own `source = "../../modules/x"`."""
    deps: set[str] = set()
    needle = '"../../modules/'
    for tf in sorted((repo / env_dir).glob("*.tf")):
        for raw in tf.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line.startswith("source") or needle not in line:
                continue
            tail = line.split(needle, 1)[1]
            name = tail.split('"', 1)[0].strip("/")
            if name:
                deps.add(f"modules/{name}")
    return deps


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
            problems.append(f"{path}: will not parse as YAML ({exc.__class__.__name__}); "
                            f"an unreadable workflow is COULD NOT VERIFY, not clean")
            continue
        if not isinstance(doc, dict):
            problems.append(f"{path}: top level is {type(doc).__name__}, expected a mapping")
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


def pr_filters(doc: dict) -> tuple[bool, list[str]]:
    """Return (has_pull_request_trigger, path_filters). No `paths:` means every path."""
    on = triggers(doc)
    if "pull_request" not in on:
        return False, []
    block = on["pull_request"]
    if block is None:
        return True, []
    if not isinstance(block, dict):
        raise Unsupported(f"on.pull_request is {type(block).__name__}, expected a mapping")
    if "paths-ignore" in block:
        raise Unsupported(
            "on.pull_request.paths-ignore is not modelled by this script; it inverts the "
            "matching rule, so treating it as a `paths` list would report coverage that "
            "does not exist"
        )
    paths = block.get("paths")
    if paths is None:
        return True, []
    if not isinstance(paths, list) or not all(isinstance(p, str) for p in paths):
        raise Unsupported("on.pull_request.paths must be a list of strings")
    return True, paths


# What counts as "this step runs tflint". Stated once, here, because two independent
# answers to that question WILL diverge -- and the first version of this file had exactly
# that, with `startswith("tflint")` in both. That prefix test also matched the workflow
# INPUT declaration `tflint_version:`, so terraform-plan.yaml counted as lint-capable even
# with every tflint command deleted from it; the self-test caught it. A prefix test is not
# a grammar.
#
# The grammar this models, deliberately small and stated rather than guessed:
#   * a `run:` block is split into lines, then into segments on ; && || |
#   * a segment invokes tflint iff its FIRST shell word is exactly "tflint"
# A tflint reached any other way -- a wrapper script, a Makefile target, an alias -- is
# NOT detected. That is a real limit; extend this function rather than working around it,
# because everything downstream reads coverage from what it returns.
_SEPARATORS = (";", "&&", "||", "|")


def _runs_tflint(run_block: str) -> bool:
    for line in run_block.splitlines():
        segment = line.strip()
        for sep in _SEPARATORS:
            segment = segment.replace(sep, "\n")
        for part in segment.split("\n"):
            words = part.split()
            if words and words[0] == "tflint":
                return True
    return False


def tflint_run_steps(workflows: list[dict]):
    """Every (workflow, job name, step label, env-scopes) whose run block invokes tflint.

    The single derivation of "runs tflint". Both the coverage model and the config check
    read this, so they cannot disagree about which steps exist.
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
                if not isinstance(run, str) or not _runs_tflint(run):
                    continue
                step_env = step.get("env") if isinstance(step.get("env"), dict) else {}
                label = step.get("name") or f"steps[{index}]"
                yield wf, job_name, label, (step_env, job_env, wf_env)


def lint_capable(workflows: list[dict]) -> set[str]:
    """Local reusable-workflow paths that actually run tflint, as a caller would `uses:` them."""
    return {"./" + wf["rel"] for wf, _, _, _ in tflint_run_steps(workflows)}


def planned_dirs(doc: dict, capable: set[str]) -> list[str]:
    """working_directory values this workflow hands to a lint-capable reusable workflow."""
    out = []
    jobs = doc.get("jobs")
    if not isinstance(jobs, dict):
        return out
    for job in jobs.values():
        if not isinstance(job, dict):
            continue
        uses = job.get("uses")
        with_ = job.get("with")
        if not isinstance(uses, str) or not isinstance(with_, dict):
            continue
        if uses not in capable:
            continue
        wd = with_.get("working_directory")
        if isinstance(wd, str) and wd not in (".", ""):
            out.append(wd.rstrip("/"))
    return out


def tflint_steps_missing_config(workflows: list[dict]) -> list[str]:
    """Every step that runs tflint must have TFLINT_CONFIG_FILE in scope.

    A workflow-level or job-level `env:` satisfies this as well as a step-level one, so
    all three scopes are checked -- narrowing it to the step would reject a correct
    workflow, and a guard that misfires gets relaxed rather than satisfied.
    """
    missing = []
    for wf, job_name, label, envs in tflint_run_steps(workflows):
        if any("TFLINT_CONFIG_FILE" in scope for scope in envs):
            continue
        missing.append(
            f"{wf['rel']}: job {job_name!r} step {label!r} runs tflint without "
            f"TFLINT_CONFIG_FILE. tflint looks for .tflint.hcl in its working "
            f"directory only, so the root config is not found and the AWS ruleset "
            f"silently does not load"
        )
    return missing


def load_exclusions(repo: Path) -> tuple[dict[str, str], list[str]]:
    """Read the exclusions manifest. Absent is fine; malformed is a failure."""
    path = repo / EXCLUSIONS_FILE
    if not path.exists():
        return {}, []
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return {}, [f"{EXCLUSIONS_FILE}: will not parse as JSON ({exc})"]
    entries = doc.get("excluded") if isinstance(doc, dict) else None
    if not isinstance(entries, list):
        return {}, [f"{EXCLUSIONS_FILE}: expected a top-level object with an 'excluded' list"]
    out: dict[str, str] = {}
    problems: list[str] = []
    for entry in entries:
        if not isinstance(entry, dict) or not isinstance(entry.get("path"), str):
            problems.append(f"{EXCLUSIONS_FILE}: each entry needs a string 'path'")
            continue
        reason = entry.get("reason")
        if not isinstance(reason, str) or not reason.strip():
            problems.append(
                f"{EXCLUSIONS_FILE}: {entry['path']} has no 'reason'. An exclusion without "
                f"a recorded reason is indistinguishable from an oversight"
            )
            continue
        out[entry["path"].rstrip("/")] = reason
    return out, problems


def run(repo: Path) -> list[str]:
    failures: list[str] = []

    tf_dirs, root_problems = discover_terraform_dirs(repo)
    failures.extend(root_problems)

    workflows, wf_problems = load_workflows(repo)
    failures.extend(wf_problems)
    if not workflows:
        return failures

    capable = lint_capable(workflows)
    if not capable:
        failures.append(
            "no workflow in .github/workflows runs tflint, so no directory can be covered; "
            "if linting moved, update lint_capable() rather than deleting this check"
        )

    # ---- check 1: tflint is actually configured wherever it runs --------------------
    failures.extend(tflint_steps_missing_config(workflows))

    # ---- gather callers, refusing anything unmodelled -------------------------------
    callers = []
    for wf in workflows:
        try:
            has_pr, filters = pr_filters(wf["doc"])
        except Unsupported as exc:
            failures.append(f"{wf['rel']}: {exc}")
            continue
        if not has_pr:
            continue
        try:
            for pattern in filters:
                _match_prefix(pattern)
        except Unsupported as exc:
            failures.append(f"{wf['rel']}: {exc}")
            continue
        callers.append({
            "rel": wf["rel"],
            "filters": filters,
            "planned": planned_dirs(wf["doc"], capable),
        })

    def fires_for(caller: dict, directory: str) -> bool:
        # No `paths:` at all means the workflow runs for every pull request.
        if not caller["filters"]:
            return True
        return any(covers_dir(p, directory) for p in caller["filters"])

    covered: dict[str, str] = {}
    for caller in callers:
        if not caller["planned"]:
            continue
        for directory in tf_dirs:
            is_env = directory.startswith("environments/")
            planned_here = directory in caller["planned"]
            if is_env and not planned_here:
                continue  # some other workflow may plan it
            if fires_for(caller, directory):
                covered.setdefault(directory, caller["rel"])

    excluded, excl_problems = load_exclusions(repo)
    failures.extend(excl_problems)

    # ---- check 2: covered XOR excluded, for every directory on disk -----------------
    for directory in tf_dirs:
        in_cov, in_exc = directory in covered, directory in excluded
        if in_cov and in_exc:
            failures.append(
                f"{directory}: excluded in {EXCLUSIONS_FILE} AND covered by "
                f"{covered[directory]}. The recorded reason for the exclusion is no longer "
                f"true -- remove the entry"
            )
        elif not in_cov and not in_exc:
            failures.append(
                f"{directory}: contains Terraform but no workflow both plans it and "
                f"triggers on changes to it, and it is not in {EXCLUSIONS_FILE}. Add it to "
                f"a workflow's paths filter, or record why it is deliberately uncovered"
            )

    # ---- check 3: a planned environment filters on the modules it consumes ----------
    for caller in callers:
        for env_dir in caller["planned"]:
            if not env_dir.startswith("environments/"):
                continue
            if not (repo / env_dir).is_dir():
                continue  # reported by check 4
            if not fires_for(caller, env_dir):
                failures.append(
                    f"{caller['rel']}: plans {env_dir} but its paths filters do not fire "
                    f"for changes to it"
                )
            for dep in sorted(module_dependencies(repo, env_dir)):
                if not fires_for(caller, dep):
                    failures.append(
                        f"{caller['rel']}: plans {env_dir}, which consumes {dep}, but no "
                        f"paths filter fires for {dep}. Editing that module changes this "
                        f"plan and triggers no CI"
                    )

    # ---- check 4: nothing listed anywhere has gone stale ----------------------------
    on_disk = set(tf_dirs)
    for caller in callers:
        for pattern in caller["filters"]:
            literal, recursive = _match_prefix(pattern)
            target = repo / literal
            if not (target.is_dir() if recursive else target.exists()):
                failures.append(
                    f"{caller['rel']}: paths filter {pattern!r} matches nothing on disk. A "
                    f"filter pointing at a renamed or deleted path silently covers nothing"
                )
        for wd in caller["planned"]:
            directory = repo / wd
            if not directory.is_dir() or not any(directory.glob("*.tf")):
                failures.append(
                    f"{caller['rel']}: working_directory {wd!r} is not a directory "
                    f"containing .tf files"
                )
    for path in sorted(excluded):
        if path not in on_disk:
            failures.append(
                f"{EXCLUSIONS_FILE}: {path} is excluded but is not a Terraform directory on "
                f"disk. Delete the entry -- a manifest of things that no longer exist reads "
                f"as coverage"
            )

    return failures


def main(argv: list[str]) -> int:
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
