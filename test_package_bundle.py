from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("package-bundle.py")
SPEC = importlib.util.spec_from_file_location("package_bundle", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
package_bundle = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = package_bundle
SPEC.loader.exec_module(package_bundle)


class ScannerTests(unittest.TestCase):
    def test_finds_only_executable_requires(self) -> None:
        source = """
-- require("./comment")
local text = 'require("./string")'
local module = require ( -- comment
    "./module"
)
"""
        calls = package_bundle.find_require_calls(source, "main.luau")

        self.assertEqual([call.requested_path for call in calls], ["./module"])

    def test_accepts_repo_root_style_requires(self) -> None:
        source = """
local a = require("bundles/Example/module")
local b = require("helpers/shared/tool")
"""
        calls = package_bundle.find_require_calls(source, "main.luau")

        self.assertEqual(
            [call.requested_path for call in calls],
            ["bundles/Example/module", "helpers/shared/tool"],
        )

    def test_rejects_dynamic_require(self) -> None:
        with self.assertRaisesRegex(
            package_bundle.PackagingError, "quoted relative path"
        ):
            package_bundle.find_require_calls("require(module_name)", "main.luau")

    def test_rejects_non_relative_require(self) -> None:
        with self.assertRaisesRegex(
            package_bundle.PackagingError, "must be relative"
        ):
            package_bundle.find_require_calls('require("module")', "main.luau")


class BuilderTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.bundle = Path(self.temporary_directory.name)
        self.original_repo_root = package_bundle.REPO_ROOT

    def tearDown(self) -> None:
        package_bundle.REPO_ROOT = self.original_repo_root
        self.temporary_directory.cleanup()

    def write(self, relative_path: str, source: str) -> Path:
        path = self.bundle / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(source, encoding="utf-8")
        return path

    def set_repo_root(self, path: Path) -> None:
        package_bundle.REPO_ROOT = path.resolve()

    def test_collects_nested_dependencies_and_rewrites_requires(self) -> None:
        entry = self.write(
            "main.luau",
            'local value = require("./modules/value")\nreturn value\n',
        )
        self.write(
            "modules/value.luau",
            'return require("../shared/result")\n',
        )
        self.write("shared/result.luau", "return 0\n")

        builder = package_bundle.BundleBuilder(self.bundle)
        entry_id = builder.collect(entry)
        rewritten = package_bundle.rewrite_requires(builder.modules["main.luau"])

        self.assertEqual(entry_id, "main.luau")
        self.assertEqual(
            set(builder.modules),
            {"main.luau", "modules/value.luau", "shared/result.luau"},
        )
        self.assertIn('__bundle_require("modules/value.luau")', rewritten)

    def test_detects_dependency_cycle(self) -> None:
        entry = self.write("main.luau", 'return require("./other")\n')
        self.write("other.luau", 'return require("./main")\n')

        with self.assertRaisesRegex(
            package_bundle.PackagingError,
            r"main\.luau -> other\.luau -> main\.luau",
        ):
            package_bundle.BundleBuilder(self.bundle).collect(entry)

    def test_rejects_missing_dependency(self) -> None:
        entry = self.write("main.luau", 'return require("./missing")\n')

        with self.assertRaisesRegex(
            package_bundle.PackagingError, "does not exist"
        ):
            package_bundle.BundleBuilder(self.bundle).collect(entry)

    def test_rejects_path_escape(self) -> None:
        entry = self.write("main.luau", 'return require("../outside")\n')

        with self.assertRaisesRegex(
            package_bundle.PackagingError, "outside the bundle"
        ):
            package_bundle.BundleBuilder(self.bundle).collect(entry)

    def test_collects_repo_root_style_dependency_in_bundle(self) -> None:
        repo_root = self.bundle / "repo"
        bundle_root = repo_root / "bundles" / "Example"
        entry = bundle_root / "main.luau"
        entry.parent.mkdir(parents=True, exist_ok=True)
        entry.write_text(
            'local module = require("bundles/Example/modules/value")\nreturn module\n',
            encoding="utf-8",
        )
        (bundle_root / "modules").mkdir(parents=True, exist_ok=True)
        (bundle_root / "modules" / "value.luau").write_text("return 0\n", encoding="utf-8")
        self.set_repo_root(repo_root)

        builder = package_bundle.BundleBuilder(bundle_root)
        entry_id = builder.collect(entry)
        rewritten = package_bundle.rewrite_requires(builder.modules["main.luau"])

        self.assertEqual(entry_id, "main.luau")
        self.assertIn('__bundle_require("modules/value.luau")', rewritten)

    def test_rejects_repo_root_style_path_outside_bundle(self) -> None:
        repo_root = self.bundle / "repo"
        bundle_root = repo_root / "bundles" / "Example"
        entry = bundle_root / "main.luau"
        entry.parent.mkdir(parents=True, exist_ok=True)
        entry.write_text('return require("helpers/shared/tool")\n', encoding="utf-8")
        (repo_root / "helpers" / "shared").mkdir(parents=True, exist_ok=True)
        (repo_root / "helpers" / "shared" / "tool.luau").write_text(
            "return 0\n",
            encoding="utf-8",
        )
        self.set_repo_root(repo_root)

        with self.assertRaisesRegex(
            package_bundle.PackagingError, "outside the bundle"
        ):
            package_bundle.BundleBuilder(bundle_root).collect(entry)

    def test_rejects_missing_repo_root_style_dependency(self) -> None:
        repo_root = self.bundle / "repo"
        bundle_root = repo_root / "bundles" / "Example"
        entry = bundle_root / "main.luau"
        entry.parent.mkdir(parents=True, exist_ok=True)
        entry.write_text(
            'return require("bundles/Example/shared/missing")\n',
            encoding="utf-8",
        )
        self.set_repo_root(repo_root)

        with self.assertRaisesRegex(
            package_bundle.PackagingError, "does not exist"
        ):
            package_bundle.BundleBuilder(bundle_root).collect(entry)


class TemplateTests(unittest.TestCase):
    def test_renders_all_helper_markers(self) -> None:
        module = package_bundle.Module(
            module_id="main.luau",
            path=Path("main.luau"),
            source="return 0\n",
            requires=[],
        )
        helper = "\n".join(package_bundle.TEMPLATE_MARKERS.values())

        output = package_bundle.render_helper(
            helper,
            "Example",
            "main.luau",
            {"main.luau": module},
            "abcdefgh_script",
        )

        self.assertNotIn("DO NOT TOUCH", output)
        self.assertIn('"Example"', output)
        self.assertIn('"abcdefgh_script"', output)
        self.assertIn('__bundle_modules["main.luau"]', output)

    def test_rejects_missing_helper_marker(self) -> None:
        with self.assertRaisesRegex(
            package_bundle.PackagingError, "bundle_name.*exactly once"
        ):
            package_bundle.render_helper("", "Example", "main.luau", {}, "key")


if __name__ == "__main__":
    unittest.main()
