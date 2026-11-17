#!/usr/bin/env python3
"""App Store Connect API client for `build.sh release` (#98). Standard library plus `openssl`.

Credentials come from the environment (ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH), which build.sh
loads from ~/.appstoreconnect/maynardgolf.env when they aren't set. The .p8 key never lives in the
repo (scripts/README.md, "Release").

    asc.py check --bundle-id ID                 the key works and the app exists; prints its id
    asc.py latest-build --bundle-id ID          newest uploaded build number (empty if none)
    asc.py whats-new --bundle-id ID --version V --build N --notes-file F [--timeout S]
                                                waits for the uploaded build, then sets its What to Test
"""

import argparse
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.appstoreconnect.apple.com"
ENV_VARS = ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_PATH")
LOCALE = "en-US"


class ASCError(Exception):
    """A failure the release can't continue past, with a message for the person running it."""


def credentials(env):
    """The key id, issuer id and key path from `env`, or an ASCError naming what's missing."""
    missing = [name for name in ENV_VARS if not env.get(name)]
    if missing:
        raise ASCError("missing " + ", ".join(missing) + " (see scripts/README.md, Release)")
    path = os.path.expanduser(env["ASC_KEY_PATH"])
    if not os.path.isfile(path):
        raise ASCError(f"ASC_KEY_PATH doesn't exist: {path}")
    return env["ASC_KEY_ID"], env["ASC_ISSUER_ID"], path


def _b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(der):
    """An ECDSA signature from `openssl dgst` (DER: SEQUENCE of r and s) as the 64-byte r‖s a
    JWT's ES256 signature needs."""
    if len(der) < 8 or der[0] != 0x30:
        raise ASCError("unexpected signature format from openssl")
    index = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    parts = []
    for _ in range(2):
        if der[index] != 0x02:
            raise ASCError("unexpected signature format from openssl")
        length = der[index + 1]
        value = der[index + 2:index + 2 + length].lstrip(b"\0")
        if len(value) > 32:
            raise ASCError("unexpected signature length from openssl")
        parts.append(value.rjust(32, b"\0"))
        index += 2 + length
    return parts[0] + parts[1]


def openssl_sign(key_path, message):
    """Signs `message` with the .p8 key (ES256's SHA-256 ECDSA) and returns the DER signature."""
    result = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path], input=message,
                            capture_output=True)
    if result.returncode != 0:
        raise ASCError("openssl couldn't sign with the key: " + result.stderr.decode().strip())
    return result.stdout


