#!/usr/bin/env python3
"""
beads -> GitHub Issues / Projects / Wiki synchronisation.

Reads the beads database (Dolt, .beads/dolt/Surypus) and mirrors the task list
into GitHub Issues, adds them to the GitHub Project board, and regenerates the
wiki pages. Run it after changing issues in beads.

    python3 tools/beads-sync-github.py --dry-run
    python3 tools/beads-sync-github.py --push
"""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

REPO = "surypus/surypus"
PROJECT_ID = "PVT_kwDOE1S_r84BmjWl"
PROJECT_URL = "https://github.com/orgs/surypus/projects/2"
DOLTHUB_URL = "https://www.dolthub.com/repositories/dominicusin/Surypus-bd"

PRIORITY = {0: "P0", 1: "P1", 2: "P2", 3: "P3"}
TYPE = {"task": "task", "bug": "bug", "feature": "feature", "epic": "epic", "chore": "chore"}

# ProjectV2 "Status" field options -> beads status
PROJECT_STATUS = {"Todo": "open", "In Progress": "in_progress", "Done": "closed"}


def gh(*args: str, json_out: bool = False) -> Any:
    """Run a gh command, returning stdout (or parsed JSON)."""
    result = subprocess.run(
        ["gh", *args], capture_output=True, text=True
    )
    if result.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args)} failed: {result.stderr.strip()}")
    return json.loads(result.stdout) if json_out else result.stdout


def gh_graphql(query: str, variables: dict) -> Any:
    """Run a GraphQL mutation.

    gh's -F flag type-infers values, so a numeric option id such as 98236657 is
    sent as a JSON number and GitHub rejects it where a String is expected.
    Sending the whole payload as JSON avoids that coercion.
    """
    payload = json.dumps({"query": query, "variables": variables})
    result = subprocess.run(
        ["gh", "api", "graphql", "--input", "-"],
        input=payload, capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"graphql failed: {result.stderr.strip()[:200]}")
    data = json.loads(result.stdout)
    if "errors" in data:
        raise RuntimeError(f"graphql error: {json.dumps(data['errors'])[:200]}")
    return data


def export_issues() -> list[dict]:
    """Export every beads issue as a JSON object."""
    out = Path("/tmp/beads-sync.jsonl")
    subprocess.run(
        ["bd", "export", "--all", "-o", str(out)],
        capture_output=True, text=True, check=True,
    )
    return [json.loads(line) for line in out.read_text().splitlines() if line.strip()]


def issue_body(issue: dict) -> str:
    """Render a beads issue as a GitHub issue body."""
    priority = PRIORITY.get(issue.get("priority", 1), "P1")
    lines = [
        f"**beads ID:** `{issue['id']}`",
        f"**Priority:** {priority}",
        f"**Type:** {issue.get('issue_type', 'task')}",
        "",
        issue.get("description") or "_No description._",
        "",
        "---",
        "_Mirrored from beads. Edit the beads issue, then re-run "
        "`tools/beads-sync-github.py`._",
    ]
    return "\n".join(lines)


def labels_for(issue: dict) -> list[str]:
    labels = [PRIORITY[issue["priority"]]] if issue.get("priority") in PRIORITY else []
    if issue.get("issue_type") in TYPE:
        labels.append(TYPE[issue["issue_type"]])
    return labels


