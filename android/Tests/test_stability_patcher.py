import importlib.util
from pathlib import Path
import unittest
import tempfile

spec = importlib.util.spec_from_file_location('patcher', Path(__file__).resolve().parents[1] / 'patch_stability.py')
patcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patcher)

class PatcherTests(unittest.TestCase):
    def test_deferred_start_resolves_view_after_one_reading_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as folder:
            tree = Path(folder)
            base = tree / 'smali_classes6/tech/oliverprojects/speedtestplus/telemetry'
            base.mkdir(parents=True)
            animator = base / 'SpeedPlusLiveAnimator.smali'
            runner = base / 'SpeedPlusLiveAnimator$OfflineStart.smali'
            animator.write_text('.method public static declared-synchronized startOffline(X)V\n'
                f'    sget-object v1, {patcher.ANIM}->coordinatorRef:X\n'
                'old scheduling\n    :cond_2\n    return-void\n.end method\n')
            runner.write_text('    iget-object v2, p0, old\n'
                '    invoke-virtual {v1}, Lcom/ookla/mobile4/app/ic;->speedPlusPrepareOffline()V\n'
                '    invoke-virtual {v1, v3, v4, v5, v6}, Lcom/ookla/mobile4/app/ic;->speedPlusOfflineReading(IFJ)V\n'
                '    invoke-virtual {v2}, Lcom/ookla/mobile4/views/coordinators/a;->x()V\n')
            changed = patcher.deferred_patches(tree)
            body = changed[runner]
            self.assertEqual(body.count('->speedPlusOfflineReading(IFJ)V'), 1)
            self.assertLess(body.index('->speedPlusOfflineReading'), body.index('->offlineCoordinator'))
            self.assertLess(body.index('->x()V'), body.index('$OfflineUpload;'))
            self.assertNotIn('$OfflineUpload;', changed[animator])
            for path, text in changed.items():
                path.write_text(text)
            self.assertEqual(changed, patcher.deferred_patches(tree))

    def test_restart_uses_existing_offline_runner_not_another_start_sequence(self):
        source = Path(patcher.__file__).read_text()
        self.assertIn("'.method public L()V'", source)
        self.assertIn('->M()V', source)
        self.assertNotIn('bootstrapOffline', source)

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
