"""Adapt a temporary Kandelabr schema; Hermes shares its sparse candle models."""

from copy import deepcopy
import json
from pathlib import Path
import re
import sys

import yaml


class SpecLoader(yaml.SafeLoader):
    pass


SpecLoader.yaml_implicit_resolvers = {}
for tag, pattern, first in (
    ("null", r"~|null|Null|NULL|", ["~", "n", "N", ""]),
    ("bool", r"true|True|TRUE|false|False|FALSE", "tTfF"),
    ("int", r"-?(?:0|[1-9][0-9]*)", "-0123456789"),
    ("float", r"-?(?:0|[1-9][0-9]*)(?:\.[0-9]*)?(?:[eE][-+]?[0-9]+)?", "-0123456789"),
    ("merge", r"<<", "<"),
):
    SpecLoader.add_implicit_resolver(f"tag:yaml.org,2002:{tag}", re.compile(f"^(?:{pattern})$"), list(first))


def load(text):
    return yaml.load(text, SpecLoader)


def prepare(document):
    document = deepcopy(document)
    candle = document["components"]["schemas"]["Candle"]
    optional = {"o", "h", "l", "c", "v"}
    if missing := optional - candle["properties"].keys():
        raise ValueError(f"Candle has no properties {', '.join(sorted(missing))}")
    candle["required"] = [key for key in candle.get("required", []) if key not in optional]
    return document


if __name__ == "__main__":
    Path(sys.argv[2]).write_text(json.dumps(prepare(load(Path(sys.argv[1]).read_text()))))
