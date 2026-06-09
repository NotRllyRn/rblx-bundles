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

    def test_accepts_at_root_and_plain_relative_requires(self) -> None:
        source = """
local a = require("@helpers/shared/tool")
local b = require("module")
local c = require("somefolder/file")
"""
        calls = package_bundle.find_require_calls(source, "main.luau")

        self.assertEqual(
            [call.requested_path for call in calls],
            ["@helpers/shared/tool", "module", "somefolder/file"],
        )

    def test_rejects_dynamic_require(self) -> None:
        with self.assertRaisesRegex(
            package_bundle.PackagingError, "quoted path string"
        ):
            package_bundle.find_require_calls("require(module_name)", "main.luau")

    def test_rejects_absolute_require(self) -> None:
        with self.assertRaisesRegex(
            package_bundle.PackagingError, "must be relative"
        ):
            package_bundle.find_require_calls('require("/module")', "main.luau")

    def test_rejects_at_slash_require(self) -> None:
        with self.assertRaisesRegex(
            package_bundle.PackagingError, "must be relative"
        ):
            package_bundle.find_require_calls('require("@/module")', "main.luau")


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
            'local value = require("modules/value")\nreturn value\n',
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
            'local module = require("@bundles/Example/modules/value")\nreturn module\n',
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

    def test_collects_repo_root_style_dependency_outside_bundle(self) -> None:
        repo_root = self.bundle / "repo"
        bundle_root = repo_root / "bundles" / "Example"
        entry = bundle_root / "main.luau"
        entry.parent.mkdir(parents=True, exist_ok=True)
        entry.write_text('return require("@helpers/shared/tool")\n', encoding="utf-8")
        (repo_root / "helpers" / "shared").mkdir(parents=True, exist_ok=True)
        (repo_root / "helpers" / "shared" / "tool.luau").write_text(
            "return 0\n",
            encoding="utf-8",
        )
        self.set_repo_root(repo_root)

        builder = package_bundle.BundleBuilder(bundle_root)
        entry_id = builder.collect(entry)
        rewritten = package_bundle.rewrite_requires(builder.modules["main.luau"])

        self.assertEqual(entry_id, "main.luau")
        self.assertIn("helpers/shared/tool.luau", builder.modules)
        self.assertIn('__bundle_require("helpers/shared/tool.luau")', rewritten)

    def test_rejects_missing_repo_root_style_dependency(self) -> None:
        repo_root = self.bundle / "repo"
        bundle_root = repo_root / "bundles" / "Example"
        entry = bundle_root / "main.luau"
        entry.parent.mkdir(parents=True, exist_ok=True)
        entry.write_text(
            'return require("@bundles/Example/shared/missing")\n',
            encoding="utf-8",
        )
        self.set_repo_root(repo_root)

        with self.assertRaisesRegex(
            package_bundle.PackagingError, "does not exist"
        ):
            package_bundle.BundleBuilder(bundle_root).collect(entry)

    def test_rejects_repo_root_style_path_outside_repository(self) -> None:
        repo_root = self.bundle / "repo"
        bundle_root = repo_root / "bundles" / "Example"
        entry = bundle_root / "main.luau"
        entry.parent.mkdir(parents=True, exist_ok=True)
        entry.write_text('return require("@/outside")\n', encoding="utf-8")
        self.set_repo_root(repo_root)

        with self.assertRaisesRegex(
            package_bundle.PackagingError, "must be relative"
        ):
            package_bundle.find_require_calls(entry.read_text(encoding="utf-8"), "main.luau")

    def test_collects_plain_relative_path_without_dot_prefix(self) -> None:
        entry = self.write(
            "main.luau",
            'local value = require("modules/value")\nreturn value\n',
        )
        self.write("modules/value.luau", "return 0\n")

        builder = package_bundle.BundleBuilder(self.bundle)
        entry_id = builder.collect(entry)
        rewritten = package_bundle.rewrite_requires(builder.modules["main.luau"])

        self.assertEqual(entry_id, "main.luau")
        self.assertIn('__bundle_require("modules/value.luau")', rewritten)

    def test_collects_folder_entry_module_and_rewrites_to_folder_id(self) -> None:
        entry = self.write("main.luau", 'return require("./modules")\n')
        self.write(
            "modules/init.luau",
            'return require("modules/helper")\n',
        )
        self.write("modules/helper.luau", "return 0\n")

        builder = package_bundle.BundleBuilder(self.bundle)
        entry_id = builder.collect(entry)
        rewritten_entry = package_bundle.rewrite_requires(builder.modules["main.luau"])
        rewritten_folder = package_bundle.rewrite_requires(builder.modules["modules"])

        self.assertEqual(entry_id, "main.luau")
        self.assertEqual(
            set(builder.modules),
            {"main.luau", "modules", "modules/helper.luau"},
        )
        self.assertIn('__bundle_require("modules")', rewritten_entry)
        self.assertIn('__bundle_require("modules/helper.luau")', rewritten_folder)

    def test_collects_explicit_init_path_as_folder_module_id(self) -> None:
        entry = self.write("main.luau", 'return require("./modules/init.luau")\n')
        self.write("modules/init.luau", "return 0\n")

        builder = package_bundle.BundleBuilder(self.bundle)
        builder.collect(entry)
        rewritten = package_bundle.rewrite_requires(builder.modules["main.luau"])

        self.assertIn('__bundle_require("modules")', rewritten)
        self.assertIn("modules", builder.modules)
        self.assertNotIn("modules/init.luau", builder.modules)

    def test_collects_repo_root_folder_dependency_and_init_relative_requires(self) -> None:
        repo_root = self.bundle / "repo"
        bundle_root = repo_root / "bundles" / "Example"
        entry = bundle_root / "main.luau"
        entry.parent.mkdir(parents=True, exist_ok=True)
        entry.write_text('return require("@vendor/Fusion")\n', encoding="utf-8")
        (repo_root / "vendor" / "Fusion").mkdir(parents=True, exist_ok=True)
        (repo_root / "vendor" / "Fusion" / "init.luau").write_text(
            'local Types = require("Fusion/Types")\nreturn Types\n',
            encoding="utf-8",
        )
        (repo_root / "vendor" / "Fusion" / "Types.luau").write_text(
            "return {}\n",
            encoding="utf-8",
        )
        self.set_repo_root(repo_root)

        builder = package_bundle.BundleBuilder(bundle_root)
        entry_id = builder.collect(entry)
        rewritten_entry = package_bundle.rewrite_requires(builder.modules["main.luau"])
        rewritten_folder = package_bundle.rewrite_requires(builder.modules["vendor/Fusion"])

        self.assertEqual(entry_id, "main.luau")
        self.assertIn('__bundle_require("vendor/Fusion")', rewritten_entry)
        self.assertIn("vendor/Fusion", builder.modules)
        self.assertIn("vendor/Fusion/Types.luau", builder.modules)
        self.assertIn('__bundle_require("vendor/Fusion/Types.luau")', rewritten_folder)

    def test_collects_nested_folder_module_init_requires(self) -> None:
        repo_root = self.bundle / "repo"
        bundle_root = repo_root / "bundles" / "Example"
        entry = bundle_root / "main.luau"
        entry.parent.mkdir(parents=True, exist_ok=True)
        entry.write_text('return require("@vendor/Fusion/State/For")\n', encoding="utf-8")
        (repo_root / "vendor" / "Fusion" / "State" / "For").mkdir(
            parents=True, exist_ok=True
        )
        (repo_root / "vendor" / "Fusion" / "State" / "For" / "init.luau").write_text(
            'local ForTypes = require("For/ForTypes")\n'
            'local Types = require("../Types")\n'
            "return {ForTypes, Types}\n",
            encoding="utf-8",
        )
        (repo_root / "vendor" / "Fusion" / "State" / "For" / "ForTypes.luau").write_text(
            "return {}\n",
            encoding="utf-8",
        )
        (repo_root / "vendor" / "Fusion" / "Types.luau").write_text(
            "return {}\n",
            encoding="utf-8",
        )
        self.set_repo_root(repo_root)

        builder = package_bundle.BundleBuilder(bundle_root)
        builder.collect(entry)
        rewritten = package_bundle.rewrite_requires(
            builder.modules["vendor/Fusion/State/For"]
        )

        self.assertIn(
            '__bundle_require("vendor/Fusion/State/For/ForTypes.luau")',
            rewritten,
        )
        self.assertIn('__bundle_require("vendor/Fusion/Types.luau")', rewritten)

    def test_rejects_missing_folder_entry(self) -> None:
        entry = self.write("main.luau", 'return require("./modules")\n')
        (self.bundle / "modules").mkdir(parents=True, exist_ok=True)

        with self.assertRaisesRegex(
            package_bundle.PackagingError, "required file does not exist"
        ):
            package_bundle.BundleBuilder(self.bundle).collect(entry)


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