def sync_issues(issues: list[dict], dry_run: bool) -> tuple[int, int]:
    """Create GitHub issues that do not exist yet. Returns (created, skipped)."""
    created = skipped = 0
    for issue in issues:
        found = gh(
            "issue", "list", "--state", "all", "--search", f'"{issue["id"]}"',
            "--json", "number", "--jq", ".[0].number",
        ).strip()
        if found:
            skipped += 1
            continue
        if dry_run:
            print(f"  would create {issue['id']}: {issue['title'][:60]}")
            created += 1
            continue
        cmd = [
            "issue", "create", "--title", issue["title"][:80],
            "--body", issue_body(issue),
        ]
        labels = labels_for(issue)
        if labels:
            cmd += ["--label", ",".join(labels)]
        result = subprocess.run(["gh", *cmd], capture_output=True, text=True)
        if result.returncode != 0:
            print(f"  FAILED {issue['id']}: {result.stderr.strip()[:100]}")
            continue
        number = result.stdout.strip().rstrip("/").split("/")[-1]
        if issue["status"] == "closed":
            subprocess.run(
                ["gh", "issue", "close", number, "--reason", "completed"],
                capture_output=True, text=True,
            )
        created += 1
    return created, skipped


def project_item_ids(project_id: str) -> dict[str, str]:
    """Map issue node id -> project item id for everything already on the board."""
    query = """
    query($id:ID!) {
      node(id:$id) {
        ... on ProjectV2 {
          items(first:100) {
            nodes { id content { ... on Issue { id number } } }
          }
        }
      }
    }"""
    data = gh(
        "api", "graphql", "-f", f"query={query}", "-F", f"id={project_id}",
        json_out=True,
    )
    nodes = data["data"]["node"]["items"]["nodes"]
    return {
        n["content"]["id"]: n["id"]
        for n in nodes
        if n.get("content") and n["content"].get("id")
    }


def sync_project(issues: list[dict], dry_run: bool) -> tuple[int, int]:
    """Add every issue to the GitHub Project board. Returns (added, skipped)."""
    on_board = project_item_ids(PROJECT_ID)
    added = skipped = 0
    for issue in issues:
        result = gh(
            "issue", "list", "--state", "all", "--search", f'"{issue["id"]}"',
            "--json", "number", "--jq", ".[0].number",
        ).strip()
        if not result:
            continue
        node = gh(
            "api", "graphql", "-f",
            'query={ repository(owner:"surypus",name:"surypus")'
            f'{{ issue(number:{result}){{ id }} }} }}',
            json_out=True,
        )
        issue_id = node["data"]["repository"]["issue"]["id"]
        if issue_id in on_board:
            skipped += 1
            continue
        if dry_run:
            print(f"  would add to project: {issue['id']}")
            added += 1
            continue
        mutation = (
            'mutation($p:ID!,$c:ID!){ addProjectV2ItemById(input:{projectId:$p,'
            'contentId:$c}){ item { id } } }'
        )
        r = subprocess.run(
            ["gh", "api", "graphql", "-f", f"query={mutation}",
             "-F", f"p={PROJECT_ID}", "-F", f"c={issue_id}"],
            capture_output=True, text=True,
        )
        if '"item"' in r.stdout:
            added += 1
        else:
            print(f"  FAILED project add {issue['id']}: {r.stderr.strip()[:100]}")
    return added, skipped


def project_status_fields(project_id: str) -> tuple[str, dict[str, str]]:
    """Return the project's Status field id and its option-id map."""
    query = """
    query($id:ID!) {
      node(id:$id) {
        ... on ProjectV2 {
          fields(first:20) {
            nodes {
              ... on ProjectV2SingleSelectField {
                id name
                options { id name }
              }
            }
          }
        }
      }
    }"""
    data = gh("api", "graphql", "-f", f"query={query}", "-F", f"id={project_id}", json_out=True)
    for field in data["data"]["node"]["fields"]["nodes"]:
        if field.get("name") == "Status":
            return field["id"], {o["name"]: o["id"] for o in field["options"]}
    raise RuntimeError("project has no Status field")


