"""Unit tests for scripts/asc.py (#98). No network: requests go to a fake opener."""

import base64
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
import urllib.error
from contextlib import redirect_stderr
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import asc  # noqa: E402


def der(r, s):
    """A DER ECDSA signature for integers r and s, as openssl writes it."""
    def integer(value):
        body = value.to_bytes((value.bit_length() + 8) // 8, "big")  # keeps a leading 0 when the top bit is set
        return b"\x02" + bytes([len(body)]) + body
    content = integer(r) + integer(s)
    return b"\x30" + bytes([len(content)]) + content


def decode(segment):
    return json.loads(base64.urlsafe_b64decode(segment + "=" * (-len(segment) % 4)))


class FakeResponse(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


class FakeOpener:
    """Answers each request with the next queued (status, body); records what was sent."""

    def __init__(self, *responses):
        self.responses = list(responses)
        self.requests = []

    def __call__(self, request):
        body = json.loads(request.data) if request.data else None
        self.requests.append((request.get_method(), request.full_url, body, request.headers))
        status, payload = self.responses.pop(0)
        raw = json.dumps(payload).encode() if payload is not None else b""
        if status >= 400:
            raise urllib.error.HTTPError(request.full_url, status, "error", {}, io.BytesIO(raw))
        return FakeResponse(raw)


def client(*responses):
    opener = FakeOpener(*responses)
    sleeps = []
    return asc.Client(lambda: "TOKEN", opener=opener, sleep=sleeps.append), opener, sleeps


class CredentialsTests(unittest.TestCase):
    def test_missing_variables_are_named(self):
        with self.assertRaisesRegex(asc.ASCError, "ASC_ISSUER_ID, ASC_KEY_PATH"):
            asc.credentials({"ASC_KEY_ID": "K"})

    def test_a_key_path_that_does_not_exist(self):
        with self.assertRaisesRegex(asc.ASCError, "doesn't exist"):
            asc.credentials({"ASC_KEY_ID": "K", "ASC_ISSUER_ID": "I", "ASC_KEY_PATH": "/nope/key.p8"})

    def test_all_present(self):
        with tempfile.NamedTemporaryFile(suffix=".p8") as key:
            self.assertEqual(asc.credentials({"ASC_KEY_ID": "K", "ASC_ISSUER_ID": "I", "ASC_KEY_PATH": key.name}),
                             ("K", "I", key.name))


class SignatureTests(unittest.TestCase):
    def test_der_to_raw_pads_and_strips_to_32_bytes(self):
        r, s = 2 ** 255 + 7, 5  # r has its top bit set (DER adds a 0 byte); s is short
        raw = asc.der_to_raw(der(r, s))
        self.assertEqual(len(raw), 64)
        self.assertEqual(int.from_bytes(raw[:32], "big"), r)
        self.assertEqual(int.from_bytes(raw[32:], "big"), s)

    def test_bad_signatures_are_rejected(self):
        for bad in (b"", b"\x31" + b"\0" * 10, b"\x30\x06\x03\x01\x01\x02\x01\x01",
                    b"\x30\x46\x02\x21" + b"\x01" * 33 + b"\x02\x21" + b"\x01" * 33):
            with self.assertRaises(asc.ASCError):
                asc.der_to_raw(bad)

    def test_token_claims_and_signature(self):
        signed = []

        def sign(path, message):
            signed.append((path, message))
            return der(1, 2)

        jwt = asc.token("KEY", "ISSUER", "/k.p8", 1000, sign=sign)
        header, payload, signature = jwt.split(".")
        self.assertEqual(decode(header), {"alg": "ES256", "kid": "KEY", "typ": "JWT"})
        self.assertEqual(decode(payload), {"iss": "ISSUER", "iat": 1000, "exp": 1600, "aud": "appstoreconnect-v1"})
        self.assertEqual(signed, [("/k.p8", f"{header}.{payload}".encode())])
        self.assertEqual(base64.urlsafe_b64decode(signature + "=="), (1).to_bytes(32, "big") + (2).to_bytes(32, "big"))

    def test_openssl_sign_with_a_real_key(self):
        with tempfile.TemporaryDirectory() as folder:
            key = os.path.join(folder, "key.p8")
            subprocess.run(["openssl", "genpkey", "-algorithm", "EC", "-pkeyopt", "ec_paramgen_curve:P-256",
                            "-out", key], check=True, capture_output=True)
            self.assertEqual(len(asc.der_to_raw(asc.openssl_sign(key, b"message"))), 64)
            with self.assertRaisesRegex(asc.ASCError, "openssl couldn't sign"):
                asc.openssl_sign(os.path.join(folder, "missing.p8"), b"message")


class ClientTests(unittest.TestCase):
    def test_requests_carry_the_token(self):
        api, opener, _ = client((200, {"data": [{"id": "APP"}]}))
        self.assertEqual(api.app_id("org.example"), "APP")
        method, url, body, headers = opener.requests[0]
        self.assertEqual((method, body), ("GET", None))
        self.assertIn("filter%5BbundleId%5D=org.example", url)
        self.assertEqual(headers["Authorization"], "Bearer TOKEN")

    def test_an_unknown_app(self):
        api, _, _ = client((200, {"data": []}))
        with self.assertRaisesRegex(asc.ASCError, "no app with bundle id"):
            api.app_id("org.example")

    def test_a_rejected_key(self):
        api, _, _ = client((401, {"errors": []}))
        with self.assertRaisesRegex(asc.ASCError, "rejected the API key"):
            api.app_id("org.example")

    def test_other_http_errors_include_the_detail(self):
        api, _, _ = client((409, {"errors": [{"detail": "conflict here"}]}))
        with self.assertRaisesRegex(asc.ASCError, "409.*conflict here"):
            api.app_id("org.example")

    def test_no_network(self):
        def offline(request):
            raise urllib.error.URLError("offline")
        api = asc.Client(lambda: "TOKEN", opener=offline)
        with self.assertRaisesRegex(asc.ASCError, "can't reach App Store Connect: offline"):
            api.app_id("org.example")

    def test_latest_build_is_the_highest_number(self):
        builds = {"data": [{"attributes": {"version": v}} for v in ("12", "10", "9", "1.0.3")]}
        api, opener, _ = client((200, builds), (200, {"data": []}))
        self.assertEqual(api.latest_build_number("APP"), 12)
        self.assertIsNone(api.latest_build_number("APP"))
        self.assertIn("filter%5Bapp%5D=APP", opener.requests[0][1])

    def test_waiting_for_a_build(self):
        api, opener, sleeps = client((200, {"data": []}), (200, {"data": [{"id": "B"}]}))
        self.assertEqual(api.wait_for_build("APP", "1.2", 186, timeout=600, interval=30), "B")
        self.assertEqual(sleeps, [30])
        self.assertIn("filter%5Bversion%5D=186", opener.requests[0][1])
        self.assertIn("filter%5BpreReleaseVersion.version%5D=1.2", opener.requests[0][1])

    def test_giving_up_on_a_build(self):
        api, _, sleeps = client((200, {"data": []}))
        self.assertIsNone(api.wait_for_build("APP", "1.2", 186, timeout=0))
        self.assertEqual(sleeps, [])

    def test_giving_up_after_the_timeout(self):
        now = [0.0]
        opener = FakeOpener(*[(200, {"data": []})] * 3)

        def sleep(seconds):
            now[0] += seconds

        api = asc.Client(lambda: "TOKEN", opener=opener, sleep=sleep, clock=lambda: now[0])
        self.assertIsNone(api.wait_for_build("APP", "1.2", 186, timeout=60, interval=30))
        self.assertEqual((len(opener.requests), now[0]), (3, 60.0))

    def test_whats_new_creates_a_localization(self):
        api, opener, _ = client((200, {"data": []}), (201, {"data": {}}))
        api.set_whats_new("B", "- New: x")
        method, url, body, _ = opener.requests[1]
        self.assertEqual((method, url), ("POST", asc.API + "/v1/betaBuildLocalizations"))
        self.assertEqual(body["data"]["attributes"], {"locale": "en-US", "whatsNew": "- New: x"})
        self.assertEqual(body["data"]["relationships"]["build"]["data"]["id"], "B")

    def test_whats_new_updates_an_existing_localization(self):
        existing = {"data": [{"id": "FR", "attributes": {"locale": "fr-FR"}},
                             {"id": "EN", "attributes": {"locale": "en-US"}}]}
        api, opener, _ = client((200, existing), (200, None))
        api.set_whats_new("B", "- Fixed: y")
        method, url, body, _ = opener.requests[1]
        self.assertEqual((method, url), ("PATCH", asc.API + "/v1/betaBuildLocalizations/EN"))
        self.assertEqual(body["data"]["attributes"], {"whatsNew": "- Fixed: y"})


class CommandLineTests(unittest.TestCase):
    def test_missing_credentials_fail_clearly(self):
        err = io.StringIO()
        with redirect_stderr(err):
            self.assertEqual(asc.main(["check", "--bundle-id", "org.example"], env={}), 1)
        self.assertIn("missing ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH", err.getvalue())

    def run_with(self, argv, *responses):
        opener = FakeOpener(*responses)
        real_client = asc.Client
        with tempfile.NamedTemporaryFile(suffix=".p8") as key, \
                mock.patch.object(asc, "Client", lambda make_token: real_client(make_token, opener=opener,
                                                                                 sleep=lambda _: None)), \
                mock.patch.object(asc, "token", lambda *args: "TOKEN"), \
                mock.patch("sys.stdout", new_callable=io.StringIO) as out, \
                redirect_stderr(io.StringIO()) as err:
            code = asc.main(argv, env={"ASC_KEY_ID": "K", "ASC_ISSUER_ID": "I", "ASC_KEY_PATH": key.name})
        return code, out.getvalue(), err.getvalue()

    def test_check_and_latest_build(self):
        app = (200, {"data": [{"id": "APP"}]})
        self.assertEqual(self.run_with(["check", "--bundle-id", "b"], app), (0, "APP\n", ""))
        self.assertEqual(self.run_with(["latest-build", "--bundle-id", "b"], app,
                                       (200, {"data": [{"attributes": {"version": "12"}}]})), (0, "12\n", ""))
        self.assertEqual(self.run_with(["latest-build", "--bundle-id", "b"], app, (200, {"data": []})), (0, "\n", ""))

    def test_whats_new(self):
        with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as notes:
            notes.write("- New: x\n")
        try:
            argv = ["whats-new", "--bundle-id", "b", "--version", "1.2", "--build", "186",
                    "--notes-file", notes.name, "--timeout", "0"]
            app = (200, {"data": [{"id": "APP"}]})
            code, out, _ = self.run_with(argv, app, (200, {"data": [{"id": "B"}]}), (200, {"data": []}),
                                         (201, {"data": {}}))
            self.assertEqual((code, out), (0, "What to Test set on build 186\n"))
            code, _, err = self.run_with(argv, app, (200, {"data": []}))
            self.assertEqual(code, 1)
            self.assertIn("didn't appear", err)
        finally:
            os.unlink(notes.name)


if __name__ == "__main__":
    unittest.main()
