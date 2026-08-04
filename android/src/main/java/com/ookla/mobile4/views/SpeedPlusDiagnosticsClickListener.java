package com.ookla.mobile4.views;

import android.content.Context;
import android.view.View;

/** Small isolated listener so the existing controls wiring stays readable. */
public final class SpeedPlusDiagnosticsClickListener implements View.OnClickListener {
    private final Context context;

    public SpeedPlusDiagnosticsClickListener(Context context) {
        this.context = context;
    }

    @Override public void onClick(View view) {
        SpeedPlusDiagnostics.copyToClipboard(context);
    }
}
