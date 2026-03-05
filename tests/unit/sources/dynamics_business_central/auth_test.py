"""
Auth verification test for Dynamics 365 Business Central connector.
Obtains an OAuth 2.0 access token via client credentials flow, then
makes a simple API call to verify connectivity.
"""
import sys
import json
import urllib.request
import urllib.parse
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
from tests.unit.sources.test_utils import load_config


def test_auth():
    config_path = Path(__file__).parent / "configs" / "dev_config.json"
    config = load_config(config_path)

    tenant_id = config["tenant_id"]
    client_id = config["client_id"]
    client_secret = config["client_secret"]
    environment = config["environment"]
    company_id = config["company_id"]

    token_url = f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token"
    token_data = urllib.parse.urlencode({
        "grant_type": "client_credentials",
        "client_id": client_id,
        "client_secret": client_secret,
        "scope": "https://api.businesscentral.dynamics.com/.default",
    }).encode()

    print("Step 1: Requesting access token...")
    req = urllib.request.Request(token_url, data=token_data, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            token_resp = json.loads(resp.read())
            access_token = token_resp["access_token"]
            print(f"   Token obtained (expires_in={token_resp.get('expires_in')}s)")
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"Token request failed: HTTP {e.code}")
        print(f"   {body}")
        return False

    base_url = (
        f"https://api.businesscentral.dynamics.com/v2.0/{tenant_id}/{environment}"
        f"/api/databricks/standardEndpoints/v1.0/companies({company_id})/countriesRegions?$top=1"
    )

    print("Step 2: Testing API call (countriesRegions?$top=1)...")
    api_req = urllib.request.Request(base_url, headers={
        "Authorization": f"Bearer {access_token}",
        "Accept": "application/json",
    })
    try:
        with urllib.request.urlopen(api_req, timeout=20) as resp:
            data = json.loads(resp.read())
            records = data.get("value", [])
            print(f"   Success! Got {len(records)} record(s).")
            if records:
                print(f"   Sample: {json.dumps(records[0], indent=2)[:300]}")
            return True
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"API call failed: HTTP {e.code}")
        print(f"   {body[:500]}")
        if e.code == 401:
            print("   Check: Does the Azure app have 'API.ReadWrite.All' or equivalent BC API permission?")
        elif e.code == 404:
            print("   Check: Is the environment name correct? Is the AL extension deployed? Is the company_id valid?")
        return False


if __name__ == "__main__":
    success = test_auth()
    sys.exit(0 if success else 1)
