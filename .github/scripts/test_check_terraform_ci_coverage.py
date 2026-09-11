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

import json
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
    return root


def edit(path: Path, old: str, new: str) -> None:
    """Replace `old` with `new`, asserting it appeared exactly once."""
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise AssertionError(
            f"mutation anchor matched {count} times in {path} (expected 1); the mutation "
            f"did NOT apply as intended, so any verdict from this case is meaningless"
        )
    path.write_text(text.replace(old, new), encoding="utf-8")


class CheckerSelfTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = clone_repo(Path(self.tmp.name))

    # ---- control ----------------------------------------------------------------
    def test_the_real_repository_passes(self) -> None:
        """The control. Without this every 'mutation rejected' below could be a checker
        that rejects everything, which catches nothing and would simply be deleted."""
        self.assertEqual(
            checker.run(self.repo), [],
            "the repository as committed must pass, or the mutation cases below prove "
            "nothing about the checker's ability to discriminate",
        )

    # ---- helper -----------------------------------------------------------------
    def assert_rejected(self, needle: str) -> None:
        failures = checker.run(self.repo)
        self.assertTrue(failures, f"mutation was NOT caught; expected a failure mentioning {needle!r}")
        joined = "\n".join(failures)
        self.assertIn(needle, joined, f"caught, but for the wrong reason:\n{joined}")

    # ---- check 2: an uncovered ADDITION, the defect issue #38 is about ------------
    def test_new_environment_directory_is_rejected(self) -> None:
        new = self.repo / "environments" / "brand-new-env"
        new.mkdir()
        (new / "main.tf").write_text('resource "null_resource" "x" {}\n')
        self.assert_rejected("environments/brand-new-env: contains Terraform but no workflow")

    def test_new_module_directory_is_rejected(self) -> None:
        new = self.repo / "modules" / "brand-new-module"
        new.mkdir()
        (new / "main.tf").write_text('variable "x" { type = string }\n')
        self.assert_rejected("modules/brand-new-module: contains Terraform but no workflow")

    # ---- check 3: a module consumed by a planned environment but unfiltered -------
    def test_dropping_a_consumed_module_from_the_filters_is_rejected(self) -> None:
        edit(self.repo / ".github/workflows/ad.yaml",
             '      - "modules/ssm-session-access-policy/**"\n', "")
        self.assert_rejected("consumes modules/ssm-session-access-policy")

    def test_a_newly_consumed_module_must_be_filtered(self) -> None:
        new = self.repo / "modules" / "late-arrival"
        new.mkdir()
        (new / "main.tf").write_text('variable "x" { type = string }\n')
        main = self.repo / "environments/ad/main.tf"
        main.write_text(
            main.read_text()
            + '\nmodule "late" {\n  source = "../../modules/late-arrival"\n}\n'
        )
        self.assert_rejected("consumes modules/late-arrival")

    # ---- check 1: tflint running without its config ------------------------------
    def test_tflint_without_config_file_is_rejected(self) -> None:
        edit(self.repo / ".github/workflows/terraform-plan.yaml",
             "        env:\n"
             "          TFLINT_CONFIG_FILE: ${{ github.workspace }}/.tflint.hcl\n", "")
        self.assert_rejected("runs tflint without TFLINT_CONFIG_FILE")

    # ---- check 4: the manifest and the filters going stale -----------------------
    def test_exclusion_for_a_directory_that_does_not_exist_is_rejected(self) -> None:
        path = self.repo / checker.EXCLUSIONS_FILE
        doc = json.loads(path.read_text())
        doc["excluded"].append({"path": "modules/deleted-long-ago", "reason": "stale"})
        path.write_text(json.dumps(doc, indent=2))
        self.assert_rejected("modules/deleted-long-ago is excluded but is not a Terraform directory")

    def test_exclusion_without_a_reason_is_rejected(self) -> None:
        path = self.repo / checker.EXCLUSIONS_FILE
        doc = json.loads(path.read_text())
        doc["excluded"].append({"path": "environments/ad"})
        path.write_text(json.dumps(doc, indent=2))
        self.assert_rejected("has no 'reason'")

    def test_excluded_but_actually_covered_is_rejected(self) -> None:
        """An exclusion that has been overtaken by real coverage states a reason that is
        no longer true, which is the stale-prose class in a manifest."""
        path = self.repo / checker.EXCLUSIONS_FILE
        doc = json.loads(path.read_text())
        doc["excluded"].append({"path": "environments/ad", "reason": "no longer true"})
        path.write_text(json.dumps(doc, indent=2))
        self.assert_rejected("AND covered by")

    def test_path_filter_matching_nothing_is_rejected(self) -> None:
        edit(self.repo / ".github/workflows/ad.yaml",
             '      - "environments/ad/**"\n',
             '      - "environments/ad/**"\n      - "modules/renamed-away/**"\n')
        self.assert_rejected("matches nothing on disk")

    def test_working_directory_that_does_not_exist_is_rejected(self) -> None:
        edit(self.repo / ".github/workflows/ad.yaml",
             '      tflint_version: "0.64.0"\n      aws_region: us-east-1\n'
             "      working_directory: environments/ad\n",
             '      tflint_version: "0.64.0"\n      aws_region: us-east-1\n'
             "      working_directory: environments/gone\n")
        self.assert_rejected("is not a directory containing .tf files")

    # ---- three-state: what the checker cannot model must FAIL, never skip ---------
    def test_unsupported_glob_shape_is_rejected(self) -> None:
        edit(self.repo / ".github/workflows/ad.yaml",
             '      - "environments/ad/**"\n',
             '      - "environments/ad/**"\n      - "modules/*/main.tf"\n')
        self.assert_rejected("glob syntax this script does not model")

    def test_paths_ignore_is_rejected_rather_than_guessed_at(self) -> None:
        edit(self.repo / ".github/workflows/ad.yaml",
             "  pull_request:\n    paths:\n",
             "  pull_request:\n    paths-ignore:\n      - \"docs/**\"\n    paths:\n")
        self.assert_rejected("paths-ignore is not modelled")

    def test_unparseable_workflow_is_rejected(self) -> None:
        (self.repo / ".github/workflows/broken.yaml").write_text(
            "name: broken\non:\n  pull_request:\njobs:\n  a: [unclosed\n")
        self.assert_rejected("will not parse as YAML")

    # ---- vacuity: an empty inventory must not agree with everything ---------------
    def test_empty_inventory_root_is_rejected(self) -> None:
        shutil.rmtree(self.repo / "modules")
        (self.repo / "modules").mkdir()
        self.assert_rejected("matched no directory containing .tf")

    def test_missing_inventory_root_is_rejected(self) -> None:
        shutil.rmtree(self.repo / "modules")
        self.assert_rejected("does not exist")

    def test_a_repository_with_no_tflint_anywhere_is_rejected(self) -> None:
        edit(self.repo / ".github/workflows/terraform-plan.yaml",
             "          tflint --init\n          tflint --format compact\n",
             "          echo skipped\n")
        self.assert_rejected("no workflow in .github/workflows runs tflint")


