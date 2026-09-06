"""Apply narrowly-scoped authored hooks to the established decoded Android tree.

Input must already contain the 1.8.13 offline-cache fixes. Does not distribute the
underlying application. Missing/changed hook sites fail closed before any write.
"""
from pathlib import Path
import argparse

STATE = 'Lcom/ookla/mobile4/views/SpeedPlusState;'
ANIM = 'Ltech/oliverprojects/speedtestplus/telemetry/SpeedPlusLiveAnimator;'

def replace_in_method(source, signature, before, after):
    start = source.index(signature)
    end = source.index('.end method', start)
    body = source[start:end]
    if after in body:
        return source
    if body.count(before) != 1:
        raise ValueError(f'Unrecognized hook: {signature}')
    return source[:start] + body.replace(before, after, 1) + source[end:]

def patches(tree):
    files = {}
    def patch(relative, signature, before, after):
        path = tree / relative
        source = files.get(path)
        if source is None:
            source = path.read_text(encoding='utf-8')
        files[path] = replace_in_method(source, signature, before, after)

    base = 'smali_classes6/tech/oliverprojects/speedtestplus/telemetry/'
    patch(base + 'SpeedPlusLiveAnimator$Pulse.smali', '.method public run()V',
          '    :cond_2\n    :goto_0',
          '    :cond_2\n    return-void\n\n    :goto_0')
    begin = f'    invoke-static {{p1}}, {STATE}->beginLiveSpeed(I)V'
    patch(base + 'SpeedPlusLiveAnimator.smali', '.method public static declared-synchronized begin(', begin,
          f'    const/4 v2, 0x3\n    sub-int/2addr v2, p1\n    invoke-static {{v2}}, {ANIM}->stop(I)V\n\n' + begin)
    controller = 'smali_classes4/com/ookla/mobile4/app/ic.smali'
    cancel = f'    invoke-static {{}}, {ANIM}->cancelOffline()V'
    patch(controller, '.method public q()V', cancel,
          f'    invoke-static {{}}, {STATE}->isOffline()Z\n    move-result v0\n'
          '    if-eqz v0, :sp_online_prepare\n    return-void\n\n    :sp_online_prepare\n' + cancel)
    patch(controller, '.method public v(Lcom/ookla/error/c;)V',
          '    :cond_2\n    const/16 p1, 0x80',
          f'    :cond_2\n    invoke-static {{}}, {STATE}->showConnectionHelp()V\n\n    const/16 p1, 0x80')
    state = 'smali_classes6/com/ookla/mobile4/views/SpeedPlusState.smali'
    patch(state, '.method public static hasValidatedNetwork()Z', '    const/16 v2, 0x10', '    const/16 v2, 0x11')
    patch(state, '.method public static hasValidatedNetwork()Z',
          '    move-result v0\n    :try_end_0',
          '    move-result v0\n    xor-int/lit8 v0, v0, 0x1\n    :try_end_0')
    path = tree / state
    if '.method public static showConnectionHelp()V' not in files[path]:
        helper = f'''.method public static showConnectionHelp()V
    .locals 1
    sget-object v0, {STATE}->currentActivityRef:Ljava/lang/ref/WeakReference;
    if-eqz v0, :help_done
    invoke-virtual {{v0}}, Ljava/lang/ref/WeakReference;->get()Ljava/lang/Object;
    move-result-object v0
    check-cast v0, Landroid/app/Activity;
    invoke-static {{v0}}, Ltech/oliverprojects/speedtestplus/SpeedPlusConnectionHelp;->show(Landroid/app/Activity;)V
    :help_done
    return-void
.end method

'''
        files[path] += '\n' + helper
    runtime = Path(__file__).resolve().parent / 'runtime'
    animator = tree / (base + 'SpeedPlusLiveAnimator.smali')
    source = files[animator]
    if '.method public static bootstrapOffline(' not in source:
        start = source.index('.method public static declared-synchronized startOffline(')
        end = source.index('.end method', start) + len('.end method')
        files[animator] = source[:start] + (runtime / 'offline-bootstrap-methods.txt').read_text() + source[end:]
    bootstrap = 'SpeedPlusLiveAnimator$Bootstrap.smali'
    files[tree / (base + bootstrap)] = (runtime / bootstrap).read_text()
    coordinator = tree / 'smali_classes5/com/ookla/mobile4/views/coordinators/a.smali'
    source = coordinator.read_text()
    start = source.index('.method public x()V')
    end = source.index('.end method', start)
    body = source[start:end]
    marker = '    if-eqz v2, :offline_normal'
    if marker in body:
        first = body.index(marker)
        last = body.index('    :offline_normal', first)
        body = body[:first] + body[last:]
    before = '    if-eqz v2, :speedplus_custom_animator_done'
    after = f'''    if-nez v2, :speedplus_start_animator
    invoke-static {{}}, {STATE}->isOffline()Z
    move-result v2
    if-eqz v2, :speedplus_custom_animator_done
    :speedplus_start_animator'''
    if ':speedplus_start_animator' not in body:
        if body.count(before) != 1:
            raise ValueError('Unrecognized coordinator animator hook')
        body = body.replace(before, after, 1)
    files[coordinator] = source[:start] + body + source[end:]
    controller_path = tree / controller
    if '.method public speedPlusOfflineFailed()V' not in files[controller_path]:
        files[controller_path] += '''
.method public speedPlusOfflineFailed()V
    .locals 2
    const/16 v0, 0x80
    invoke-virtual {p0, v0}, Lcom/ookla/mobile4/app/ic;->G(I)V
    iget-object v0, p0, Lcom/ookla/mobile4/app/ic;->d:Lcom/ookla/mobile4/app/ic$b;
    new-instance v1, Ljava/lang/Exception;
    invoke-direct {v1}, Ljava/lang/Exception;-><init>()V
    invoke-virtual {v0, v1}, Lcom/ookla/mobile4/app/ic$b;->l(Ljava/lang/Exception;)V
    return-void
.end method
'''
    return files

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('decoded_tree', type=Path)
    args = parser.parse_args()
    planned = patches(args.decoded_tree)
    for path, source in planned.items():
        path.write_text(source, encoding='utf-8')
    print(f'Patched {len(planned)} runtime files; rebuild, repack, align and sign next.')
