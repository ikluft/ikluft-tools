#!/usr/bin/env python3
"""
generate railroad (syntax) diagram for Condorcet Election Format (CEF) parsing
by Ian Kluft
"""
import sys
import re
from pathlib import Path
from railroad import Diagram, DiagramItem, Start, End, Sequence, Choice, OneOrMore, Optional, Group


def outsvg(element: DiagramItem, name: str, is_complex: bool = False):
    """write to file"""
    diag_type = "complex" if is_complex else "simple"
    svg_path = Path("syndiag-cef-" + name + ".svg")
    diag = Diagram(Start(diag_type, name), element, End(diag_type))
    with svg_path.open(mode="w", encoding="utf-8") as svg_file:
        diag.writeSvg(svg_file.write)


def run():
    """generate railroad diagram"""
    word = Choice(0, "WORD", "INT")
    words = OneOrMore(word)
    outsvg(words, "words")

    quantifier = Sequence("*", "INT")
    outsvg(quantifier, "quantifier")

    weight = Sequence("^", "INT")
    outsvg(weight, "weight")

    multipliers = Optional(
        Group(
            Choice(
                0,
                Sequence("quantifier", "weight"),
                Sequence("weight", "quantifier"),
                "quantifier",
                "weight",
            ),
            "multipliers",
        ),
        skip=True
    )
    candidate = "words"
    outsvg(candidate, "candidate")

    tag = "words"
    outsvg(tag, "tag")

    equal_list = OneOrMore("candidate", "=")
    choice_list = Group(Choice(0, OneOrMore(equal_list, ">"), "/EMPTY_RANKING/"), "candidates")
    ranking = Sequence(choice_list, multipliers)
    tags = OneOrMore("tag", ",")
    line = Sequence(Optional(Group(Sequence(tags, "||"), "tags"), skip=True), ranking)
    outsvg(line, "line", is_complex=True)


if __name__ == "__main__":
    sys.argv[0] = re.sub(r"(-script\.pyw|\.exe)?$", "", sys.argv[0])
    sys.exit(run())
