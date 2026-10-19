#!/usr/bin/env python3
"""PreToolUse gate: scan skills/plugins with NVIDIA SkillSpector before install.

Intercepts
  * Bash: `claude plugin install <plugin>[@marketplace]`, `npx skills add <src>`,
    and git clone / cp / mv / rsync / ln / unzip / tar / curl / wget commands
    that target a skills or plugins directory.
  * Write / Edit / MultiEdit on files inside a skills or plugins directory.

Policy (fail closed): the tool call is allowed only when SkillSpector returns
recommendation SAFE, the analysis is complete, and no active finding at or above
SKILLSPECTOR_GATE_BLOCK_SEVERITY (default LOW, i.e. any finding) exists.
Anything else, including a source that cannot be resolved or a scan error,
denies the call and explains why.

Environment
  SKILLSPECTOR_GATE_BLOCK_SEVERITY  LOW | MEDIUM | HIGH | CRITICAL  (default LOW)
  SKILLSPECTOR_GATE_LLM             1 = run the LLM stage (needs SKILLSPECTOR_PROVIDER
                                    and credentials); default is static analysis only
  SKILLSPECTOR_GATE_DISABLE         1 = gate off (explicit opt-out)
"""

import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SEVERITY_RANK = {"LOW": 1, "MEDIUM": 2, "HIGH": 3, "CRITICAL": 4}
SKILL_DIR_RE = re.compile(r"(^|/)(\.claude/(skills|plugins|commands)|\.agents/skills|skills)(/|$)")
FETCH_CMDS = {"git", "cp", "mv", "rsync", "ln", "unzip", "tar", "curl", "wget", "install"}
SCAN_TIMEOUT = 540


class GateError(Exception):
    """Install detected but the source could not be resolved or scanned."""


def skillspector_bin():
    for cand in (shutil.which("skillspector"), str(Path.home() / ".local/bin/skillspector")):
        if cand and os.access(cand, os.X_OK):
            return cand
    raise GateError(
        "SkillSpector ist nicht installiert. Ausfuehren: "
        "bash .claude/hooks/install-skillspector.sh"
    )


# --------------------------------------------------------------------------- scan

def run_scan(target, label):
    cmd = [skillspector_bin(), "scan", str(target), "--format", "json"]
    llm = os.environ.get("SKILLSPECTOR_GATE_LLM") == "1" and os.environ.get("SKILLSPECTOR_PROVIDER")
    if not llm:
        cmd.append("--no-llm")
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=SCAN_TIMEOUT)
    except subprocess.TimeoutExpired:
        raise GateError(f"SkillSpector-Scan von {label} hat das Zeitlimit ({SCAN_TIMEOUT}s) ueberschritten.")
    try:
        report = json.loads(proc.stdout)
    except json.JSONDecodeError:
        err = (proc.stderr or proc.stdout).strip().splitlines()[-5:]
        raise GateError(f"SkillSpector-Scan von {label} fehlgeschlagen (exit {proc.returncode}): " + " | ".join(err))
    report["_exit"] = proc.returncode
    report["_mode"] = "statisch + LLM" if llm else "nur statisch (--no-llm)"
    return report


def evaluate(report):
    """Return (allowed, reasons)."""
    threshold = SEVERITY_RANK.get(os.environ.get("SKILLSPECTOR_GATE_BLOCK_SEVERITY", "LOW").upper(), 1)
    ra = report.get("risk_assessment", {})
    comp = report.get("analysis_completeness", {})
    reasons = []
    if report["_exit"] == 2 or not report.get("execution_successful", False):
        reasons.append("Scan nicht erfolgreich ausgefuehrt")
    if ra.get("recommendation") != "SAFE":
        reasons.append(f"Empfehlung {ra.get('recommendation')}")
    if not comp.get("is_complete", False):
        exc = comp.get("ledger_exceptions") or []
        detail = "; ".join(f"{e.get('path')}: {e.get('reason_code')}" for e in exc[:5])
        reasons.append(f"Analyse unvollstaendig ({comp.get('coverage_percent')}% Abdeckung{', ' + detail if detail else ''})")
    blocking = [i for i in report.get("issues", []) if SEVERITY_RANK.get(i.get("severity"), 0) >= threshold]
    if blocking:
        reasons.append(f"{len(blocking)} Befund(e) mit Schweregrad >= {list(SEVERITY_RANK)[threshold - 1]}")
    return not reasons, reasons


def format_findings(report, limit=15):
    lines = []
    for i in report.get("issues", [])[:limit]:
        loc = i.get("location") or {}
        where = f"{loc.get('file', '?')}:{loc.get('start_line', '?')}"
        lines.append(
            f"  - [{i.get('severity')}] {i.get('id')} {i.get('category')} / {i.get('pattern')} @ {where}\n"
            f"      Fund: {str(i.get('finding', '')).strip()[:160]}\n"
            f"      Warum: {str(i.get('explanation', '')).strip()[:300]}"
        )
    extra = len(report.get("issues", [])) - limit
    if extra > 0:
        lines.append(f"  ... {extra} weitere Befunde")
    return "\n".join(lines)


