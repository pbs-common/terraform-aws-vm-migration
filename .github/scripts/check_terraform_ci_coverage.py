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

SIX CHECKS, and each direction matters:

  1. CONFIG      every workflow step that runs tflint resolves TFLINT_CONFIG_FILE to the
                 repository-root config. tflint reads .tflint.hcl from its OWN working
                 directory and never walks up to the repository root, and
                 terraform-plan.yaml sets defaults.run.working-directory to the
                 environment being planned. Without the explicit path the root config is
                 invisible, `tflint --init` installs nothing, the AWS ruleset silently
                 does not run, and the step still passes.
  2. COVERAGE    every Terraform directory is covered, or excluded -- never neither, and
                 never both. "Both" matters: an excluded directory that has since been
                 wired into CI means the manifest's stated reason is now false.
  3. DEPENDENCY  a workflow that plans an environment filters on every module that
                 environment consumes. Otherwise editing the module changes the plan and
                 triggers nothing -- coverage of the environment without coverage of its
                 inputs.
  4. SHARED      a workflow that plans anything also filters on the inputs that decide
                 what its plan and lint DO: the root tflint config, and every reusable
                 workflow it calls. Without this, a pull request changing the linting is
                 never checked by the linting.
  5. STALENESS   every path filter, every working_directory and every exclusion still
                 names something that exists. An allow-list checked only in the direction
                 "everything listed still exists" is blind to additions; one checked only
                 as "everything that exists is listed" rots into entries matching nothing.
  6. VACUITY     the inventory roots exist and are non-empty, and at least one workflow
                 actually runs tflint.

Anything this script cannot parse or cannot model is a FAILURE, never a skip. A checker
has three outcomes -- verified pass, verified fail, and could-not-verify -- and the third
one silently joining the first is the defect class this whole file exists to prevent. That
is why every `Unsupported` below is raised rather than swallowed: a construct this script
has not modelled must stop the build and be modelled, not be quietly read as "absent".

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
TFLINT_CONFIG = ".tflint.hcl"

# Triggers that can carry path filters and can therefore decide whether a plan runs.
# Enumerated rather than assumed: the first version of this script read only
# `pull_request`, so a stale `push.paths` filter could stop the main-branch plan while
# check 5 still reported every filter healthy.
CHANGE_TRIGGERS = ("pull_request", "pull_request_target", "push")

# GitHub's path-filter syntax supports *, **, ?, +, ! and character ranges. This script
# deliberately implements only the two shapes the repository actually uses, and REFUSES
# anything else rather than guessing at semantics it has not modelled:
#
#     "a/b/**"   every path under a/b
#     "a/b"      exactly a/b
#
# A pattern outside that subset fails with a message saying to extend the matcher.
# Approximating someone else's grammar from examples of it is how a matcher acquires
# silent false negatives; a bounded subset that says so is honest, a wildcard heuristic
# is not.
_GLOB_CHARS = set("*?[]+!")


class Unsupported(Exception):
    """A construct this script has not modelled. Always fatal, never skipped."""


# --------------------------------------------------------------------------------------
# Path filters
# --------------------------------------------------------------------------------------

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
            f"extend _match_prefix() rather than loosening the check"
        )
    return literal, recursive


def matches(pattern: str, path: str) -> bool:
    """Does a supported GitHub path filter match this repo-relative path?"""
    literal, recursive = _match_prefix(pattern)
    return path.startswith(literal + "/") if recursive else path == literal


def covers_dir(pattern: str, directory: str) -> bool:
    """Does the filter fire for a change to any file inside `directory`?"""
    return matches(pattern, directory + "/probe.tf")


# --------------------------------------------------------------------------------------
# Job `if:` conditions
# --------------------------------------------------------------------------------------
#
# A job gated off for pull requests is not coverage, however good its path filters are.
# Reading the condition needs an evaluator, and reimplementing another system's expression
# language wholesale is exactly how a checker acquires an unbounded bug surface -- so this
# models a deliberately tiny subset and REFUSES the rest:
#
#     expr       := term ('||' term)*
#     term       := factor ('&&' factor)*
#     factor     := '(' expr ')' | comparison
#     comparison := context ('==' | '!=') <single-quoted literal>
#     context    := github.event_name | github.ref
#
# Anything else -- a function call, a different context, a bare identifier -- raises
# Unsupported so the build stops and a human decides, rather than the job being silently
# treated as either always-running or never-running.

_EVENT_CONTEXTS = ("github.event_name", "github.ref")


