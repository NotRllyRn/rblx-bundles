from __future__ import annotations

import importlib.util
import io
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("convert-instance-requires.py")
SPEC = importlib.util.spec_from_file_location("convert_instance_requires", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
convert_instance_requires = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = convert_instance_requires
SPEC.loader.exec_module(convert_instance_requires)


class RewriteTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def write(self, relative_path: str, source: str) -> Path:
        path = self.root / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(source, encoding="utf-8")
        return path

    def build_index(self) -> dict[tuple[str, ...], object]:
        return convert_instance_requires.build_module_index(self.root)

    def rewrite(self, relative_path: str) -> tuple[str, convert_instance_requires.RewriteStats]:
        modules = self.build_index()
        rel_path = Path(relative_path)
        module = modules[convert_instance_requires.module_logical_path(rel_path)]
        source = (self.root / rel_path).read_text(encoding="utf-8")
        return convert_instance_requires.rewrite_source(source, module, modules)

    def test_rewrites_direct_sibling_from_init_module(self) -> None:
        self.write("src/init.luau", 'local Types = require(script.Types)\nreturn Types\n')
        self.write("src/Types.luau", "return {}\n")

        rewritten, stats = self.rewrite("src/init.luau")

        self.assertEqual(rewritten, 'local Types = require("src/Types")\nreturn Types\n')
        self.assertEqual(stats.rewrites, 1)
        self.assertEqual(stats.unresolved, 0)

    def test_rewrites_alias_based_parent_chain_from_single_parent(self) -> None:
        self.write(
            "src/External.luau",
            "local Package = script.Parent\nlocal formatError = require(Package.Logging.formatError)\n",
        )
        self.write("src/Logging/formatError.luau", "return function() end\n")

        rewritten, stats = self.rewrite("src/External.luau")

        self.assertIn('require("./Logging/formatError")', rewritten)
        self.assertEqual(stats.rewrites, 1)

    def test_rewrites_alias_based_parent_chain_from_double_parent(self) -> None:
        self.write(
            "src/State/ForPairs.luau",
            "local Package = script.Parent.Parent\nlocal Types = require(Package.Types)\n",
        )
        self.write("src/Types.luau", "return {}\n")

        rewritten, stats = self.rewrite("src/State/ForPairs.luau")

        self.assertIn('require("../Types")', rewritten)
        self.assertEqual(stats.rewrites, 1)

    def test_rewrites_alias_based_parent_chain_from_triple_parent(self) -> None:
        self.write(
            "src/State/For/Disassembly.luau",
            "local Package = script.Parent.Parent.Parent\nlocal Types = require(Package.Types)\n",
        )
        self.write("src/Types.luau", "return {}\n")

        rewritten, stats = self.rewrite("src/State/For/Disassembly.luau")

        self.assertIn('require("../../Types")', rewritten)
        self.assertEqual(stats.rewrites, 1)

    def test_resolves_directory_index_target_without_init_suffix(self) -> None:
        self.write(
            "src/State/ForPairs.luau",
            "local Package = script.Parent.Parent\nlocal For = require(Package.State.For)\n",
        )
        self.write("src/State/For/init.luau", "return {}\n")

        rewritten, stats = self.rewrite("src/State/ForPairs.luau")

        self.assertIn('require("./For")', rewritten)
        self.assertNotIn("/init", rewritten)
        self.assertEqual(stats.rewrites, 1)

    def test_resolves_inside_init_module_using_directory_index(self) -> None:
        self.write(
            "src/State/For/init.luau",
            "local Package = script.Parent.Parent\nlocal ForTypes = require(Package.State.For.ForTypes)\n",
        )
        self.write("src/State/For/ForTypes.luau", "return {}\n")

        rewritten, stats = self.rewrite("src/State/For/init.luau")

        self.assertIn('require("For/ForTypes")', rewritten)
        self.assertEqual(stats.rewrites, 1)

    def test_init_module_requiring_sibling_of_own_folder_stays_relative_to_parent(self) -> None:
        self.write(
            "src/State/For/init.luau",
            "local Package = script.Parent.Parent\nlocal Computed = require(Package.State.Computed)\n",
        )
        self.write("src/State/Computed.luau", "return {}\n")

        rewritten, stats = self.rewrite("src/State/For/init.luau")

        self.assertIn('require("./Computed")', rewritten)
        self.assertEqual(stats.rewrites, 1)

    def test_leaves_missing_target_unchanged_and_counts_unresolved(self) -> None:
        original = 'local Types = require(script.Types)\nreturn Types\n'
        self.write("src/init.luau", original)

        rewritten, stats = self.rewrite("src/init.luau")

        self.assertEqual(rewritten, original)
        self.assertEqual(stats.rewrites, 0)
        self.assertEqual(stats.unresolved, 1)

    def test_leaves_non_module_directory_unchanged_and_counts_unresolved(self) -> None:
        original = 'local value = require(script.Utility)\nreturn value\n'
        self.write("src/init.luau", original)
        self.write("src/Utility/helper.txt", "hello\n")

        rewritten, stats = self.rewrite("src/init.luau")

        self.assertEqual(rewritten, original)
        self.assertEqual(stats.unresolved, 1)

    def test_leaves_dynamic_require_unchanged(self) -> None:
        original = 'return require(script.Parent:FindFirstChild("Types"))\n'
        self.write("src/External.luau", original)
        self.write("src/Types.luau", "return {}\n")

        rewritten, stats = self.rewrite("src/External.luau")

        self.assertEqual(rewritten, original)
        self.assertEqual(stats.rewrites, 0)
        self.assertEqual(stats.unresolved, 0)

    def test_preserves_existing_string_requires(self) -> None:
        original = 'local Types = require("./Types")\nreturn Types\n'
        self.write("src/init.luau", original)
        self.write("src/Types.luau", "return {}\n")

        rewritten, stats = self.rewrite("src/init.luau")

        self.assertEqual(rewritten, original)
        self.assertEqual(stats.rewrites, 0)
        self.assertEqual(stats.unresolved, 0)

    def test_supports_mixed_extensions(self) -> None:
        self.write(
            "src/External.lua",
            "local Package = script.Parent\nlocal Types = require(Package.Types)\n",
        )
        self.write("src/Types.luau", "return {}\n")

        rewritten, stats = self.rewrite("src/External.lua")

        self.assertIn('require("./Types")', rewritten)
        self.assertEqual(stats.rewrites, 1)

    def test_rewrite_preserves_line_count(self) -> None:
        original = "local Package = script.Parent\n\nlocal Types = require(Package.Types)\nreturn Types\n"
        self.write("src/External.luau", original)
        self.write("src/Types.luau", "return {}\n")

        rewritten, _ = self.rewrite("src/External.luau")

        self.assertEqual(rewritten.count("\n"), original.count("\n"))

    def test_rejects_ambiguous_module_paths(self) -> None:
        self.write("src/Foo.luau", "return {}\n")
        self.write("src/Foo/init.luau", "return {}\n")

        with self.assertRaisesRegex(
            convert_instance_requires.ConversionError,
            'ambiguous module path "src/Foo"',
        ):
            self.build_index()


class ConversionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def write(self, relative_path: str, source: str) -> None:
        path = self.root / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(source, encoding="utf-8")

    def test_convert_tree_mirrors_and_rewrites_files(self) -> None:
        source_dir = self.root / "source"
        output_dir = self.root / "out"
        self.write("source/init.luau", 'local Types = require(script.Types)\nreturn Types\n')
        self.write("source/Types.luau", "return {}\n")
        self.write("source/readme.txt", "notes\n")

        scanned, changed, rewrites, unresolved = convert_instance_requires.convert_tree(
            source_dir,
            output_dir,
        )

        self.assertEqual((scanned, changed, rewrites, unresolved), (2, 1, 1, 0))
        self.assertEqual(
            (output_dir / "init.luau").read_text(encoding="utf-8"),
            'local Types = require("source/Types")\nreturn Types\n',
        )
        self.assertEqual(
            (output_dir / "readme.txt").read_text(encoding="utf-8"),
            "notes\n",
        )

    def test_main_prints_summary(self) -> None:
        source_dir = self.root / "source"
        output_dir = self.root / "out"
        self.write("source/init.luau", 'local Types = require(script.Types)\nreturn Types\n')
        self.write("source/Types.luau", "return {}\n")

        stdout = io.StringIO()
        stderr = io.StringIO()
        with redirect_stdout(stdout), redirect_stderr(stderr):
            exit_code = convert_instance_requires.main([str(source_dir), str(output_dir)])

        self.assertEqual(exit_code, 0)
        self.assertEqual(stderr.getvalue(), "")
        self.assertIn("Lua files scanned: 2", stdout.getvalue())
        self.assertIn("Files changed: 1", stdout.getvalue())
        self.assertIn("Require calls rewritten: 1", stdout.getvalue())
        self.assertIn("Unresolved instance requires left unchanged: 0", stdout.getvalue())

    def test_main_rejects_overlapping_directories(self) -> None:
        source_dir = self.root / "source"
        self.write("source/init.luau", "return {}\n")

        stderr = io.StringIO()
        with redirect_stderr(stderr):
            exit_code = convert_instance_requires.main(
                [str(source_dir), str(source_dir / "out")]
            )

        self.assertEqual(exit_code, 1)
        self.assertIn("must not be inside source_dir", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