def summary_line(report, label):
    ra = report.get("risk_assessment", {})
    return (f"SkillSpector [{label}]: Score {ra.get('score')}/100, Schweregrad {ra.get('severity')}, "
            f"Empfehlung {ra.get('recommendation')}, Modus {report['_mode']}")


# ------------------------------------------------------------- source resolution

def clone(url, ref=None, workdir=None):
    dest = Path(tempfile.mkdtemp(prefix="ssgate-", dir=workdir))
    cmd = ["git", "clone", "--depth", "1", "--quiet"]
    if ref:
        cmd += ["--branch", ref]
    cmd += [url, str(dest / "src")]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=180,
                          env={**os.environ, "GIT_TERMINAL_PROMPT": "0"})
    if proc.returncode != 0 and ref:
        # ref may be a commit sha: full clone + checkout
        shutil.rmtree(dest / "src", ignore_errors=True)
        proc = subprocess.run(["git", "clone", "--quiet", url, str(dest / "src")],
                              capture_output=True, text=True, timeout=300)
        if proc.returncode == 0:
            proc = subprocess.run(["git", "-C", str(dest / "src"), "checkout", "--quiet", ref],
                                  capture_output=True, text=True)
    if proc.returncode != 0:
        raise GateError(f"Quelle {url} konnte nicht geladen werden: {proc.stderr.strip()[:300]}")
    return dest / "src"


def github_url(repo):
    return repo if "://" in repo else f"https://github.com/{repo}.git"


def resolve_source_obj(source, market_root, plugin_root_prefix):
    """Materialize a marketplace plugin `source` entry to a local directory."""
    if isinstance(source, str):
        base = Path(market_root)
        if plugin_root_prefix and not source.startswith("./"):
            base = base / plugin_root_prefix
        path = (base / source).resolve()
        if not path.exists():
            raise GateError(f"Plugin-Pfad {path} existiert nicht.")
        return path
    kind = source.get("source")
    if kind in ("github", "url", "git", "git-subdir"):
        url = github_url(source["repo"]) if kind == "github" else source.get("url")
        if not url:
            raise GateError(f"Plugin-Quelle ohne URL: {source}")
        root = clone(url, source.get("ref") or source.get("sha"))
        sub = source.get("path")
        return (root / sub) if sub else root
    if kind == "npm":
        pkg = source["package"] + (f"@{source['version']}" if source.get("version") else "")
        dest = Path(tempfile.mkdtemp(prefix="ssgate-npm-"))
        proc = subprocess.run(["npm", "pack", pkg, "--ignore-scripts", "--pack-destination", str(dest)],
                              capture_output=True, text=True, timeout=180)
        tgz = list(dest.glob("*.tgz"))
        if proc.returncode != 0 or not tgz:
            raise GateError(f"npm-Paket {pkg} konnte nicht geladen werden: {proc.stderr.strip()[:300]}")
        subprocess.run(["tar", "-xzf", str(tgz[0]), "-C", str(dest)], check=True)
        return dest / "package"
    raise GateError(f"Plugin-Quelltyp '{kind}' wird vom Gate nicht unterstuetzt.")


def marketplaces():
    """Yield (name, root_dir) for every known marketplace."""
    base = Path.home() / ".claude/plugins"
    seen = set()
    known = base / "known_marketplaces.json"
    if known.exists():
        try:
            for name, info in json.loads(known.read_text()).items():
                loc = info.get("installLocation")
                if loc:
                    seen.add(name)
                    yield name, Path(loc)
        except (json.JSONDecodeError, AttributeError):
            pass
    mdir = base / "marketplaces"
    if mdir.is_dir():
        for d in mdir.iterdir():
            if d.name not in seen:
                yield d.name, d


def resolve_plugin(spec):
    name, _, market = spec.partition("@")
    candidates = []
    for mname, root in marketplaces():
        if market and mname != market:
            continue
        mf = root / ".claude-plugin/marketplace.json"
        if not mf.exists():
            continue
        try:
            data = json.loads(mf.read_text())
        except json.JSONDecodeError:
            continue
        prefix = (data.get("metadata") or {}).get("pluginRoot", "")
        for p in data.get("plugins", []):
            if p.get("name") == name:
                candidates.append((mname, root, prefix, p.get("source")))
    if not candidates:
        raise GateError(
            f"Plugin '{spec}' wurde in keinem bekannten Marketplace gefunden; Quelle nicht pruefbar. "
            "Erst den Marketplace hinzufuegen (claude plugin marketplace add ...)."
        )
    if len(candidates) > 1:
        raise GateError(f"Plugin '{name}' ist mehrdeutig ({', '.join(c[0] for c in candidates)}); plugin@marketplace angeben.")
    mname, root, prefix, source = candidates[0]
    return resolve_source_obj(source, root, prefix), f"{name}@{mname}"