def token(key_id, issuer_id, key_path, now, sign=openssl_sign):
    """A 10-minute App Store Connect JWT. `now` and `sign` are passed in so tests are fixed."""
    header = _b64(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    payload = _b64(json.dumps({"iss": issuer_id, "iat": int(now), "exp": int(now) + 600,
                               "aud": "appstoreconnect-v1"}).encode())
    signing_input = f"{header}.{payload}".encode()
    return f"{header}.{payload}.{_b64(der_to_raw(sign(key_path, signing_input)))}"


class Client:
    """The few App Store Connect calls a release makes. `opener` (urllib's `urlopen` by default),
    `make_token` and `sleep` are injected so tests run without the network or a clock."""

    def __init__(self, make_token, opener=urllib.request.urlopen, sleep=time.sleep):
        self.make_token = make_token
        self.opener = opener
        self.sleep = sleep

    def request(self, method, path, body=None):
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(API + path, data=data, method=method, headers={
            "Authorization": "Bearer " + self.make_token(), "Content-Type": "application/json"})
        try:
            with self.opener(req) as response:
                raw = response.read()
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors="replace")[:500]
            if error.code == 401:
                raise ASCError("App Store Connect rejected the API key (401). Check ASC_KEY_ID, "
                               "ASC_ISSUER_ID and that the key isn't revoked.") from None
            raise ASCError(f"App Store Connect {method} {path} failed ({error.code}): {detail}") from None
        except urllib.error.URLError as error:
            raise ASCError(f"can't reach App Store Connect: {error.reason}") from None
        return json.loads(raw) if raw else {}

    def app_id(self, bundle_id):
        """The App Store Connect id of the app with `bundle_id`."""
        query = urllib.parse.urlencode({"filter[bundleId]": bundle_id, "limit": 1})
        data = self.request("GET", "/v1/apps?" + query).get("data", [])
        if not data:
            raise ASCError(f"no app with bundle id {bundle_id} in App Store Connect")
        return data[0]["id"]

    def latest_build_number(self, app_id):
        """The highest build number uploaded for the app, across every version, or None."""
        query = urllib.parse.urlencode({"filter[app]": app_id, "sort": "-uploadedDate", "limit": 50,
                                        "fields[builds]": "version"})
        numbers = [int(b["attributes"]["version"]) for b in self.request("GET", "/v1/builds?" + query)
                   .get("data", []) if b["attributes"]["version"].isdigit()]
        return max(numbers) if numbers else None

    def find_build(self, app_id, version, number):
        """The id of build `number` of marketing `version`, or None until App Store Connect lists it."""
        query = urllib.parse.urlencode({"filter[app]": app_id, "filter[version]": str(number),
                                        "filter[preReleaseVersion.version]": version, "limit": 1})
        data = self.request("GET", "/v1/builds?" + query).get("data", [])
        return data[0]["id"] if data else None

    def wait_for_build(self, app_id, version, number, timeout, interval=30):
        """Polls until the uploaded build appears (it takes a few minutes after upload)."""
        deadline = time.monotonic() + timeout
        while True:
            build_id = self.find_build(app_id, version, number)
            if build_id or time.monotonic() >= deadline:
                return build_id
            self.sleep(interval)

    def set_whats_new(self, build_id, text):
        """Sets the build's What to Test (en-US), updating the localization if one exists."""
        existing = self.request("GET", f"/v1/builds/{build_id}/betaBuildLocalizations").get("data", [])
        match = next((item for item in existing if item["attributes"].get("locale") == LOCALE), None)
        if match:
            self.request("PATCH", f"/v1/betaBuildLocalizations/{match['id']}", {"data": {
                "type": "betaBuildLocalizations", "id": match["id"], "attributes": {"whatsNew": text}}})
        else:
            self.request("POST", "/v1/betaBuildLocalizations", {"data": {
                "type": "betaBuildLocalizations", "attributes": {"locale": LOCALE, "whatsNew": text},
                "relationships": {"build": {"data": {"type": "builds", "id": build_id}}}}})


def main(argv=None, env=os.environ):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("check", "latest-build", "whats-new"):
        command = sub.add_parser(name)
        command.add_argument("--bundle-id", required=True)
        if name == "whats-new":
            command.add_argument("--version", required=True, help="marketing version, e.g. 1.2")
            command.add_argument("--build", type=int, required=True)
            command.add_argument("--notes-file", required=True)
            command.add_argument("--timeout", type=int, default=1200, help="seconds to wait for the build")
    args = parser.parse_args(argv)

    try:
        key_id, issuer_id, key_path = credentials(env)
        client = Client(lambda: token(key_id, issuer_id, key_path, time.time()))
        app = client.app_id(args.bundle_id)
        if args.command == "check":
            print(app)
        elif args.command == "latest-build":
            latest = client.latest_build_number(app)
            print("" if latest is None else latest)
        else:
            with open(args.notes_file, encoding="utf-8") as handle:
                text = handle.read().strip()
            build_id = client.wait_for_build(app, args.version, args.build, args.timeout)
            if not build_id:
                raise ASCError(f"build {args.build} didn't appear in App Store Connect within "
                               f"{args.timeout} s; paste {args.notes_file} into What to Test by hand")
            client.set_whats_new(build_id, text)
            print(f"What to Test set on build {args.build}")
    except ASCError as error:
        print(f"asc.py: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
