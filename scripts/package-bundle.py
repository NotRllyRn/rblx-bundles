#!/usr/bin/env python3

from __future__ import annotations

import argparse
import secrets
import string
import sys
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
BUNDLES_DIR = REPO_ROOT / "bundles"
OUTPUT_DIR = REPO_ROOT / "packaged-bundles"
HELPER_PATH = REPO_ROOT / "scripts/main-helper.luau"
TEMPLATE_MARKERS = {
    "bundle_name": "--// ** DO NOT TOUCH ** IDENTIFIER: BUNDLE_NAME",
    "control_key": "--// ** DO NOT TOUCH ** IDENTIFIER: CONTROL_KEY",
    "modules": "--// ** DO NOT TOUCH ** IDENTIFIER: MODULES",
    "entry_module": "--// ** DO NOT TOUCH ** IDENTIFIER: ENTRY_MODULE",
}


class PackagingError(Exception):
    pass


@dataclass(frozen=True)
class RequireCall:
    start: int
    end: int
    requested_path: str


@dataclass
class Module:
    module_id: str
    path: Path
    source: str
    requires: list[tuple[RequireCall, str]]


def is_relative_require(requested_path: str) -> bool:
    return bool(requested_path) and not requested_path.startswith(("@", "/"))


def is_repo_root_require(requested_path: str) -> bool:
    return (
        requested_path.startswith("@")
        and len(requested_path) > 1
        and not requested_path.startswith("@/")
    )


def long_bracket_level(source: str, index: int) -> int | None:
    if index >= len(source) or source[index] != "[":
        return None

    cursor = index + 1
    while cursor < len(source) and source[cursor] == "=":
        cursor += 1

    if cursor < len(source) and source[cursor] == "[":
        return cursor - index - 1
    return None


def skip_long_bracket(source: str, index: int, level: int) -> int:
    closing = "]" + ("=" * level) + "]"
    end = source.find(closing, index + level + 2)
    if end == -1:
        raise PackagingError("unterminated long string or block comment")
    return end + len(closing)


def skip_quoted_string(source: str, index: int) -> int:
    quote = source[index]
    cursor = index + 1

    while cursor < len(source):
        if source[cursor] == "\\":
            cursor += 2
            continue
        if source[cursor] == quote:
            return cursor + 1
        cursor += 1

    raise PackagingError(f"unterminated {quote} string")


def skip_trivia(source: str, index: int) -> int:
    cursor = index
    while cursor < len(source):
        if source[cursor].isspace():
            cursor += 1
            continue

        if source.startswith("--", cursor):
            bracket_start = cursor + 2
            level = long_bracket_level(source, bracket_start)
            if level is not None:
                cursor = skip_long_bracket(source, bracket_start, level)
            else:
                newline = source.find("\n", cursor + 2)
                cursor = len(source) if newline == -1 else newline + 1
            continue

        break
    return cursor


def parse_path_string(source: str, index: int) -> tuple[str, int]:
    quote = source[index]
    cursor = index + 1
    value: list[str] = []

    while cursor < len(source):
        character = source[cursor]
        if character == quote:
            return "".join(value), cursor + 1
        if character == "\\":
            if cursor + 1 >= len(source):
                break
            escaped = source[cursor + 1]
            escapes = {
                "\\": "\\",
                "\"": "\"",
                "'": "'",
                "n": "\n",
                "r": "\r",
                "t": "\t",
            }
            value.append(escapes.get(escaped, escaped))
            cursor += 2
            continue
        value.append(character)
        cursor += 1

    raise PackagingError("unterminated path string in require call")


