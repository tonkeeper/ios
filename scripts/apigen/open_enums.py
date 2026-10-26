"""Add fallback decoding to generated string enums; reject unsupported output shapes."""

from pathlib import Path
import re
import sys


def transform(source):
    declarations = list(re.finditer(
        r"(?m)^([ \t]*)(?:@frozen\s+)?public enum \w+\s*:\s*([^\{]+)\{\n", source
    ))
    for declaration in reversed(declarations):
        indent, conformances = declaration.groups()
        protocols = set(re.sub(r"\s", "", conformances).split(","))
        if not {"String", "Swift.String"}.intersection(protocols) or "CodingKey" in protocols:
            continue
        if "Codable" not in protocols:
            raise ValueError("Unsupported generated string enum conformances")
        end = re.search(r"(?m)^" + re.escape(indent) + r"\}", source[declaration.end():])
        if end is None:
            raise ValueError("Cannot find generated string enum body")
        at = declaration.end() + end.start()
        body = source[declaration.end():at]
        if re.search(r"\binit\s*\(\s*from\b", body):
            raise ValueError("Generator now emits enum decoding; review the fallback adapter")
        pad = indent + "    "
        fallback = "" if re.search(r"(?m)^\s*case unknown\b", body) else f"{pad}case unknown\n"
        decoding = (
            f"{pad}public init(from decoder: any Decoder) throws {{\n"
            f"{pad}    self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown\n"
            f"{pad}}}\n"
        )
        source = source[:at] + fallback + decoding + source[at:]
    string_enums = re.findall(r"(?m)^.*\benum\s+(?!CodingKeys\b)\w+\s*:\s*(?:Swift\.)?String\b", source)
    if len(string_enums) != sum(
        bool({"String", "Swift.String"}.intersection(re.sub(r"\s", "", m.group(2)).split(","))) and "CodingKey" not in m.group(2)
        for m in declarations
    ):
        raise ValueError("Unsupported generated string enum declaration")
    return source


if __name__ == "__main__":
    for path in Path(sys.argv[1]).rglob("*.swift"):
        path.write_text(transform(path.read_text()))
