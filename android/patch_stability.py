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
    patch(controller, '.method public L()V', '    .locals 1\n', f'''    .locals 1
    invoke-static {{}}, {STATE}->isOffline()Z
    move-result v0
    if-eqz v0, :sp_native_restart
    invoke-virtual {{p0}}, Lcom/ookla/mobile4/app/ic;->M()V
    return-void
    :sp_native_restart
''')
    patch(controller, '.method public K()V', '    .locals 2\n',
          f'    .locals 2\n    invoke-static {{}}, {ANIM}->cancelOffline()V\n')
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
    animator = tree / (base + 'SpeedPlusLiveAnimator.smali')
    if '.method public static isOfflineUploadAnimating()Z' not in files[animator]:
        files[animator] += f'''
.method public static isOfflineUploadAnimating()Z
    .locals 1
    sget-boolean v0, {ANIM}->offlineActive:Z
    if-eqz v0, :done
    sget-boolean v0, {ANIM}->uploadActive:Z
    :done
    return v0
.end method
'''
    needle = 'smali_classes5/com/ookla/mobile4/views/gauge/g.smali'
    before = '    iget v0, p0, Lcom/ookla/mobile4/views/gauge/g;->r:I'
    patch(needle, '.method public e(Landroid/graphics/Canvas;Landroid/graphics/RectF;)V', before,
          before + f'''
    invoke-static {{}}, {ANIM}->isOfflineUploadAnimating()Z
    move-result v1
    if-eqz v1, :sp_native_needle_alpha
    const/16 v0, 0xff
    :sp_native_needle_alpha
''')
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
    return deferred_patches(tree, files)

def deferred_patches(tree, files=None):
    files = {} if files is None else files
    base = 'smali_classes6/tech/oliverprojects/speedtestplus/telemetry/'
    animator = tree / (base + 'SpeedPlusLiveAnimator.smali')
    controller = tree / 'smali_classes4/com/ookla/mobile4/app/ic.smali'
    if controller.exists():
        source = files.get(controller, controller.read_text(encoding='utf-8'))
        source = replace_in_method(source, '.method public L()V',
            '    invoke-virtual {p0}, Lcom/ookla/mobile4/app/ic;->M()V', f'''    # Keep native RESTARTING_SUITE; GO's connecting transition is different.
    const/16 v0, 0x60
    invoke-virtual {{p0, v0}}, Lcom/ookla/mobile4/app/ic;->G(I)V
    iget-object v0, p0, Lcom/ookla/mobile4/app/ic;->d:Lcom/ookla/mobile4/app/ic$b;
    invoke-virtual {{v0}}, Lcom/ookla/mobile4/app/ic$b;->i()V
    invoke-static {{p0}}, {ANIM}->startOffline(Lcom/ookla/mobile4/app/ic;)V''')
        files[controller] = source
    # Resolve the current gauge only after the first reading creates its view.
    # Upload is scheduled by OfflineStart, never against a stale pre-GO view.
    source = files.get(animator, animator.read_text(encoding='utf-8'))
    signature = '.method public static declared-synchronized startOffline('
    start = source.index(signature)
    end = source.index('.end method', start)
    body = source[start:end]
    if '# sp_deferred_view' not in body:
        first = body.index(f'    sget-object v1, {ANIM}->coordinatorRef:')
        last = body.index('    :cond_2', first)
        body = body[:first] + f'''    # sp_deferred_view
    const/4 v1, 0x0
    new-instance v2, Ltech/oliverprojects/speedtestplus/telemetry/SpeedPlusLiveAnimator$OfflineStart;
    invoke-direct {{v2, p0, v1, v0}}, Ltech/oliverprojects/speedtestplus/telemetry/SpeedPlusLiveAnimator$OfflineStart;-><init>(Lcom/ookla/mobile4/app/ic;Ljava/lang/Object;I)V
    sget-object v3, {ANIM}->MAIN:Landroid/os/Handler;
    const-wide/16 v4, 0x384
    invoke-virtual {{v3, v2, v4, v5}}, Landroid/os/Handler;->postDelayed(Ljava/lang/Runnable;J)Z

''' + body[last:]
        source = source[:start] + body + source[end:]
    if '.method public static offlineCoordinator()Ljava/lang/Object;' not in source:
        source += f'''
.method public static offlineCoordinator()Ljava/lang/Object;
    .locals 1
    sget-object v0, {ANIM}->coordinatorRef:Ljava/lang/ref/WeakReference;
    if-eqz v0, :ready
    invoke-virtual {{v0}}, Ljava/lang/ref/WeakReference;->get()Ljava/lang/Object;
    move-result-object v0
    :ready
    return-object v0
.end method
'''
    files[animator] = source
    runner = tree / (base + 'SpeedPlusLiveAnimator$OfflineStart.smali')
    source = runner.read_text(encoding='utf-8')
    if '# sp_resolve_after_reading' not in source:
        start = source.index('    iget-object v2, p0,')
        end = source.index('    invoke-virtual {v1}, Lcom/ookla/mobile4/app/ic;->speedPlusPrepareOffline()V', start)
        source = source[:start] + '    check-cast v1, Lcom/ookla/mobile4/app/ic;\n\n' + source[end:]
        marker = '    invoke-virtual {v1, v3, v4, v5, v6}, Lcom/ookla/mobile4/app/ic;->speedPlusOfflineReading(IFJ)V'
        source = source.replace(marker, marker + f'''
    # sp_resolve_after_reading
    invoke-static {{}}, {ANIM}->offlineCoordinator()Ljava/lang/Object;
    move-result-object v2
    if-eqz v2, :cancel
    check-cast v2, Lcom/ookla/mobile4/views/coordinators/a;
''', 1)
        marker = '    invoke-virtual {v2}, Lcom/ookla/mobile4/views/coordinators/a;->x()V'
        source = source.replace(marker, marker + f'''
    new-instance v3, Ltech/oliverprojects/speedtestplus/telemetry/SpeedPlusLiveAnimator$OfflineUpload;
    invoke-direct {{v3, v1, v2, v0}}, Ltech/oliverprojects/speedtestplus/telemetry/SpeedPlusLiveAnimator$OfflineUpload;-><init>(Lcom/ookla/mobile4/app/ic;Ljava/lang/Object;I)V
    invoke-static {{}}, {ANIM}->access$100()Landroid/os/Handler;
    move-result-object v4
    const-wide/16 v5, 0x1388
    invoke-virtual {{v4, v3, v5, v6}}, Landroid/os/Handler;->postDelayed(Ljava/lang/Runnable;J)Z
''', 1)
    files[runner] = source
    return files

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('decoded_tree', type=Path)
    parser.add_argument('--deferred-only', action='store_true', help='Apply the view-readiness fix to an already patched candidate')
    args = parser.parse_args()
    planned = deferred_patches(args.decoded_tree) if args.deferred_only else patches(args.decoded_tree)
    for path, source in planned.items():
        path.write_text(source, encoding='utf-8')
    print(f'Patched {len(planned)} runtime files; rebuild, repack, align and sign next.')
