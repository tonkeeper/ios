"""Rewrite OpenAPI 3.1 `anyOf: [<scalar>, null]` nullables as `type: [<scalar>, 'null']`.

swift-openapi-generator skips a property whose `anyOf` has a `null` branch, so FastAPI-style
optional fields vanish from the generated types. The type-list form becomes a Swift optional.
Works on the block-style YAML the schema is stored in; prints the rewritten spec to stdout.
"""

import re
import sys

NULLABLE = re.compile(
    r"(?m)^(?P<indent>[ \t]*)anyOf:\n"
    r"(?P=indent)- type: (?P<type>string|integer|number|boolean)\n"
    r"(?P=indent)- type: 'null'\n"
)


def transform(source):
    return NULLABLE.sub(
        lambda match: (
            f"{match['indent']}type:\n"
            f"{match['indent']}- {match['type']}\n"
            f"{match['indent']}- 'null'\n"
        ),
        source,
    )


if __name__ == "__main__":
    with open(sys.argv[1], encoding="utf-8") as spec:
        sys.stdout.write(transform(spec.read()))