def _tokenize_condition(text: str) -> list[str]:
    text = text.strip()
    if text.startswith("${{") and text.endswith("}}"):
        text = text[3:-2].strip()
    tokens: list[str] = []
    i = 0
    while i < len(text):
        ch = text[i]
        if ch.isspace():
            i += 1
        elif text.startswith("&&", i) or text.startswith("||", i) or text.startswith("==", i) \
                or text.startswith("!=", i):
            tokens.append(text[i:i + 2]); i += 2
        elif ch in "()":
            tokens.append(ch); i += 1
        elif ch == "'":
            end = text.find("'", i + 1)
            if end == -1:
                raise Unsupported(f"unterminated string in condition {text!r}")
            tokens.append(text[i:end + 1]); i = end + 1
        else:
            start = i
            while i < len(text) and not text[i].isspace() and text[i] not in "()" \
                    and not text.startswith("&&", i) and not text.startswith("||", i) \
                    and not text.startswith("==", i) and not text.startswith("!=", i):
                i += 1
            if i == start:
                raise Unsupported(f"cannot tokenize condition {text!r} at offset {i}")
            tokens.append(text[start:i])
    return tokens


def evaluate_condition(text: str, context: dict[str, str]) -> bool:
    """Evaluate a supported `if:` expression, or raise Unsupported."""
    tokens = _tokenize_condition(text)
    pos = 0

    def peek() -> str | None:
        return tokens[pos] if pos < len(tokens) else None

    def take() -> str:
        nonlocal pos
        if pos >= len(tokens):
            raise Unsupported(f"condition {text!r} ended unexpectedly")
        pos += 1
        return tokens[pos - 1]

    def parse_expr() -> bool:
        value = parse_term()
        while peek() == "||":
            take()
            value = parse_term() or value
        return value

    def parse_term() -> bool:
        value = parse_factor()
        while peek() == "&&":
            take()
            value = parse_factor() and value
        return value

    def parse_factor() -> bool:
        if peek() == "(":
            take()
            value = parse_expr()
            if take() != ")":
                raise Unsupported(f"unbalanced parentheses in condition {text!r}")
            return value
        left = take()
        if left not in _EVENT_CONTEXTS:
            raise Unsupported(
                f"condition {text!r} reads {left!r}, which this script does not model; "
                f"supported contexts are {', '.join(_EVENT_CONTEXTS)}"
            )
        op = take()
        if op not in ("==", "!="):
            raise Unsupported(f"unsupported operator {op!r} in condition {text!r}")
        literal = take()
        if not (literal.startswith("'") and literal.endswith("'") and len(literal) >= 2):
            raise Unsupported(
                f"condition {text!r} compares against {literal!r}; only single-quoted "
                f"string literals are modelled"
            )
        actual = context.get(left, "")
        wanted = literal[1:-1]
        return actual == wanted if op == "==" else actual != wanted

    result = parse_expr()
    if pos != len(tokens):
        raise Unsupported(f"trailing tokens in condition {text!r}")
    return result


# A pull_request event, as the runner would present it. `github.ref` on a pull request is
# refs/pull/<n>/merge -- never refs/heads/main, which is what makes apply-style jobs
# correctly evaluate to false here.
PULL_REQUEST_CONTEXT = {
    "github.event_name": "pull_request",
    "github.ref": "refs/pull/1/merge",
}


# --------------------------------------------------------------------------------------
# Inventory
# --------------------------------------------------------------------------------------

