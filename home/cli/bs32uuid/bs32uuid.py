"""Replace UUIDs on stdin with their typeid base32 suffix.

The base32 suffix (26 chars) is centered within the width of the matched
UUID text so surrounding layout (tables, aligned columns) is preserved.
"""

import re
import sys

ALPHABET = "0123456789abcdefghjkmnpqrstvwxyz"

UUID_RE = re.compile(
    r"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}"
    r"-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b"
)


def encode(value):
    """Encode a 128 bit int as 26 crockford base32 characters.

    The leading character only carries the top 3 bits, matching the
    typeid suffix encoding.
    """
    return "".join(
        ALPHABET[(value >> shift) & 0x1F]
        for shift in range(125, -5, -5)
    )


def center(text, width):
    if len(text) >= width:
        return text
    pad = width - len(text)
    left = pad // 2
    return " " * left + text + " " * (pad - left)


def replace(match):
    text = match.group(0)
    value = int(text.replace("-", ""), 16)
    return center(encode(value), len(text))


def main():
    for line in sys.stdin:
        sys.stdout.write(UUID_RE.sub(replace, line))
        sys.stdout.flush()


if __name__ == "__main__":
    main()