def is_remote(s):
    return bool(re.match(r"^(https?://|git@|ssh://|git://)", s)) or bool(re.match(r"^[\w.-]+/[\w.-]+$", s))


def local_or_remote(src, cwd):
    """Return a scan target (path or URL) for a user-supplied source string."""
    src = os.path.expanduser(src)
    if re.match(r"^[\w.-]+/[\w.-]+$", src) and not Path(cwd, src).exists():
        return f"https://github.com/{src}"
    if is_remote(src):
        return src
    p = Path(cwd, src).resolve()
    if not p.exists():
        raise GateError(f"Quelle {p} existiert nicht.")
    return p


# ------------------------------------------------------------- bash detection

def split_segments(command):
    try:
        lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|\n<>")
        lexer.whitespace = " \t\r"
        lexer.whitespace_split = True
        tokens = list(lexer)
    except ValueError:
        return None
    segs, cur = [], []
    for t in tokens:
        if t and set(t) <= set(";&|\n"):
            if cur:
                segs.append(cur)
            cur = []
        else:
            cur.append(t)
    if cur:
        segs.append(cur)
    return segs


def strip_prefix(seg):
    while seg and (re.match(r"^\w+=", seg[0]) or seg[0] in ("sudo", "env", "command", "exec", "time")):
        seg = seg[1:]
    return seg


def positional(args):
    out, skip = [], False
    for a in args:
        if skip:
            skip = False
            continue
        if a in ("-b", "--branch", "-o", "-O", "--output", "-d", "-C", "--depth", "--scope", "-s", "-a", "--agent"):
            skip = True
            continue
        if a.startswith("-"):
            continue
        out.append(a)
    return out


def detect_bash(command, cwd):
    """Return list of (target, label) to scan; raise GateError if install is unscannable."""
    segs = split_segments(command)
    if segs is None:
        if re.search(r"plugins?\s+(install|i)\b|skills\s+add\b", command):
            raise GateError("Install-Befehl erkannt, aber nicht parsebar.")
        return []
    targets = []
    for seg in segs:
        seg = strip_prefix(seg)
        if not seg:
            continue
        base = os.path.basename(seg[0])
        joined = " ".join(seg)

        # shell redirection into a skills/plugins dir cannot be pre-scanned
        # (shlex emits unquoted redirect operators as their own tokens)
        for i, a in enumerate(seg):
            if a and set(a) <= set("<>&") and ">" in a and i + 1 < len(seg) and SKILL_DIR_RE.search(seg[i + 1]):
                raise GateError(f"Shell-Umleitung in Skill-/Plugin-Verzeichnis ({seg[i + 1]}) ist nicht pruefbar; Write-Tool verwenden.")
        seg = [a for j, a in enumerate(seg)
               if not (set(a) <= set("<>&")) and not (j > 0 and set(seg[j - 1]) <= set("<>&") and ">" in seg[j - 1] or j > 0 and seg[j - 1] in ("<", "<<", "<<<"))]
        if not seg:
            continue

        # claude plugin install <spec>
        if base == "claude" and len(seg) >= 3 and seg[1] in ("plugin", "plugins") and seg[2] in ("install", "i"):
            for spec in positional(seg[3:]):
                targets.append(resolve_plugin(spec))
            continue

        # npx skills add <src>  /  skills add <src>  /  npx add-skill <src>
        m = None
        if base in ("npx", "pnpx", "bunx") or (base in ("pnpm", "yarn") and len(seg) > 1 and seg[1] == "dlx"):
            rest = [a for a in seg[1:] if a not in ("dlx", "-y", "--yes")]
            if rest and re.match(r"^(skills|add-skill|@[\w-]+/skills)(@.*)?$", rest[0]):
                m = rest[1:]
                if m and m[0] in ("add", "install", "i"):
                    m = m[1:]
                elif rest[0].startswith("skills"):
                    m = None
        elif base == "skills" and len(seg) > 1 and seg[1] in ("add", "install"):
            m = seg[2:]
        if m is not None:
            srcs = positional(m)
            if not srcs:
                raise GateError(f"Skill-Install ohne erkennbare Quelle: {joined}")
            for s in srcs:
                targets.append((local_or_remote(s, cwd), s))
            continue

        # file-fetch commands writing into a skills/plugins dir
        if base in FETCH_CMDS and SKILL_DIR_RE.search(joined):
            if base == "git":
                if len(seg) > 1 and seg[1] == "clone":
                    pos = positional(seg[2:])
                    if not pos:
                        raise GateError(f"git clone ohne Quelle: {joined}")
                    targets.append((local_or_remote(pos[0], cwd), pos[0]))
                continue
            if base in ("cp", "mv", "rsync", "ln", "install"):
                pos = positional(seg[1:])
                for s in pos[:-1]:
                    if not SKILL_DIR_RE.search(s) or Path(cwd, os.path.expanduser(s)).exists():
                        targets.append((local_or_remote(s, cwd), s))
                continue
            if base in ("unzip", "tar"):
                archives = [a for a in positional(seg[1:]) if re.search(r"\.(zip|tar|tgz|tar\.gz|skill)$", a)]
                if not archives:
                    raise GateError(f"Archiv-Entpacken in Skill-Verzeichnis ohne pruefbares Archiv: {joined}")
                for a in archives:
                    if a.endswith(".zip") or a.endswith(".skill"):
                        targets.append((local_or_remote(a, cwd), a))
                    else:
                        d = Path(tempfile.mkdtemp(prefix="ssgate-tar-"))
                        subprocess.run(["tar", "-xf", str(Path(cwd, a)), "-C", str(d)], check=True)
                        targets.append((d, a))
                continue
            if base in ("curl", "wget"):
                urls = [a for a in seg[1:] if re.match(r"^https?://", a)]
                if not urls:
                    raise GateError(f"Download in Skill-Verzeichnis ohne URL: {joined}")
                for u in urls:
                    targets.append((u, u))
                continue
    return targets