def sync_status(issues: list[dict], project_id: str, dry_run: bool) -> tuple[int, int]:
    """Set the project Status field from each issue's beads status."""
    field_id, options = project_status_fields(project_id)
    wanted = {
        "open": "Todo",
        "in_progress": "In Progress",
        "closed": "Done",
    }

    query = """
    query($id:ID!) {
      node(id:$id) {
        ... on ProjectV2 {
          items(first:100) {
            nodes { id fieldValues(first:20) {
              nodes { __typename
                ... on ProjectV2ItemFieldSingleSelectValue { name } }
            } }
          }
        }
      }
    }"""
    data = gh("api", "graphql", "-f", f"query={query}", "-F", f"id={project_id}", json_out=True)
    items = data["data"]["node"]["items"]["nodes"]
    item_number = project_item_numbers(project_id)

    # issue number -> beads status, read from the mirrored issue bodies
    number_status = issue_status_by_number(issues)

    set_ = skipped = failed = 0
    for item in items:
        current = next(
            (
                fv["name"]
                for fv in item["fieldValues"]["nodes"]
                if fv["__typename"] == "ProjectV2ItemFieldSingleSelectValue"
            ),
            None,
        )
        number = item_number.get(item["id"])
        if number is None:
            skipped += 1
            continue
        status = number_status.get(number)
        if status is None:
            skipped += 1
            continue
        target = wanted[status]
        if current == target:
            skipped += 1
            continue
        if dry_run:
            print(f"  would set {number} -> {target}")
            set_ += 1
            continue
        mutation = (
            "mutation($p:ID!,$i:ID!,$f:ID!,$o:String!){"
            "updateProjectV2ItemFieldValue(input:{projectId:$p,itemId:$i,"
            "fieldId:$f,value:{singleSelectOptionId:$o}}){projectV2Item{id}}}"
        )
        try:
            gh_graphql(mutation, {
                "p": project_id, "i": item["id"],
                "f": field_id, "o": options[target],
            })
            set_ += 1
        except RuntimeError as exc:
            failed += 1
            print(f"  status failed for #{number}: {exc}")
    return set_, failed


def issue_status_by_number(issues: list[dict]) -> dict[int, str]:
    """Map GitHub issue number to the beads status of the issue it mirrors."""
    out: dict[int, str] = {}
    for issue in issues:
        number = gh(
            "issue", "list", "--state", "all", "--search", f'"{issue["id"]}"',
            "--json", "number", "--jq", ".[0].number",
        ).strip()
        if number:
            out[int(number)] = issue["status"]
    return out


def project_item_numbers(project_id: str) -> dict[str, int]:
    """Map project item id -> GitHub issue number."""
    query = """
    query($id:ID!) {
      node(id:$id) {
        ... on ProjectV2 {
          items(first:100) {
            nodes { id content { __typename ... on Issue { number } } }
          }
        }
      }
    }"""
    data = gh("api", "graphql", "-f", f"query={query}", "-F", f"id={project_id}", json_out=True)
    out = {}
    for item in data["data"]["node"]["items"]["nodes"]:
        content = item.get("content") or {}
        if content.get("__typename") == "Issue":
            out[item["id"]] = content["number"]
    return out


