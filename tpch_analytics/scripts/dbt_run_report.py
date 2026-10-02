"""Summarise a dbt run from target/run_results.json: failures and slowest nodes."""
import json
import sys
from pathlib import Path

path = Path(sys.argv[1] if len(sys.argv) > 1 else "target/run_results.json")
results = json.loads(path.read_text())["results"]

problems = [r for r in results if r["status"] not in ("success", "pass")]
slowest = sorted(results, key=lambda r: r["execution_time"], reverse=True)[:5]

print(f"{len(results)} nodes, {len(problems)} not successful")
for r in problems:
    print(f"  {r['status'].upper():6} {r['unique_id']}  {(r.get('message') or '')[:80]}")
print("Slowest nodes:")
for r in slowest:
    print(f"  {r['execution_time']:6.2f}s  {r['unique_id'].split('.')[2]}")

sys.exit(1 if any(r["status"] in ("error", "fail") for r in problems) else 0)
