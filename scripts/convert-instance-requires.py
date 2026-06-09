#!/usr/bin/env python3

from __future__ import annotations

import argparse
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path


LUA_SUFFIXES = {".lua", ".luau"}


class ConversionError(Exception):
    pass


@dataclass(frozen=True)
class ModuleInfo:
    source_path: Path
    relative_path: Path
    logical_path: tuple[str, ...]
    is_init: bool


@dataclass(frozen=True)
class Replacement:
    start: int
    end: int
    text: str


@dataclass(frozen=True)
class RewriteStats:
    rewrites: int = 0
    unresolved: int = 0


def is_lua_file(path: Path) -> bool:
    return path.suffix in LUA_SUFFIXES


def logical_path_string(parts: tuple[str, ...]) -> str:
    return "/".join(parts) if parts else "."


def path_without_suffix(relative_path: Path) -> tuple[str, ...]:
    parts = list(relative_path.parts)
    parts[-1] = Path(parts[-1]).stem
    return tuple(parts)


def module_logical_path(relative_path: Path) -> tuple[str, ...]:
    stem = relative_path.stem
    if stem == "init":
        return tuple(relative_path.parts[:-1])
    return path_without_suffix(relative_path)


def build_module_index(source_dir: Path) -> dict[tuple[str, ...], ModuleInfo]:
    modules: dict[tuple[str, ...], ModuleInfo] = {}
    ambiguities: list[str] = []

    for path in sorted(source_dir.rglob("*")):
        if not path.is_file() or not is_lua_file(path):
            continue

        relative_path = path.relative_to(source_dir)
        logical_path = module_logical_path(relative_path)
        module = ModuleInfo(
            source_path=path,
            relative_path=relative_path,
            logical_path=logical_path,
            is_init=path.stem == "init",
        )
        existing = modules.get(logical_path)
        if existing is not None:
            ambiguities.append(
                "ambiguous module path "
                f'"{logical_path_string(logical_path)}": '
                f"{existing.relative_path.as_posix()} and {relative_path.as_posix()}"
            )
            continue
        modules[logical_path] = module

    if ambiguities:
        joined = "\n".join(ambiguities)
        raise ConversionError(
            f"found {len(ambiguities)} ambiguity error(s):\n{joined}"
        )

    return modules


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
        raise ConversionError("unterminated long string or block comment")
    return end + len(closing)


def skip_quoted_string(source: str, index: int) -> int:
    quote = source[index]
    cursor = index + 1

    while cursor < len(source):
        character = source[cursor]
        if character == "\\":
            cursor += 2
            continue
        if character == quote:
            return cursor + 1
        cursor += 1

    raise ConversionError(f"unterminated {quote} string")


def skip_comment(source: str, index: int) -> int:
    bracket_start = index + 2
    level = long_bracket_level(source, bracket_start)
    if level is not None:
        return skip_long_bracket(source, bracket_start, level)

    newline = source.find("\n", index + 2)
    return len(source) if newline == -1 else newline + 1


def skip_trivia(source: str, index: int) -> int:
    cursor = index
    while cursor < len(source):
        if source[cursor].isspace():
            cursor += 1
            continue
        if source.startswith("--", cursor):
            cursor = skip_comment(source, cursor)
            continue
        break
    return cursor


def skip_spaces(source: str, index: int) -> int:
    cursor = index
    while cursor < len(source) and source[cursor].isspace():
        cursor += 1
    return cursor


def is_identifier_start(character: str) -> bool:
    return character == "_" or character.isalpha()


def is_identifier_part(character: str) -> bool:
    return character == "_" or character.isalnum()


def parse_identifier(source: str, index: int) -> tuple[str, int] | None:
    if index >= len(source) or not is_identifier_start(source[index]):
        return None

    cursor = index + 1
    while cursor < len(source) and is_identifier_part(source[cursor]):
        cursor += 1

    return source[index:cursor], cursor


def has_identifier_prefix(source: str, index: int) -> bool:
    if index <= 0:
        return False
    previous = source[index - 1]
    return is_identifier_part(previous) or previous in ".:"


def is_statement_terminated(source: str, index: int) -> bool:
    cursor = index
    while cursor < len(source):
        character = source[cursor]
        if character == "\n" or character == "\r":
            return True
        if character.isspace():
            cursor += 1
            continue
        if source.startswith("--", cursor):
            return True
        return character == ";"
    return True


