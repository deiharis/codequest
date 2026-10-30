#!/usr/bin/env python3
"""Checks every lesson file against what the renderers actually read.

Run from the project root:  python3 tools/validate_lessons.py

This exists because a missing field is invisible at runtime. The renderers use
Dictionary.get() with a default, so a lesson with no "verdict" draws an empty
label and the game carries on looking fine. That is the kind of defect that
ships. A wrong `answer` index is worse: the check beat silently marks the right
answer wrong, and teaches the opposite of the lesson.
"""
import json, glob, os, sys

REQUIRED = {
    "dialogue":  ["speaker", "text"],
    "concept":   ["title", "body"],
    "compare":   ["title", "left_label", "left_body", "right_label", "right_body"],
    "example":   ["title", "bad", "good", "verdict"],
    "steps":     ["title", "steps"],
    "check":     ["question", "options", "answer", "explanation"],
    "encounter": ["taunt", "text"],
}

def main() -> int:
    root = os.path.join(os.path.dirname(__file__), "..", "data", "lessons")
    files = sorted(glob.glob(os.path.join(root, "*.json")))
    if not files:
        print("no lesson files found under data/lessons/")
        return 1

    problems = 0
    for path in files:
        name = os.path.basename(path)
        try:
            doc = json.load(open(path, encoding="utf-8"))
        except json.JSONDecodeError as e:
            print(f"{name}: not valid JSON — {e}")
            problems += 1
            continue

        for key in ("world", "title", "phase", "beats"):
            if key not in doc:
                print(f"{name}: missing top-level '{key}'")
                problems += 1
        if doc.get("world") != name[:-5]:
            print(f"{name}: world id is '{doc.get('world')}', should match the filename")
            problems += 1

        for i, beat in enumerate(doc.get("beats", [])):
            t = beat.get("type")
            where = f"{name} beat {i + 1} ({t})"
            if t not in REQUIRED:
                print(f"{where}: unknown beat type — the renderer will fall back to 'concept'")
                problems += 1
                continue
            for field in REQUIRED[t]:
                if field not in beat or beat[field] in ("", [], None):
                    print(f"{where}: missing or empty '{field}'")
                    problems += 1
            if t == "check":
                opts = beat.get("options", [])
                if not isinstance(beat.get("answer"), int) or not 0 <= beat["answer"] < len(opts):
                    print(f"{where}: 'answer' is not a valid index into 'options'")
                    problems += 1
            if t == "steps" and not 3 <= len(beat.get("steps", [])) <= 6:
                print(f"{where}: {len(beat.get('steps', []))} steps — keep it between 3 and 6 to fit the card")
                problems += 1

        print(f"{name}: {len(doc.get('beats', []))} beats")

    print(f"\n{len(files)} lesson(s), {problems} problem(s)")
    return 1 if problems else 0

if __name__ == "__main__":
    sys.exit(main())
