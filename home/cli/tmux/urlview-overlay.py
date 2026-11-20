import os
import re
import shutil
import subprocess
import sys
import termios
import tty

from wcwidth import wcwidth

URL_RE = re.compile(
    r"https?://(?:"
    r"[-a-zA-Z0-9@:%._+~#=]{1,256}\.[a-zA-Z0-9]{2,6}\b"
    r"[-a-zA-Z0-9()@:%_+.~#?&/=]*"
    r"|\[[0-9a-f:]+\](?::[0-9]+)?"
    r"|localhost(?::[0-9]+)?\b[-a-zA-Z0-9()@:%_+.~#?&/=]*"
    r")"
)
CSI_RE = re.compile(r"\x1b\[([0-?]*)[ -/]*([@-~])")
OSC_RE = re.compile(r"\x1b\](.*?)(?:\x1b\\|\x07)")

RESET = "\x1b[0m"
LINK_STYLE = "\x1b[4;95m"
SELECTED_STYLE = "\x1b[4;30;105m"
BAR_STYLE = "\x1b[48;5;18m\x1b[38;5;20m"
URL_STYLE = "\x1b[95m"

NEXT_KEYS = {"n", "j", "l", "\t", "\x0e", "\x1b[B", "\x1b[C", "\x1bOB"}
PREV_KEYS = {"N", "k", "h", "\x10", "\x1b[Z", "\x1b[A", "\x1b[D", "\x1bOA"}


class Cell:
    __slots__ = ("text", "sgr", "link")

    def __init__(self, text, sgr, link):
        self.text = text
        self.sgr = sgr
        self.link = link


def parse(lines):
    """Split `capture-pane -e` output into rows of styled cells."""
    rows = []
    sgr = ""
    link = None
    for line in lines:
        row = []
        i = 0
        while i < len(line):
            ch = line[i]
            if ch == "\x1b":
                m = CSI_RE.match(line, i)
                if m:
                    if m.group(2) == "m":
                        if m.group(1).split(";")[0] in ("", "0"):
                            sgr = ""
                        sgr += m.group(0)
                    i = m.end()
                    continue
                m = OSC_RE.match(line, i)
                if m:
                    parts = m.group(1).split(";", 2)
                    if parts[0] == "8" and len(parts) == 3:
                        link = parts[2] or None
                    i = m.end()
                    continue
                i += 2
                continue
            if wcwidth(ch) == 0 and row:
                row[-1].text += ch
            else:
                row.append(Cell(ch, sgr, link))
            i += 1
        rows.append(row)
    return rows


def text_width(row):
    """Width of the row ignoring trailing blanks (`capture-pane -N` pads)."""
    end = len(row)
    while end and row[end - 1].text == " ":
        end -= 1
    return sum(max(wcwidth(cell.text[0]), 1) for cell in row[:end])


def strip_trailing(url):
    while url and url[-1] in ".,;:!?)":
        if url[-1] == ")" and url.count(")") <= url.count("("):
            break
        url = url[:-1]
    return url


def find_links(rows, width):
    """Return `(url, [(row, col), ...])` for every link, in screen order."""
    links = []
    current = None
    for r, row in enumerate(rows):
        for c, cell in enumerate(row):
            if cell.link is None:
                current = None
                continue
            if current is None or current[0] != cell.link:
                current = (cell.link, [])
                links.append(current)
            current[1].append((r, c))

    # Bare urls may wrap onto the next row: join rows that fill the full
    # width, keeping a map from text offsets back to cells.
    text = []
    positions = []
    for r, row in enumerate(rows):
        for c, cell in enumerate(row):
            text.append(cell.text[0])
            positions.append((r, c))
        if text_width(row) < width:
            text.append("\n")
            positions.append(None)
    text = "".join(text)

    for m in URL_RE.finditer(text):
        url = strip_trailing(m.group(0))
        start = m.start()
        end = start + len(url)
        cells = [p for p in positions[start:end] if p is not None]
        if any(rows[r][c].link is not None for r, c in cells):
            continue
        links.append((url, cells))

    links.sort(key=lambda link: link[1][0])
    return links


def bar(index, links, width):
    url = links[index][0]
    left = f" [{index + 1}/{len(links)}] "
    hints = "  n/N: next/prev  enter: open  y: copy  q: quit "
    if len(left) + len(url) + len(hints) > width:
        hints = ""
    room = width - len(left) - len(hints)
    if len(url) > room:
        cut = max(room - 1, 0)
        url = url[:cut] + "…"
    pad = " " * max(width - len(left) - len(url) - len(hints), 0)
    return (
        BAR_STYLE
        + left
        + URL_STYLE
        + url
        + BAR_STYLE
        + pad
        + hints
        + "\x1b[K"
        + RESET
    )


def render(rows, links, selected, width, height):
    owner = {}
    for i, (_, cells) in enumerate(links):
        for pos in cells:
            owner[pos] = i

    selected_rows = {r for r, _ in links[selected][1]}
    bar_row = 0 if height - 1 in selected_rows else height - 1

    out = []
    for r in range(height):
        # clear first: a trailing erase after a full-width row could hit the
        # last column while the cursor is pending wrap
        out.append(f"\x1b[{r + 1};1H{RESET}\x1b[K")
        if r == bar_row:
            out.append(bar(selected, links, width))
            continue
        last = None
        for c, cell in enumerate(rows[r] if r < len(rows) else []):
            i = owner.get((r, c))
            if i is None:
                style = cell.sgr
            elif i == selected:
                style = cell.sgr + SELECTED_STYLE
            else:
                style = cell.sgr + LINK_STYLE
            if style != last:
                out.append(RESET + style)
                last = style
            out.append(cell.text)
        out.append(RESET)
    sys.stdout.write("".join(out))
    sys.stdout.flush()


def tmux(*args):
    subprocess.run(["tmux", *args], check=False)


def open_url(url):
    subprocess.run(["xdg-open", url], check=False)
    tmux("display-message", f"Opened {url}")


def copy_url(url):
    tmux("set-buffer", "--", url)
    if shutil.which("wl-copy"):
        subprocess.run(["wl-copy", "--", url], check=False)
    tmux("display-message", f"Copied {url}")


def interact(rows, links, width, height):
    selected = len(links) - 1
    fd = sys.stdin.fileno()
    while True:
        render(rows, links, selected, width, height)
        key = os.read(fd, 32).decode(errors="replace")
        if key in NEXT_KEYS:
            selected = (selected + 1) % len(links)
        elif key in PREV_KEYS:
            selected = (selected - 1) % len(links)
        elif key == "g":
            selected = 0
        elif key == "G":
            selected = len(links) - 1
        elif key in ("\r", "\n", "o"):
            open_url(links[selected][0])
            return
        elif key == "y":
            copy_url(links[selected][0])
            return
        elif key in ("q", "\x1b", "\x03"):
            return


def main():
    mode, path, width = sys.argv[1], sys.argv[2], int(sys.argv[3])
    with open(path, encoding="utf-8", errors="replace") as f:
        lines = f.read().split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    rows = parse(lines)
    links = find_links(rows, width)

    if mode == "check":
        sys.exit(0 if links else 1)

    os.unlink(path)
    if not links:
        return

    size = os.get_terminal_size()
    fd = sys.stdin.fileno()
    saved = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        sys.stdout.write("\x1b[?25l\x1b[2J")
        interact(rows, links, size.columns, size.lines)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, saved)
        sys.stdout.write(RESET + "\x1b[?25h")
        sys.stdout.flush()


main()