def parse_path_expression(
    source: str,
    index: int,
    current_module: tuple[str, ...],
    aliases: dict[str, tuple[str, ...]],
) -> tuple[tuple[str, ...], int] | None:
    cursor = skip_trivia(source, index)
    identifier = parse_identifier(source, cursor)
    if identifier is None:
        return None

    name, cursor = identifier
    if name == "script":
        current = current_module
    elif name in aliases:
        current = aliases[name]
    else:
        return None

    while True:
        dot_index = skip_trivia(source, cursor)
        if dot_index >= len(source) or source[dot_index] != ".":
            return current, cursor

        child_index = skip_trivia(source, dot_index + 1)
        child = parse_identifier(source, child_index)
        if child is None:
            return None

        segment, cursor = child
        if segment == "Parent":
            if not current:
                return None
            current = current[:-1]
        else:
            current = current + (segment,)


def parse_string_literal(source: str, index: int) -> tuple[str, int] | None:
    if index >= len(source) or source[index] not in ("'", '"'):
        return None

    quote = source[index]
    cursor = index + 1
    value: list[str] = []

    while cursor < len(source):
        character = source[cursor]
        if character == quote:
            return "".join(value), cursor + 1
        if character == "\\":
            if cursor + 1 >= len(source):
                return None
            escaped = source[cursor + 1]
            escapes = {
                "\\": "\\",
                "'": "'",
                '"': '"',
                "n": "\n",
                "r": "\r",
                "t": "\t",
            }
            value.append(escapes.get(escaped, escaped))
            cursor += 2
            continue
        value.append(character)
        cursor += 1

    return None


def find_matching_paren(source: str, open_paren_index: int) -> int | None:
    depth = 1
    cursor = open_paren_index + 1

    while cursor < len(source):
        if source.startswith("--", cursor):
            cursor = skip_comment(source, cursor)
            continue

        character = source[cursor]
        if character in ("'", '"', "`"):
            cursor = skip_quoted_string(source, cursor)
            continue

        level = long_bracket_level(source, cursor)
        if level is not None:
            cursor = skip_long_bracket(source, cursor, level)
            continue

        if character == "(":
            depth += 1
        elif character == ")":
            depth -= 1
            if depth == 0:
                return cursor
        cursor += 1

    return None


def emit_relative_require(
    current_module: ModuleInfo,
    target_module: tuple[str, ...],
) -> str:
    if current_module.is_init:
        current_parts = current_module.logical_path
        folder_name = current_module.source_path.parent.name
        inside_current_folder = (
            not current_parts
            or target_module[: len(current_parts)] == current_parts
        )
        if inside_current_folder and folder_name:
            suffix = list(target_module[len(current_parts) :])
            path_parts = [folder_name, *suffix]
            return "/".join(path_parts)

    from_parts = (
        list(current_module.logical_path[:-1])
        if current_module.is_init
        else list(current_module.logical_path[:-1])
    )

    common_length = 0
    while (
        common_length < len(from_parts)
        and common_length < len(target_module)
        and from_parts[common_length] == target_module[common_length]
    ):
        common_length += 1

    relative_parts = [".."] * (len(from_parts) - common_length)
    relative_parts.extend(target_module[common_length:])

    relative_path = "/".join(relative_parts) if relative_parts else "."
    if not relative_path.startswith("."):
        relative_path = "./" + relative_path
    return relative_path


def apply_replacements(source: str, replacements: list[Replacement]) -> str:
    if not replacements:
        return source

    parts: list[str] = []
    cursor = 0
    for replacement in replacements:
        parts.append(source[cursor:replacement.start])
        parts.append(replacement.text)
        cursor = replacement.end
    parts.append(source[cursor:])
    return "".join(parts)


def try_parse_local_alias(
    source: str,
    local_end: int,
    current_module: tuple[str, ...],
    aliases: dict[str, tuple[str, ...]],
) -> tuple[str, tuple[str, ...]] | None:
    cursor = skip_trivia(source, local_end)
    name = parse_identifier(source, cursor)
    if name is None:
        return None

    alias_name, cursor = name
    if alias_name == "function":
        return None

    cursor = skip_trivia(source, cursor)
    if cursor >= len(source) or source[cursor] != "=":
        return None

    expression = parse_path_expression(source, cursor + 1, current_module, aliases)
    if expression is None:
        return None

    resolved_path, end = expression
    if not is_statement_terminated(source, end):
        return None

    return alias_name, resolved_path