class TflintInvocationGrammar(unittest.TestCase):
    """Both directions of "does this step run tflint".

    The rejection cases are not hypothetical: the first version of this checker used
    `startswith("tflint")`, which matched the workflow input declaration
    `tflint_version:`. terraform-plan.yaml therefore counted as lint-capable with every
    tflint command removed from it, and the whole coverage model rested on that answer.
    """

    def test_real_invocations_are_detected(self) -> None:
        for block in ("tflint --init\ntflint --format compact\n",
                      "  tflint\n",
                      "cd x && tflint --format compact\n",
                      "terraform init; tflint\n"):
            with self.subTest(block=block):
                self.assertTrue(checker._runs_tflint(block))

    def test_mentions_that_are_not_invocations_are_rejected(self) -> None:
        for block in ("tflint_version: 0.64.0\n",
                      "echo tflint\n",
                      "# tflint --init\n",
                      "tflint-wrapper --init\n",
                      "TFLINT_CONFIG_FILE=x true\n"):
            with self.subTest(block=block):
                self.assertFalse(checker._runs_tflint(block))

    def test_the_repository_has_exactly_one_tflint_step_and_it_is_configured(self) -> None:
        """Anchors the count, so a second unconfigured tflint step cannot arrive quietly."""
        workflows, problems = checker.load_workflows(REPO)
        self.assertEqual(problems, [])
        steps = list(checker.tflint_run_steps(workflows))
        self.assertEqual(len(steps), 1, f"expected one tflint step, found {len(steps)}")
        wf, _, _, envs = steps[0]
        self.assertEqual(wf["rel"], ".github/workflows/terraform-plan.yaml")
        self.assertTrue(any("TFLINT_CONFIG_FILE" in scope for scope in envs))


class MatcherSemantics(unittest.TestCase):
    """The path-filter subset, both directions. A matcher proven only on the strings it
    must accept is half a matcher."""

    def test_recursive_pattern_matches_only_inside_the_directory(self) -> None:
        self.assertTrue(checker.matches("modules/a/**", "modules/a/main.tf"))
        self.assertTrue(checker.matches("modules/a/**", "modules/a/deep/main.tf"))
        self.assertFalse(checker.matches("modules/a/**", "modules/a"))
        self.assertFalse(checker.matches("modules/a/**", "modules/ab/main.tf"))
        self.assertFalse(checker.matches("modules/a/**", "modules/b/main.tf"))

    def test_literal_pattern_matches_exactly(self) -> None:
        self.assertTrue(checker.matches("a/b.tf", "a/b.tf"))
        self.assertFalse(checker.matches("a/b.tf", "a/b.tf.bak"))
        self.assertFalse(checker.matches("a/b.tf", "a/b.tf/c"))

    def test_covers_dir_is_true_only_for_the_named_directory(self) -> None:
        self.assertTrue(checker.covers_dir("modules/a/**", "modules/a"))
        self.assertFalse(checker.covers_dir("modules/a/**", "modules/ab"))
        self.assertFalse(checker.covers_dir("modules/a", "modules/a"))

    def test_unsupported_shapes_raise_rather_than_returning_false(self) -> None:
        for pattern in ("modules/*/main.tf", "**/*.tf", "!modules/a/**", "modules/a?/**"):
            with self.subTest(pattern=pattern):
                with self.assertRaises(checker.Unsupported):
                    checker.matches(pattern, "modules/a/main.tf")

    def test_yaml_one_dot_one_boolean_on_key_is_handled(self) -> None:
        """PyYAML parses the bare key `on` as True. Reading doc['on'] would report 'no
        triggers' for every real workflow, silently making every directory uncovered."""
        import yaml
        doc = yaml.safe_load("on:\n  pull_request:\n    paths:\n      - \"x/**\"\n")
        self.assertIn(True, doc, "precondition: PyYAML must still fold `on` to the boolean")
        self.assertNotIn("on", doc)
        self.assertEqual(checker.pr_filters(doc), (True, ["x/**"]))


if __name__ == "__main__":
    unittest.main(verbosity=2)