def write_wiki(issues: list[dict], out_dir: Path) -> list[Path]:
    """Render the wiki pages from the beads data."""
    out_dir.mkdir(parents=True, exist_ok=True)
    today = dt.date.today().isoformat()

    status = collections.Counter(i["status"] for i in issues)
    priority = collections.Counter(i["priority"] for i in issues)
    types = collections.Counter(i.get("issue_type", "task") for i in issues)

    home = f"""# Surypus Issue Tracker

Планы и статус задач проекта. Источник истины — база beads, зеркалится сюда
автоматически (`tools/beads-sync-github.py`).

## Источники данных

| Источник | Адрес |
|---|---|
| Beads (база задач) | `.beads/` в репозитории, remote — [DoltHub]({DOLTHUB_URL}) |
| GitHub Issues | https://github.com/{REPO}/issues |
| GitHub Project | {PROJECT_URL} |
| Репозиторий | https://github.com/{REPO} |

## Статус задач

| Статус | Кол-во |
|---|---|
| open | {status['open']} |
| in_progress | {status['in_progress']} |
| closed | {status['closed']} |
| **Всего** | **{len(issues)}** |

## Приоритеты

| Приоритет | Кол-во |
|---|---|
| P0 | {priority[0]} |
| P1 | {priority[1]} |
| P2 | {priority[2]} |
| P3 | {priority[3]} |

## Типы задач

{chr(10).join(f"- {k}: {v}" for k, v in sorted(types.items()))}

## Страницы

- [Plans](Plans.md) — активные задачи
- [Backlog](Backlog.md) — закрытые задачи

*Обновлено: {today}*
"""

    active = [i for i in issues if i["status"] != "closed"]
    plans = [f"# Plans\n\nАктивные задачи — {len(active)}. Обновлено: {today}.\n"]
    for state, title in (("in_progress", "In Progress"), ("open", "Open")):
        group = sorted(
            (i for i in active if i["status"] == state), key=lambda x: x["priority"]
        )
        plans.append(f"\n## {title}\n")
        for i in group:
            plans.append(f"\n### {i['id']} — {i['title']}\n")
            plans.append(i.get("description") or "_No description._")
            plans.append("")

    backlog = [f"# Backlog\n\nЗакрытые задачи — {status['closed']}. Обновлено: {today}.\n"]
    for i in sorted(issues, key=lambda x: x["priority"]):
        if i["status"] == "closed":
            backlog.append(f"- `{i['id']}` ({PRIORITY.get(i['priority'], 'P?')}) {i['title']}")

    files = {
        "Home.md": home,
        "Plans.md": "\n".join(plans),
        "Backlog.md": "\n".join(backlog),
    }
    written = []
    for name, content in files.items():
        path = out_dir / name
        path.write_text(content)
        written.append(path)
    return written


def push_wiki(out_dir: Path) -> None:
    """Publish the rendered wiki to the GitHub wiki repository."""
    wiki = Path("/tmp/surypus-wiki")
    if not (wiki / ".git").exists():
        subprocess.run(
            ["git", "clone", "--depth", "1", f"https://github.com/{REPO}.wiki.git", str(wiki)],
            capture_output=True, text=True, check=True,
        )
    else:
        subprocess.run(["git", "fetch", "--depth", "1", "origin"], cwd=wiki, check=True)
        subprocess.run(["git", "reset", "--hard", "origin/master"], cwd=wiki, check=True)
    for src in out_dir.glob("*.md"):
        (wiki / src.name).write_text(src.read_text())
    subprocess.run(["git", "add", "-A"], cwd=wiki, check=True)
    # Nothing to commit is a normal outcome when the wiki is already current.
    diff = subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=wiki)
    if diff.returncode == 0:
        print("wiki already up to date")
        return
    subprocess.run(
        ["git", "commit", "-m", "docs(wiki): refresh from beads"], cwd=wiki, check=True
    )
    subprocess.run(["git", "push", "origin", "master"], cwd=wiki, check=True)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true", help="report without changing anything")
    ap.add_argument("--push", action="store_true", help="publish the wiki")
    ap.add_argument("--wiki-dir", default="wiki")
    args = ap.parse_args()

    issues = export_issues()
    print(f"beads: {len(issues)} issues")

    print("\n== Issues ==")
    created, skipped = sync_issues(issues, args.dry_run)
    print(f"created {created}, already present {skipped}")

    print("\n== Project ==")
    added, skipped = sync_project(issues, args.dry_run)
    print(f"added {added}, already on board {skipped}")

    print("\n== Project status ==")
    set_, failed = sync_status(issues, PROJECT_ID, args.dry_run)
    print(f"status updated {set_}, failed {failed}")

    print("\n== Wiki ==")
    written = write_wiki(issues, Path(args.wiki_dir))
    print("wrote " + ", ".join(p.name for p in written))
    if args.push and not args.dry_run:
        push_wiki(Path(args.wiki_dir))
        print("published to GitHub wiki")
    return 0


if __name__ == "__main__":
    sys.exit(main())