def find_require_calls(source: str, display_path: str) -> list[RequireCall]:
    calls: list[RequireCall] = []
    cursor = 0

    while cursor < len(source):
        if source.startswith("--", cursor):
            cursor = skip_trivia(source, cursor)
            continue

        character = source[cursor]
        if character in ("\"", "'", "`"):
            cursor = skip_quoted_string(source, cursor)
            continue

        level = long_bracket_level(source, cursor)
        if level is not None:
            cursor = skip_long_bracket(source, cursor, level)
            continue

        if source.startswith("require", cursor):
            previous = source[cursor - 1] if cursor > 0 else ""
            after_index = cursor + len("require")
            following = source[after_index] if after_index < len(source) else ""
            identifier_char = lambda value: value.isalnum() or value == "_"

            if (
                (previous and (identifier_char(previous) or previous in ".:"))
                or (following and identifier_char(following))
            ):
                cursor += 1
                continue

            open_paren = skip_trivia(source, after_index)
            if open_paren >= len(source) or source[open_paren] != "(":
                cursor = after_index
                continue

            argument = skip_trivia(source, open_paren + 1)
            if argument >= len(source) or source[argument] not in ("\"", "'"):
                cursor = argument
                continue

            requested_path, string_end = parse_path_string(source, argument)
            close_paren = skip_trivia(source, string_end)
            if close_paren >= len(source) or source[close_paren] != ")":
                line = source.count("\n", 0, cursor) + 1
                raise PackagingError(
                    f"{display_path}:{line}: require must contain only one path argument"
                )

            if not (
                is_relative_require(requested_path)
                or is_repo_root_require(requested_path)
            ):
                line = source.count("\n", 0, cursor) + 1
                raise PackagingError(
                    f"{display_path}:{line}: require path must be relative "
                    f"(plain, ./, or ../) or repo-root-style (@path/to/file)"
                )

            calls.append(RequireCall(cursor, close_paren + 1, requested_path))
            cursor = close_paren + 1
            continue

        cursor += 1

    return calls


def luau_string(value: str) -> str:
    return (
        "\""
        + value.replace("\\", "\\\\")
        .replace("\"", "\\\"")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        + "\""
    )


class BundleBuilder:
    def __init__(self, bundle_root: Path) -> None:
        self.bundle_root = bundle_root.resolve()
        self.modules: dict[str, Module] = {}
        self.module_paths: dict[str, Path] = {}
        self.visiting: list[str] = []

    def module_relative_path(self, path: Path) -> Path:
        path = path.resolve()
        try:
            return path.relative_to(self.bundle_root)
        except ValueError:
            return path.relative_to(REPO_ROOT)

    def module_id(self, path: Path) -> str:
        relative_path = self.module_relative_path(path)
        if relative_path.name == "init.luau" and relative_path.parent != Path("."):
            return relative_path.parent.as_posix()
        return relative_path.as_posix()

    def allowed_root_for(self, path: Path) -> Path:
        path = path.resolve()
        try:
            path.relative_to(self.bundle_root)
        except ValueError:
            return REPO_ROOT
        return self.bundle_root

    def resolve_relative_base(self, requiring_path: Path, requested_path: str) -> Path:
        if requiring_path.name == "init.luau":
            return requiring_path.parent.parent / requested_path
        return requiring_path.parent / requested_path

    def resolve_require(self, requiring_path: Path, requested_path: str) -> Path:
        if is_relative_require(requested_path):
            candidate = self.resolve_relative_base(requiring_path, requested_path)
            allowed_root = self.allowed_root_for(requiring_path)
            allowed_name = (
                "the bundle being packaged"
                if allowed_root == self.bundle_root
                else "the repository root"
            )
            containment_error = (
                f"{self.module_id(requiring_path)}: require path resolves outside "
                f"{allowed_name}: {requested_path}"
            )
        elif is_repo_root_require(requested_path):
            candidate = REPO_ROOT / requested_path[1:]
            allowed_root = REPO_ROOT
            containment_error = (
                f"{self.module_id(requiring_path)}: require path resolves outside "
                f"the repository root: {requested_path}"
            )
        else:
            raise PackagingError(
                f"{self.module_id(requiring_path)}: unsupported require path: "
                f"{requested_path}"
            )

        candidate = candidate.resolve()

        try:
            candidate.relative_to(allowed_root)
        except ValueError as error:
            raise PackagingError(containment_error) from error

        candidates = (
            [candidate]
            if candidate.suffix != ""
            else [candidate.with_suffix(".luau"), candidate / "init.luau"]
        )

        for resolved_candidate in candidates:
            if resolved_candidate.is_file():
                return resolved_candidate

        raise PackagingError(
            f"{self.module_id(requiring_path)}: required file does not exist: "
            f"{requested_path}"
        )

    def validate_module_path(self, module_id: str, path: Path) -> None:
        existing_path = self.module_paths.get(module_id)
        if existing_path is not None and existing_path != path:
            raise PackagingError(
                f"ambiguous bundled module id {module_id!r}: "
                f"{self.module_relative_path(existing_path).as_posix()} and "
                f"{self.module_relative_path(path).as_posix()}"
            )
        self.module_paths[module_id] = path

    def collect(self, path: Path) -> str:
        path = path.resolve()
        module_id = self.module_id(path)
        self.validate_module_path(module_id, path)

        if module_id in self.visiting:
            cycle_start = self.visiting.index(module_id)
            chain = self.visiting[cycle_start:] + [module_id]
            raise PackagingError(
                "circular dependency detected: " + " -> ".join(chain)
            )
        if module_id in self.modules:
            return module_id

        try:
            source = path.read_text(encoding="utf-8")
        except UnicodeDecodeError as error:
            raise PackagingError(f"{module_id}: source is not valid UTF-8") from error

        self.visiting.append(module_id)
        resolved_requires: list[tuple[RequireCall, str]] = []
        try:
            for call in find_require_calls(source, module_id):
                dependency_path = self.resolve_require(path, call.requested_path)
                dependency_id = self.collect(dependency_path)
                resolved_requires.append((call, dependency_id))
        finally:
            self.visiting.pop()

        self.modules[module_id] = Module(
            module_id=module_id,
            path=path,
            source=source,
            requires=resolved_requires,
        )
        return module_id


