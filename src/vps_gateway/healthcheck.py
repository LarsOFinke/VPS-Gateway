import json
import os
import sys
from urllib.request import urlopen

port = int(os.getenv("GATEWAY_API_PORT", "9080"))
try:
    with urlopen(f"http://127.0.0.1:{port}/v1/health", timeout=2) as response:
        payload = json.load(response)
        if response.status != 200 or payload.get("status") != "ok":
            raise RuntimeError("unhealthy response")
except Exception as error:
    print(error, file=sys.stderr)
    raise SystemExit(1) from error
