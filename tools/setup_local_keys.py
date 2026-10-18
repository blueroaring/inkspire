"""Generate independent development keys, never official server credentials."""
import json, secrets
from pathlib import Path
p = Path(__file__).resolve().parents[1] / "data/tower_report_keys.json"
if p.exists():
    raise SystemExit("Existing keys preserved")
key_id = "local-" + secrets.token_hex(8)
p.write_text(json.dumps({"active": key_id, "keys": {key_id: {"encryption": secrets.token_hex(32), "authentication": secrets.token_hex(32)}}}), encoding="utf-8")
print("Independent local development keys created; reports are not accepted by the official site.")
