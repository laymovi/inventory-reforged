"""Every function of the debug panel tells the plugin when it starts and when it ends

The debug build puts a call at the start of each function of the panel's parts and one at each way out of it, right
inside the function, so its this, its arguments and what it gives back stay the same. The plugin then knows every
panel function that runs and names it by its part, its line and what it's assigned to. If a stall has none of them
open, the stall is outside the panel's own code

    python -m interface.equipment.debug_calls < {"parts": [...], "titles": [...]}

reads the parts as JSON and writes them back with the calls in, for the node tests (tests/calls.cjs)
"""

import json
import re
import sys

ENTER = "EquipmentCalls.enter({});"
LEAVE = ";EquipmentCalls.leave({});"
RETURN_BARE = "return EquipmentCalls.leave({})"
RETURN_WITH = "return EquipmentCalls.leave({}, ("
RETURN_CLOSE = "))"
NAMES = "EquipmentCalls.name({}, {});\n"
ASSIGNED = re.compile(r"([\w$.]+)\s*[=:]\s*$")
GIVEN_TO = re.compile(r"([\w$.]+)\s*\(\s*$")
DECLARED = re.compile(r"function\s+([\w$]+)")
IDENTIFIER = re.compile(r"[\w$]")
LONGEST_NAME = 63
# Debug::Script::kMostEntries in the plugin
MOST_FUNCTIONS = 4096
# a line that ends in one of these goes on below, and so does one when the next line starts with one of the others
GOES_ON_AFTER = set("+-*/%=<>!&|^?:,.([{~")
GOES_ON_BEFORE = set("+-*/%=<>&|^?:,.([")


def past(text: str, at: int) -> int:
    """Past a string or a comment that starts here, or the same place for code"""
    if text.startswith("//", at):
        end = text.find("\n", at)
        return len(text) if end < 0 else end
    if text.startswith("/*", at):
        return text.index("*/", at + 2) + 2
    if text[at] in "\"'":
        quote = text[at]
        at += 1
        while text[at] != quote:
            at += 2 if text[at] == "\\" else 1
        return at + 1
    return at


def code(text: str, start: int, end: int):
    """The places of the text that are code, strings and comments left out"""
    at = start
    while at < end:
        after = past(text, at)
        if after == at:
            yield at
            after = at + 1
        at = after


def word_at(text: str, at: int, word: str) -> bool:
    end = at + len(word)
    before = text[at - 1] if at > 0 else " "
    after = text[end] if end < len(text) else " "
    return text.startswith(word, at) and not IDENTIFIER.match(before) and before != "." and not IDENTIFIER.match(after)


def closing(text: str, at: int) -> int:
    """The bracket that closes the one at a place"""
    pairs = {"(": ")", "[": "]", "{": "}"}
    waited = []
    for place in code(text, at, len(text)):
        char = text[place]
        if char in pairs:
            waited.append(pairs[char])
        elif waited and char == waited[-1]:
            waited.pop()
            if not waited:
                return place
    raise ValueError(f"nothing closes the {text[at]} at {at}")


def functions(text: str) -> list[tuple[int, int, int]]:
    """Where each function's word is, with its opening brace and its closing brace"""
    found = []
    for at in code(text, 0, len(text)):
        if not word_at(text, at, "function"):
            continue
        opening = closing(text, text.index("(", at)) + 1
        while text[opening].isspace():
            opening += 1
        if text[opening] != "{":
            raise ValueError(f"a function with no body at {at}")
        found.append((at, opening, closing(text, opening)))
    return found


def next_code(text: str, at: int) -> int | None:
    """The next place after this one that is code and not a space"""
    return next((place for place in code(text, at, len(text)) if not text[place].isspace()), None)


def statement_end(text: str, at: int) -> int:
    """Where the statement going on here ends, at its ; or right after its last code when a line or a block ends it.
    A newline ends it the way JavaScript reads it, unless the line plainly goes on"""
    depth = 0
    last = None
    place = at
    while place < len(text):
        after = past(text, place)
        if after != place:
            if text[place] in "\"'":
                last = after - 1
            place = after
            continue
        char = text[place]
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
            if depth < 0:
                return place if last is None else last + 1
        elif char == ";" and depth == 0:
            return place
        elif char == "\n" and depth == 0:
            ahead = next_code(text, place)
            if last is None:
                if ahead is not None and text[ahead] not in ";}":
                    raise ValueError(f"a return with its value on the next line at {at}, put it on one line")
            elif text[last] not in GOES_ON_AFTER and (ahead is None or text[ahead] not in GOES_ON_BEFORE):
                return last + 1
        if not char.isspace():
            last = place
        place += 1
    raise ValueError(f"a return that never ends at {at}")


def returns(text: str, opening: int, end: int, inner: list[tuple[int, int]]) -> list[tuple[int, int]]:
    """The returns that belong to this function itself, each with where its statement ends"""
    found = []
    for at in code(text, opening + 1, end):
        if word_at(text, at, "return") and not any(start <= at <= stop for start, stop in inner):
            found.append((at, statement_end(text, at + len("return"))))
    return found


def name(text: str, word: int, part: str) -> str:
    """The part, the line and what the function is assigned to or handed to"""
    before = text[text.rfind("\n", 0, word) + 1:word]
    declared = DECLARED.match(text, word)
    assigned = ASSIGNED.search(before)
    given = GIVEN_TO.search(before)
    if declared:
        what = declared[1]
    elif assigned:
        what = assigned[1]
    elif given:
        what = f"a function given to {given[1]}"
    else:
        what = "a function"
    return f"{part}:{text.count(chr(10), 0, word) + 1} {what}"[:LONGEST_NAME]


def instrumented(parts: list[str], titles: list[str]) -> tuple[list[str], int]:
    """The parts with the calls put in, each with the names of its functions on top, and how many functions there are"""
    result = []
    number = 0
    for text, title in zip(parts, titles):
        found = functions(text)
        first = number
        edits = []
        names = []
        for word, opening, end in found:
            names.append(name(text, word, title))
            inner = [(start, stop) for start, _, stop in found if opening < start < end]
            edits.append((opening + 1, 0, ENTER.format(number)))
            for start, stop in returns(text, opening, end, inner):
                if text[start + len("return"):stop].strip():
                    edits.append((start, len("return"), RETURN_WITH.format(number)))
                    edits.append((stop, 0, RETURN_CLOSE))
                else:
                    edits.append((start, stop - start, RETURN_BARE.format(number)))
            edits.append((end, 0, LEAVE.format(number)))
            number += 1
        # from the end back so every place still points where it did, at one place the edit made later goes first
        for _, (at, length, put) in sorted(enumerate(edits), key=lambda edit: (edit[1][0], edit[0]), reverse=True):
            text = text[:at] + put + text[at + length:]
        result.append((NAMES.format(first, json.dumps(names)) if names else "") + text)
    if number > MOST_FUNCTIONS:
        raise ValueError(f"the panel has {number} functions, the plugin keeps names for {MOST_FUNCTIONS}")
    return result, number


def main() -> None:
    asked = json.loads(sys.stdin.buffer.read().decode("utf-8"))
    parts, count = instrumented(asked["parts"], asked["titles"])
    sys.stdout.buffer.write(json.dumps({"parts": parts, "count": count}).encode("ascii"))


if __name__ == "__main__":
    main()