# ------------------------------------------------------------- file-write detection

def skill_root_for(path):
    """Directory to scan for a file inside a skills/plugins tree."""
    p = Path(path)
    parts = p.parts
    for i in range(len(parts) - 1, -1, -1):
        if parts[i] in ("skills", "plugins", "commands") and i + 1 < len(parts) - 1:
            return Path(*parts[: i + 2])
    return p.parent


def detect_write(tool, inp):
    fp = inp.get("file_path") or ""
    if not SKILL_DIR_RE.search(fp):
        return []
    root = skill_root_for(fp)
    stage = Path(tempfile.mkdtemp(prefix="ssgate-write-")) / root.name
    if root.is_dir():
        shutil.copytree(root, stage, symlinks=True, ignore=shutil.ignore_patterns(".git"))
    else:
        stage.mkdir(parents=True)
    rel = Path(fp).relative_to(root) if Path(fp).is_relative_to(root) else Path(Path(fp).name)
    target = stage / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    if tool == "Write":
        target.write_text(inp.get("content", ""))
    else:
        text = target.read_text() if target.exists() else ""
        edits = inp.get("edits") if tool == "MultiEdit" else [inp]
        for e in edits:
            old, new = e.get("old_string", ""), e.get("new_string", "")
            text = text.replace(old, new) if e.get("replace_all") else text.replace(old, new, 1)
        target.write_text(text)
    return [(stage, f"{root} (nach {tool})")]


# ------------------------------------------------------------- main

def emit(decision, reason, message):
    out = {"systemMessage": message}
    if decision == "deny":
        out["hookSpecificOutput"] = {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    print(json.dumps(out))
    sys.exit(0)


def main():
    if os.environ.get("SKILLSPECTOR_GATE_DISABLE") == "1":
        sys.exit(0)
    data = json.load(sys.stdin)
    tool = data.get("tool_name", "")
    inp = data.get("tool_input") or {}
    cwd = data.get("cwd") or os.getcwd()

    try:
        if tool == "Bash":
            targets = detect_bash(inp.get("command", ""), cwd)
        elif tool in ("Write", "Edit", "MultiEdit"):
            targets = detect_write(tool, inp)
        else:
            targets = []
        if not targets:
            sys.exit(0)
        results = [(label, run_scan(t, label)) for t, label in targets]
    except GateError as e:
        msg = f"SkillSpector-Gate: Installation gestoppt. {e}"
        emit("deny", msg, msg)

    summaries, blocked = [], []
    for label, rep in results:
        ok, reasons = evaluate(rep)
        summaries.append(("FREIGEGEBEN  " if ok else "BLOCKIERT    ") + summary_line(rep, label))
        if not ok:
            blocked.append(
                f"{summary_line(rep, label)}\nGrund: {'; '.join(reasons)}\nBefunde:\n{format_findings(rep) or '  (keine Einzelbefunde)'}"
            )
    if blocked:
        reason = ("SkillSpector-Gate: Installation gestoppt. Dem Benutzer erklaeren, was gefunden wurde, "
                  "und NICHT auf anderem Weg installieren.\n\n" + "\n\n".join(blocked))
        emit("deny", reason, "\n".join(summaries))
    emit("allow", "", "\n".join(summaries))


if __name__ == "__main__":
    main()