def discover_terraform_dirs(repo: Path) -> tuple[list[str], list[str]]:
    """Inventory from disk. Returns (directories, problems).

    Only IMMEDIATE children of each root are modelled. A Terraform directory nested
    deeper is reported as a failure rather than ignored -- ignoring it would let a
    directory be added that is neither covered nor excluded while the stated invariant
    claims to cover every Terraform directory.
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
                        f"so this directory would be neither covered nor excluded. Decide "
                        f"deliberately: flatten it, or teach discover_terraform_dirs() how "
                        f"nested directories are linted"
                    )
                    break
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
                yield wf, job_name, label, (step_env, job_env, wf_env), unclear


def lint_capable(workflows: list[dict]) -> set[str]:
    """Local reusable-workflow paths that run tflint, as a caller would `uses:` them."""
    return {"./" + wf["rel"] for wf, _, _, _, unclear in tflint_run_steps(workflows)
            if not unclear}


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
    for wf, job_name, label, envs, unclear in tflint_run_steps(workflows):
        where = f"{wf['rel']}: job {job_name!r} step {label!r}"
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
        elif not str(value).strip().endswith(TFLINT_CONFIG):
            problems.append(
                f"{where} sets TFLINT_CONFIG_FILE to {value!r}, which does not point at "
                f"{TFLINT_CONFIG}. Only the repository-root config declares the AWS plugin"
            )
    return problems


def called_workflows(doc: dict) -> set[str]:
    """Local reusable workflows this workflow calls, as written in `uses:`."""
    out = set()
    jobs = doc.get("jobs")
    if not isinstance(jobs, dict):
        return out
    for job in jobs.values():
        if isinstance(job, dict) and isinstance(job.get("uses"), str) \
                and job["uses"].startswith("./"):
            out.add(job["uses"])
    return out


def planned_dirs(doc: dict, capable: set[str], rel: str) -> tuple[list[str], list[str]]:
    """working_directory values handed to a lint-capable reusable workflow.

    A job whose `if:` is false for a pull request is NOT coverage, so the condition is
    evaluated rather than ignored. An unmodelled condition raises, and the caller turns
    that into a failure.
    """
    out: list[str] = []
    problems: list[str] = []
    jobs = doc.get("jobs")
    if not isinstance(jobs, dict):
        return out, problems
    for job_name, job in jobs.items():
        if not isinstance(job, dict):
            continue
        uses, with_ = job.get("uses"), job.get("with")
        if not isinstance(uses, str) or not isinstance(with_, dict) or uses not in capable:
            continue
        wd = with_.get("working_directory")
        if not isinstance(wd, str) or wd in (".", ""):
            continue
        condition = job.get("if")
        if condition is not None:
            try:
                if not evaluate_condition(str(condition), PULL_REQUEST_CONTEXT):
                    continue  # gated off for pull requests: correctly not coverage
            except Unsupported as exc:
                problems.append(
                    f"{rel}: job {job_name!r} has an `if:` this script cannot evaluate, so "
                    f"whether it runs for a pull request is unknown and its coverage cannot "
                    f"be trusted -- {exc}"
                )
                continue
        out.append(wd.rstrip("/"))
    return out, problems


# --------------------------------------------------------------------------------------
# Exclusions
# --------------------------------------------------------------------------------------

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


# --------------------------------------------------------------------------------------

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
            "if linting moved, update the tflint grammar rather than deleting this check"
        )

    # ---- check 1: tflint is actually configured wherever it runs --------------------
    failures.extend(tflint_config_problems(workflows))

    # ---- gather callers, refusing anything unmodelled -------------------------------
    callers = []
    for wf in workflows:
        try:
            has_pr, pr_paths = trigger_filters(wf["doc"], "pull_request")
            all_patterns: list[str] = []
            for trigger in CHANGE_TRIGGERS:
                present, patterns = trigger_filters(wf["doc"], trigger)
                if present:
                    all_patterns.extend(patterns)
            for pattern in all_patterns:
                _match_prefix(pattern)
        except Unsupported as exc:
            failures.append(f"{wf['rel']}: {exc}")
            continue
        if not has_pr:
            continue
        planned, planned_problems = planned_dirs(wf["doc"], capable, wf["rel"])
        failures.extend(planned_problems)
        callers.append({
            "rel": wf["rel"],
            "doc": wf["doc"],
            "filters": pr_paths,
            "all_patterns": all_patterns,
            "planned": planned,
        })

    def fires_for_path(caller: dict, path: str) -> bool:
        # No `paths:` at all means the workflow runs for every pull request.
        if not caller["filters"]:
            return True
        return any(matches(p, path) for p in caller["filters"])

    def fires_for(caller: dict, directory: str) -> bool:
        if not caller["filters"]:
            return True
        return any(covers_dir(p, directory) for p in caller["filters"])

    # ---- coverage model -------------------------------------------------------------
    # An environment is covered when a caller PLANS it and fires for it.
    # A module is covered when a caller plans an environment that CONSUMES it and fires
    # for it -- a path filter alone is not coverage, because a filter matching a module
    # nothing plans triggers a run that never loads that module.
    covered: dict[str, str] = {}
    for caller in callers:
        for env_dir in caller["planned"]:
            if not env_dir.startswith("environments/"):
                if env_dir in tf_dirs and fires_for(caller, env_dir):
                    covered.setdefault(env_dir, caller["rel"])  # a directly planned module
                continue
            if env_dir not in tf_dirs or not fires_for(caller, env_dir):
                continue
            covered.setdefault(env_dir, caller["rel"])
            for dep in sorted(module_dependencies(repo, env_dir)):
                if dep in tf_dirs and fires_for(caller, dep):
                    covered.setdefault(dep, f"{caller['rel']} (via {env_dir})")

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
            if not env_dir.startswith("environments/") or not (repo / env_dir).is_dir():
                continue
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

    # ---- check 4: shared inputs that decide what the plan and lint DO ---------------
    for caller in callers:
        if not caller["planned"]:
            continue
        shared = [TFLINT_CONFIG] + sorted(
            w[2:] for w in called_workflows(caller["doc"]) if w.startswith("./")
        )
        for path in shared:
            if not (repo / path).exists():
                continue  # reported by check 5 if it is a filter; otherwise not our business
            if not fires_for_path(caller, path):
                failures.append(
                    f"{caller['rel']}: plans {caller['planned']} but no paths filter fires "
                    f"for {path}, which decides what that plan and its tflint step do. A "
                    f"pull request changing it would run no plan and no lint"
                )

    # ---- check 5: nothing listed anywhere has gone stale ----------------------------
    on_disk = set(tf_dirs)
    for caller in callers:
        for pattern in caller["all_patterns"]:
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