def rewrite_requires(module: Module) -> str:
    source = module.source
    pieces: list[str] = []
    cursor = 0

    for call, dependency_id in module.requires:
        pieces.append(source[cursor : call.start])
        pieces.append(f"__bundle_require({luau_string(dependency_id)})")
        cursor = call.end

    pieces.append(source[cursor:])
    return "".join(pieces)


def indent_source(source: str, spaces: int) -> str:
    prefix = " " * spaces
    return "\n".join(
        prefix + line if line else "" for line in source.rstrip().splitlines()
    )


def generate_loader(module: Module) -> str:
    body = indent_source(rewrite_requires(module), 8)
    return "\n".join(
        [
            f"__bundle_modules[{luau_string(module.module_id)}] = function()",
            "    bundle_checkpoint()",
            "    local __bundle_result = (function()",
            body,
            "    end)()",
            "    bundle_checkpoint()",
            "    return __bundle_result",
            "end",
        ]
    )


def render_helper(
    helper: str,
    bundle_name: str,
    entry_id: str,
    modules: dict[str, Module],
    control_key: str,
) -> str:
    replacements = {
        "bundle_name": luau_string(bundle_name),
        "control_key": luau_string(control_key),
        "modules": "\n\n".join(
            generate_loader(modules[module_id]) for module_id in sorted(modules)
        ),
        "entry_module": luau_string(entry_id),
    }

    for marker_name, marker in TEMPLATE_MARKERS.items():
        marker_count = helper.count(marker)
        if marker_count != 1:
            raise PackagingError(
                f"{HELPER_PATH.name} must contain marker {marker_name!r} exactly once"
            )
        helper = helper.replace(marker, replacements[marker_name])

    return helper


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Package a bundles/<name> directory into one Luau file."
    )
    parser.add_argument("bundle", help="folder name directly under bundles/")
    return parser.parse_args()


def package_bundle(bundle_name: str) -> Path:
    if not bundle_name or Path(bundle_name).name != bundle_name:
        raise PackagingError("bundle must be a folder name directly under bundles/")

    bundle_root = (BUNDLES_DIR / bundle_name).resolve()
    if bundle_root.parent != BUNDLES_DIR.resolve() or not bundle_root.is_dir():
        raise PackagingError(f"bundle folder does not exist: bundles/{bundle_name}")

    entry_path = bundle_root / "main.luau"
    if not entry_path.is_file():
        raise PackagingError(f"bundle entry file does not exist: {entry_path}")

    try:
        helper = HELPER_PATH.read_text(encoding="utf-8")
    except FileNotFoundError as error:
        raise PackagingError(f"helper template does not exist: {HELPER_PATH}") from error

    builder = BundleBuilder(bundle_root)
    entry_id = builder.collect(entry_path)
    random_id = "".join(secrets.choice(string.ascii_lowercase) for _ in range(8))
    control_key = f"{random_id}_script"
    output = render_helper(
        helper,
        bundle_name,
        entry_id,
        builder.modules,
        control_key,
    )

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_path = OUTPUT_DIR / f"{bundle_name}.luau"
    output_path.write_text(output.rstrip() + "\n", encoding="utf-8")
    return output_path


def main() -> int:
    args = parse_args()
    try:
        output_path = package_bundle(args.bundle)
    except PackagingError as error:
        print(f"package-bundle: error: {error}", file=sys.stderr)
        return 1

    print(f"Packaged {args.bundle!r} -> {output_path.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
