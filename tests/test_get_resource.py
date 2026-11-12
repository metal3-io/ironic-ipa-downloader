import hashlib
import http.server
import io
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import threading
import unittest


class ArchiveServer(http.server.BaseHTTPRequestHandler):
    archive = b""
    checksum = True
    etag = '"test-etag"'
    requests = []

    def log_message(self, *args):
        pass

    def do_GET(self):
        type(self).requests.append((self.path, self.headers.get("If-None-Match")))
        if self.path.endswith(".sha256"):
            if not self.checksum:
                self.send_error(404)
                return
            digest = hashlib.sha256(self.archive).hexdigest()
            body = f"{digest}  ipa-centos9-master.tar.gz\n".encode()
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if self.headers.get("If-None-Match") == self.etag:
            self.send_response(304)
            self.send_header("ETag", self.etag)
            self.end_headers()
            return
        self.send_response(200)
        self.send_header("ETag", self.etag)
        self.send_header("Content-Length", str(len(self.archive)))
        self.end_headers()
        self.wfile.write(self.archive)


class GetResourceTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        archive_buffer = io.BytesIO()
        with tarfile.open(fileobj=archive_buffer, mode="w:gz") as archive:
            for suffix in ("kernel", "initramfs"):
                content = f"test-{suffix}\n".encode()
                info = tarfile.TarInfo(f"ipa-centos9-master.{suffix}")
                info.size = len(content)
                archive.addfile(info, io.BytesIO(content))
        ArchiveServer.archive = archive_buffer.getvalue()
        ArchiveServer.requests = []
        ArchiveServer.checksum = True
        self.httpd = http.server.ThreadingHTTPServer(("127.0.0.1", 0), ArchiveServer)
        self.thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self.thread.start()
        self.shared = root / "shared"
        self.env = dict(os.environ,
                        SHARED_DIR=str(self.shared),
                        IPA_BASEURI=f"http://127.0.0.1:{self.httpd.server_address[1]}/dib",
                        CURL_SPEED_LIMIT="0", CURL_RETRY="0", CURL_CONNECT_TIMEOUT="2",
                        NO_PROXY="127.0.0.1,localhost", no_proxy="127.0.0.1,localhost")

    def tearDown(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        self.thread.join(timeout=5)
        self.temp.cleanup()

    def run_downloader(self, extra_env=None):
        env = dict(self.env)
        env.update(extra_env or {})
        return subprocess.run(["bash", str(Path(__file__).resolve().parents[1] / "get-resource.sh")],
                              env=env, capture_output=True, text=True, timeout=20)

    def test_restarts_reuse_verified_persistent_download(self):
        for _ in range(3):
            result = self.run_downloader()
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
            for suffix in ("kernel", "initramfs"):
                target = self.shared / "html/images" / f"ironic-python-agent.{suffix}"
                self.assertTrue(target.is_file())
                self.assertEqual(f"test-{suffix}\n", target.read_text())
        conditional = [request for request in ArchiveServer.requests if request[1]]
        self.assertEqual(2, len(conditional))

    def test_missing_checksum_fails_closed_unless_explicitly_allowed(self):
        ArchiveServer.checksum = False
        result = self.run_downloader()
        self.assertNotEqual(0, result.returncode)
        self.assertIn("refusing an unverified archive", result.stderr)
        result = self.run_downloader({"REQUIRE_SHA256": "false"})
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_invalid_checksum_policy_is_rejected(self):
        result = self.run_downloader({"REQUIRE_SHA256": "maybe"})
        self.assertEqual(2, result.returncode)
        self.assertIn("REQUIRE_SHA256 must be true or false", result.stderr)


if __name__ == "__main__":
    unittest.main()
