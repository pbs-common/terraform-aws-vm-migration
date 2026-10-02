#!/usr/bin/env python3
"""Mutation self-test for check_terraform_ci_coverage.py.

A checker asserts something about this repository, and that assertion can go false while
the checker keeps passing -- a guard that has silently stopped detecting anything is
indistinguishable from a clean tree. So this file does not test the checker's helpers in
isolation. It copies the real repository, reintroduces each defect shape the checker was
written for, and requires the checker to REJECT each one, with a control run proving it
accepts the tree as it actually stands.

Two things every mutation does, because skipping either turns a false pass into a green
tick:

  * asserts its anchor matched EXACTLY ONCE before editing. A mutation that did not apply
    produces a checker run over an unmodified tree, which fails the "must be rejected"
    assertion for the wrong reason -- or worse, silently matches twice and changes
    something else.
  * asserts the REASON, not just the exit code. Every mutation below makes the checker
    exit 1; matching on the exit code alone would let any mutation be "caught" by an
    unrelated failure, so each names a substring of the message it must produce.

Run: python .github/scripts/test_check_terraform_ci_coverage.py
"""

from __future__ import annotations

import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_terraform_ci_coverage as checker  # noqa: E402

REPO = Path(__file__).resolve().parents[2]


def clone_repo(dest: Path) -> Path:
    """A copy of the parts of the repository the checker reads."""
    root = dest / "repo"
    root.mkdir()
    for name in (".github", "environments", "modules"):
        src = REPO / name
        if src.is_dir():
            shutil.copytree(src, root / name)
    (root / checker.TFLINT_CONFIG).write_text(
        (REPO / checker.TFLINT_CONFIG).read_text(encoding="utf-8"), encoding="utf-8")
    return root


def edit(path: Path, old: str, new: str, *, expect: int = 1, only: int | None = None) -> None:
    """Replace `old` with `new`, asserting it appeared exactly `expect` times.

    `only=N` mutates just the Nth (1-based) occurrence, for a mutation that must reach one
    trigger and not another.
    """
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != expect:
        raise AssertionError(
            f"mutation anchor matched {count} times in {path} (expected {expect}); the "
            f"mutation did NOT apply as intended, so any verdict from this case is meaningless"
        )
    if only is None:
        text = text.replace(old, new)
    else:
        parts = text.split(old)
        text = old.join(parts[:only]) + new + old.join(parts[only:])
    path.write_text(text, encoding="utf-8")


class CheckerSelfTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = clone_repo(Path(self.tmp.name))

    def assert_rejected(self, needle: str) -> None:
        failures = checker.run(self.repo)
        self.assertTrue(failures, f"mutation was NOT caught; expected a failure mentioning {needle!r}")
        joined = "\n".join(failures)
        self.assertIn(needle, joined, f"caught, but for the wrong reason:\n{joined}")

    # ---- control ----------------------------------------------------------------
    def test_the_real_repository_passes(self) -> None:
        """The control. Without this every 'mutation rejected' below could be a checker
        that rejects everything, which catches nothing and would simply be deleted."""
        self.assertEqual(
            checker.run(self.repo), [],
            "the repository as committed must pass, or the mutation cases below prove "
            "nothing about the checker's ability to discriminate",
        )

    # A new environments/* or modules/* directory needs no workflow change to be linted --
    # --list-dirs picks it up automatically. Nothing to reject here, so no test for it.

    # ---- check 1: tflint running without a usable config ------------------------
    def test_tflint_without_config_file_is_rejected(self) -> None:
        # Remove ONLY the config line. Deleting the whole `env:` block would orphan the
        # sibling GITHUB_TOKEN and yield invalid YAML, which the checker rejects for a
        # different reason -- a mutation that lands on the wrong defect proves nothing.
        edit(self.repo / ".github/workflows/terraform-plan.yaml",
             "          TFLINT_CONFIG_FILE: ${{ github.workspace }}/.tflint.hcl\n", "")
        self.assert_rejected("runs tflint without TFLINT_CONFIG_FILE")

    def test_an_empty_tflint_config_file_is_rejected(self) -> None:
        """An empty value leaves tflint looking in its working directory, exactly as if
        the variable were unset -- so presence of the NAME is not the check."""
        edit(self.repo / ".github/workflows/terraform-plan.yaml",
             "          TFLINT_CONFIG_FILE: ${{ github.workspace }}/.tflint.hcl\n",
             '          TFLINT_CONFIG_FILE: ""\n')
        self.assert_rejected("empty value")

    def test_a_tflint_config_file_pointing_elsewhere_is_rejected(self) -> None:
        edit(self.repo / ".github/workflows/terraform-plan.yaml",
             "          TFLINT_CONFIG_FILE: ${{ github.workspace }}/.tflint.hcl\n",
             "          TFLINT_CONFIG_FILE: /tmp/somewhere-else.json\n")
        self.assert_rejected("not a recognised spelling")

    def test_the_same_basename_in_a_DIFFERENT_directory_is_rejected(self) -> None:
        """A suffix test passed /tmp/.tflint.hcl, which loads a different config with no
        AWS plugin while the guard reported success. The basename is not the check."""
        edit(self.repo / ".github/workflows/terraform-plan.yaml",
             "          TFLINT_CONFIG_FILE: ${{ github.workspace }}/.tflint.hcl\n",
             "          TFLINT_CONFIG_FILE: /tmp/.tflint.hcl\n")
        self.assert_rejected("not a recognised spelling")

    def test_a_step_level_empty_value_overrides_a_valid_job_level_one(self) -> None:
        """Scope precedence, not mere presence. A step-level empty string wins over a
        correct job-level value, so a checker that asks 'does the name appear in ANY
        scope' reports a configured step that is in fact unconfigured."""
        edit(self.repo / ".github/workflows/terraform-plan.yaml",
             "          TFLINT_CONFIG_FILE: ${{ github.workspace }}/.tflint.hcl\n",
             '          TFLINT_CONFIG_FILE: ""\n')
        edit(self.repo / ".github/workflows/terraform-plan.yaml",
             "    defaults:\n",
             "    env:\n      TFLINT_CONFIG_FILE: ${{ github.workspace }}/.tflint.hcl\n\n    defaults:\n")
        self.assert_rejected("empty value")

    def test_an_unclassifiable_tflint_command_is_rejected_not_ignored(self) -> None:
        """'Could not parse' is not a pass. `sudo tflint` is a real invocation this
        script does not model; reading it as 'no tflint here' would silently drop the
        config check for that step."""
        edit(self.repo / ".github/workflows/terraform-plan.yaml",
             "          tflint --init\n          tflint --format compact\n",
             "          sudo tflint --init\n          sudo tflint --format compact\n")
        self.assert_rejected("cannot classify as an invocation")

    def test_a_relative_tflint_config_path_is_rejected(self) -> None:
        """Relative resolves against the step's working-directory (environments/ad), not
        the repository root -- so it finds no config and loads no AWS plugin."""
        edit(self.repo / ".github/workflows/terraform-plan.yaml",
             "          TFLINT_CONFIG_FILE: ${{ github.workspace }}/.tflint.hcl\n",
             "          TFLINT_CONFIG_FILE: .tflint.hcl\n")
        self.assert_rejected("not a recognised spelling")

    def test_an_unexpanded_shell_variable_config_path_is_rejected(self) -> None:
        """A workflow `env:` value is not shell-expanded, so tflint receives the dollar
        sign literally. This spelling was briefly ACCEPTED by this checker; it does not
        work."""
        edit(self.repo / ".github/workflows/terraform-plan.yaml",
             "          TFLINT_CONFIG_FILE: ${{ github.workspace }}/.tflint.hcl\n",
             "          TFLINT_CONFIG_FILE: $GITHUB_WORKSPACE/.tflint.hcl\n")
        self.assert_rejected("not a recognised spelling")

    def test_a_conditional_tflint_step_is_rejected(self) -> None:
        """`if: false` on the lint step would disable linting repository-wide."""
        edit(self.repo / ".github/workflows/terraform-plan.yaml",
             "      - name: Run TFLint\n        env:\n",
             "      - name: Run TFLint\n        if: false\n        env:\n")
        self.assert_rejected("runs tflint under a condition")

    # ---- check 2: direct lint, the one thing this checker now enforces ----------
    def test_removing_the_direct_lint_job_is_rejected(self) -> None:
        """The core guarantee. Planning an environment does not lint its modules, so
        without this job a module regression ships with CI green."""
        wf = self.repo / ".github/workflows/ci-coverage.yaml"
        text = wf.read_text()
        marker = "  lint:\n"
        assert text.count(marker) == 1, f"anchor matched {text.count(marker)} times"
        wf.write_text(text[: text.index(marker)])
        self.assert_rejected("no unfiltered workflow runs tflint in each directory")

    def test_the_lint_job_must_be_unfiltered(self) -> None:
        """A path filter on the lint job would let a new directory dodge the lint -- the
        exact blind spot this whole check exists to close."""
        edit(self.repo / ".github/workflows/ci-coverage.yaml",
             "  pull_request:\n",
             '  pull_request:\n    paths:\n      - "environments/**"\n')
        self.assert_rejected("no unfiltered workflow runs tflint in each directory")

    def test_an_unparseable_trigger_on_the_lint_job_is_rejected(self) -> None:
        """paths-ignore on the lint job's own trigger isn't modelled, so it can no
        longer be confirmed unfiltered -- same failure as removing it outright."""
        edit(self.repo / ".github/workflows/ci-coverage.yaml",
             "  pull_request:\n",
             '  pull_request:\n    paths-ignore:\n      - "docs/**"\n')
        self.assert_rejected("no unfiltered workflow runs tflint in each directory")

    # ---- three-state: what the checker cannot model must FAIL, never skip ---------
    def test_unparseable_workflow_is_rejected(self) -> None:
        (self.repo / ".github/workflows/broken.yaml").write_text(
            "name: broken\non:\n  pull_request:\njobs:\n  a: [unclosed\n")
        self.assert_rejected("will not parse as YAML")

    def test_terraform_nested_below_an_inventory_root_is_rejected(self) -> None:
        """The inventory models immediate children only. A nested directory would never
        be listed by --list-dirs while the invariant claims to cover everything."""
        nested = self.repo / "modules" / "ec2-workload" / "submodule"
        nested.mkdir()
        (nested / "main.tf").write_text('variable "x" { type = string }\n')
        self.assert_rejected("Terraform nested below modules/ec2-workload")

    # ---- an empty inventory must not agree with everything -----------------------
    def test_empty_inventory_root_is_rejected(self) -> None:
        shutil.rmtree(self.repo / "modules")
        (self.repo / "modules").mkdir()
        self.assert_rejected("matched no directory containing .tf")

    def test_missing_inventory_root_is_rejected(self) -> None:
        shutil.rmtree(self.repo / "modules")
        self.assert_rejected("does not exist")

    def test_a_repository_with_no_tflint_anywhere_is_rejected(self) -> None:
        """Both tflint steps must go: removing only the plan pipeline's leaves the
        direct-lint job still running it, a different (also caught) defect."""
        edit(self.repo / ".github/workflows/terraform-plan.yaml",
             "          tflint --init\n          tflint --format compact\n",
             "          echo skipped\n")
        edit(self.repo / ".github/workflows/ci-coverage.yaml",
             '            ( cd "$d" && tflint --format compact ) || FAILED=1\n',
             '            ( cd "$d" && echo skipped ) || FAILED=1\n')
        edit(self.repo / ".github/workflows/ci-coverage.yaml",
             "          tflint --init\n", "          echo skipped\n")
        self.assert_rejected("no unfiltered workflow runs tflint in each directory")


