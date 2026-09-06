.class final Ltech/oliverprojects/speedtestplus/telemetry/SpeedPlusLiveAnimator$Bootstrap;
.super Ljava/lang/Object;
.implements Ljava/lang/Runnable;
.field private final controller:Ljava/lang/ref/WeakReference;
.field private final generation:I
.field private final attempt:I
.method constructor <init>(Lcom/ookla/mobile4/app/ic;II)V
    .locals 1
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    new-instance v0, Ljava/lang/ref/WeakReference;
    invoke-direct {v0, p1}, Ljava/lang/ref/WeakReference;-><init>(Ljava/lang/Object;)V
    iput-object v0, p0, Ltech/oliverprojects/speedtestplus/telemetry/SpeedPlusLiveAnimator$Bootstrap;->controller:Ljava/lang/ref/WeakReference;
    iput p2, p0, Ltech/oliverprojects/speedtestplus/telemetry/SpeedPlusLiveAnimator$Bootstrap;->generation:I
    iput p3, p0, Ltech/oliverprojects/speedtestplus/telemetry/SpeedPlusLiveAnimator$Bootstrap;->attempt:I
    return-void
.end method
.method public run()V
    .locals 3
    iget-object v0, p0, Ltech/oliverprojects/speedtestplus/telemetry/SpeedPlusLiveAnimator$Bootstrap;->controller:Ljava/lang/ref/WeakReference;
    invoke-virtual {v0}, Ljava/lang/ref/WeakReference;->get()Ljava/lang/Object;
    move-result-object v0
    check-cast v0, Lcom/ookla/mobile4/app/ic;
    iget v1, p0, Ltech/oliverprojects/speedtestplus/telemetry/SpeedPlusLiveAnimator$Bootstrap;->generation:I
    iget v2, p0, Ltech/oliverprojects/speedtestplus/telemetry/SpeedPlusLiveAnimator$Bootstrap;->attempt:I
    invoke-static {v0, v1, v2}, Ltech/oliverprojects/speedtestplus/telemetry/SpeedPlusLiveAnimator;->bootstrapOffline(Lcom/ookla/mobile4/app/ic;II)V
    return-void
.end method
