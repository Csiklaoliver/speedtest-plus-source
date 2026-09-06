import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('patcher', Path(__file__).resolve().parents[1] / 'patch_stability.py')
patcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patcher)

class PatcherTests(unittest.TestCase):
    def test_bootstrap_attaches_view_before_resolving_coordinator(self):
        runtime = (Path(__file__).resolve().parents[1] / 'runtime/offline-bootstrap-methods.txt').read_text()
        self.assertLess(runtime.index('->speedPlusOfflineReading(IFJ)V'), runtime.index('    :lookup'))
        self.assertIn('const/16 v0, 0x14', runtime)
        self.assertIn('->speedPlusOfflineFailed()V', runtime)
        self.assertNotIn('->G(I)V', runtime)  # protected controller method

    def test_only_selected_method_changes_and_second_application_is_noop(self):
        original = '.method a()V\nold\n.end method\n.method b()V\nold\n.end method'
        result = patcher.replace_in_method(original, '.method a()V', 'old', 'new')
        self.assertIn('.method b()V\nold', result)
        self.assertEqual(result, patcher.replace_in_method(result, '.method a()V', 'old', 'new'))

    def test_missing_or_ambiguous_site_is_rejected(self):
        for body in ('unknown', 'old old'):
            with self.assertRaises(ValueError):
                patcher.replace_in_method('.method a()V\n' + body + '\n.end method', '.method a()V', 'old', 'new')

if __name__ == '__main__':
    unittest.main()
