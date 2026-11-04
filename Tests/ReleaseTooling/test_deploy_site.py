import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("deploy_site", Path(__file__).resolve().parents[2] / "Scripts/deploy_site.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class DeploymentCredentialTests(unittest.TestCase):
    def environment(self, text, inherited=None):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "credentials.env"
            path.write_text(text)
            return module.deployment_environment(path, inherited or {}, "configured-account")

    def test_unrelated_malformed_fields_and_shell_substitutions_are_ignored(self):
        result = self.environment("UNRELATED='unterminated\nOTHER=$missing\nCLOUDFLARE_ADMIN_API_TOKEN='test-admin'\n")
        self.assertEqual(result["CLOUDFLARE_API_TOKEN"], "test-admin")
        self.assertNotIn("UNRELATED", result)
        self.assertNotIn("OTHER", result)

    def test_environment_overrides_file_and_pinned_account_is_the_fallback(self):
        result = self.environment("CLOUDFLARE_API_TOKEN=file-token\n", {"CLOUDFLARE_API_TOKEN": "environment-token"})
        self.assertEqual(result["CLOUDFLARE_API_TOKEN"], "environment-token")
        self.assertEqual(result["CLOUDFLARE_ACCOUNT_ID"], "configured-account")

    def test_literal_values_are_not_executed_or_interpolated(self):
        result = self.environment("export CLOUDFLARE_API_TOKEN='$(touch /must-not-run)$missing' # comment\n")
        self.assertEqual(result["CLOUDFLARE_API_TOKEN"], "$(touch /must-not-run)$missing")

    def test_errors_do_not_expose_secret_text(self):
        with self.assertRaises(ValueError) as caught:
            self.environment("CLOUDFLARE_API_TOKEN='private-test-content\n")
        self.assertNotIn("private-test-content", str(caught.exception))


if __name__ == "__main__":
    unittest.main()