class TflintInvocationGrammar(unittest.TestCase):
    """Both directions of "does this step run tflint".

    The rejection cases are not hypothetical: the first version of this checker used
    `startswith("tflint")`, which matched the workflow input declaration
    `tflint_version:`. terraform-plan.yaml therefore counted as lint-capable even with
    every tflint command removed from it. A prefix test is not a grammar.
    """

    def invokes(self, block: str) -> bool:
        return checker.classify_run_block(block)[0]

    def unclear(self, block: str) -> list[str]:
        return checker.classify_run_block(block)[1]

    def test_real_invocations_are_detected(self) -> None:
        for block in ("tflint --init\ntflint --format compact\n",
                      "  tflint\n",
                      "cd x && tflint --format compact\n",
                      "terraform init; tflint\n",
                      "TFLINT_CONFIG_FILE=/x/.tflint.hcl tflint --init\n",
                      "A=1 B=2 tflint\n"):
            with self.subTest(block=block):
                self.assertTrue(self.invokes(block))
                self.assertEqual(self.unclear(block), [])

    def test_mentions_that_are_not_invocations_are_rejected(self) -> None:
        for block in ("tflint_version: 0.64.0\n",
                      "tflint-wrapper --init\n",
                      "TFLINT_CONFIG_FILE=x true\n"):
            with self.subTest(block=block):
                self.assertFalse(self.invokes(block))
                self.assertEqual(self.unclear(block), [])

    def test_unmodelled_forms_are_flagged_rather_than_read_as_absent(self) -> None:
        """The third state. These DO run tflint; the grammar cannot prove it, so they
        must be reported, not silently treated as 'no tflint in this step'."""
        for block in ("sudo tflint --init\n", "echo tflint\n", "/usr/local/bin/tflint\n"):
            with self.subTest(block=block):
                self.assertFalse(self.invokes(block))
                self.assertTrue(self.unclear(block), "must be flagged as unclassifiable")

    def test_every_tflint_step_in_the_repository_is_configured(self) -> None:
        """Anchors the COUNT as well as the state, so a third tflint step -- or an
        unconfigured one -- cannot arrive quietly. Two are expected: the plan pipeline's,
        and the credential-free job that lints every directory."""
        workflows, problems = checker.load_workflows(REPO)
        self.assertEqual(problems, [])
        steps = list(checker.tflint_run_steps(workflows))
        self.assertEqual(len(steps), 2, f"expected two tflint steps, found {len(steps)}")
        self.assertEqual(
            sorted(wf["rel"] for wf, *_ in steps),
            [".github/workflows/ci-coverage.yaml", ".github/workflows/terraform-plan.yaml"])
        for wf, _, label, envs, unclear, conditions in steps:
            with self.subTest(step=f"{wf['rel']}:{label}"):
                self.assertEqual(unclear, [])
                self.assertEqual(conditions, [])
                self.assertIn(checker.resolve_env(envs, "TFLINT_CONFIG_FILE"),
                              checker.ROOT_CONFIG_VALUES)


class TriggerBlockParsing(unittest.TestCase):
    def test_yaml_one_dot_one_boolean_on_key_is_handled(self) -> None:
        """PyYAML parses the bare key `on` as True. Reading doc['on'] would report 'no
        triggers' for every real workflow, silently making the lint job unfindable."""
        import yaml
        doc = yaml.safe_load("on:\n  pull_request:\n    paths:\n      - \"x/**\"\n")
        self.assertIn(True, doc, "precondition: PyYAML must still fold `on` to the boolean")
        self.assertNotIn("on", doc)
        self.assertEqual(checker.trigger_filters(doc, "pull_request"), (True, ["x/**"]))

    def test_paths_ignore_is_unsupported(self) -> None:
        doc = {"on": {"pull_request": {"paths-ignore": ["docs/**"]}}}
        with self.assertRaises(checker.Unsupported):
            checker.trigger_filters(doc, "pull_request")


if __name__ == "__main__":
    unittest.main(verbosity=2)