def rewrite_source(
    source: str,
    module: ModuleInfo,
    modules: dict[tuple[str, ...], ModuleInfo],
) -> tuple[str, RewriteStats]:
    aliases: dict[str, tuple[str, ...]] = {}
    replacements: list[Replacement] = []
    rewrites = 0
    unresolved = 0
    cursor = 0

    while cursor < len(source):
        if source.startswith("--", cursor):
            cursor = skip_comment(source, cursor)
            continue

        character = source[cursor]
        if character in ("'", '"', "`"):
            cursor = skip_quoted_string(source, cursor)
            continue

        level = long_bracket_level(source, cursor)
        if level is not None:
            cursor = skip_long_bracket(source, cursor, level)
            continue

        identifier = parse_identifier(source, cursor)
        if identifier is None:
            cursor += 1
            continue

        name, end = identifier
        if has_identifier_prefix(source, cursor):
            cursor = end
            continue

        if name == "local":
            alias = try_parse_local_alias(source, end, module.logical_path, aliases)
            if alias is not None:
                alias_name, resolved_path = alias
                aliases[alias_name] = resolved_path
            cursor = end
            continue

        if name != "require":
            cursor = end
            continue

        open_paren = skip_trivia(source, end)
        if open_paren >= len(source) or source[open_paren] != "(":
            cursor = end
            continue

        close_paren = find_matching_paren(source, open_paren)
        if close_paren is None:
            cursor = end
            continue

        argument_index = skip_trivia(source, open_paren + 1)
        string_argument = parse_string_literal(source, argument_index)
        if string_argument is not None:
            _, string_end = string_argument
            if skip_trivia(source, string_end) == close_paren:
                cursor = close_paren + 1
                continue

        expression = parse_path_expression(
            source,
            argument_index,
            module.logical_path,
            aliases,
        )
        if expression is not None:
            resolved_path, expression_end = expression
            if skip_trivia(source, expression_end) == close_paren:
                target_module = modules.get(resolved_path)
                if target_module is not None:
                    require_path = emit_relative_require(module, target_module.logical_path)
                    replacements.append(
                        Replacement(
                            start=cursor,
                            end=close_paren + 1,
                            text=f'require("{require_path}")',
                        )
                    )
                    rewrites += 1
                else:
                    unresolved += 1
                cursor = close_paren + 1
                continue

        cursor = close_paren + 1

    rewritten = apply_replacements(source, replacements)
    return rewritten, RewriteStats(rewrites=rewrites, unresolved=unresolved)


def ensure_non_overlapping(source_dir: Path, output_dir: Path) -> None:
    source_resolved = source_dir.resolve()
    output_resolved = output_dir.resolve()

    if source_resolved == output_resolved:
        raise ConversionError("source_dir and output_dir must be different")

    if output_resolved in source_resolved.parents:
        raise ConversionError("source_dir must not be inside output_dir")

    if source_resolved in output_resolved.parents:
        raise ConversionError("output_dir must not be inside source_dir")


def convert_tree(source_dir: Path, output_dir: Path) -> tuple[int, int, int, int]:
    modules = build_module_index(source_dir)
    lua_files_scanned = 0
    files_changed = 0
    rewrites = 0
    unresolved = 0

    for path in sorted(source_dir.rglob("*")):
        if not path.is_file():
            continue

        relative_path = path.relative_to(source_dir)
        destination = output_dir / relative_path
        destination.parent.mkdir(parents=True, exist_ok=True)

        if not is_lua_file(path):
            shutil.copyfile(path, destination)
            continue

        lua_files_scanned += 1
        source_text = path.read_text(encoding="utf-8")
        logical_path = module_logical_path(relative_path)
        module = modules[logical_path]
        rewritten_text, stats = rewrite_source(source_text, module, modules)

        if rewritten_text != source_text:
            files_changed += 1
        rewrites += stats.rewrites
        unresolved += stats.unresolved
        destination.write_text(rewritten_text, encoding="utf-8")

    return lua_files_scanned, files_changed, rewrites, unresolved


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Mirror a source folder and rewrite static Roblox instance-based "
            'requires to string requires like "./Module".'
        )
    )
    parser.add_argument("source_dir", type=Path)
    parser.add_argument("output_dir", type=Path)
    return parser.parse_args(argv)


def validate_args(source_dir: Path, output_dir: Path) -> tuple[Path, Path]:
    source_dir = source_dir.resolve()
    output_dir = output_dir.resolve()

    if not source_dir.exists():
        raise ConversionError(f"source_dir does not exist: {source_dir}")
    if not source_dir.is_dir():
        raise ConversionError(f"source_dir is not a directory: {source_dir}")
    if output_dir.exists() and not output_dir.is_dir():
        raise ConversionError(f"output_dir is not a directory: {output_dir}")

    ensure_non_overlapping(source_dir, output_dir)
    return source_dir, output_dir


def main(argv: list[str] | None = None) -> int:
    try:
        args = parse_args(argv)
        source_dir, output_dir = validate_args(args.source_dir, args.output_dir)
        scanned, changed, rewrites, unresolved = convert_tree(source_dir, output_dir)
    except ConversionError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    print(f"Lua files scanned: {scanned}")
    print(f"Files changed: {changed}")
    print(f"Require calls rewritten: {rewrites}")
    print(f"Unresolved instance requires left unchanged: {unresolved}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
