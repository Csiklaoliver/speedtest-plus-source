package com.ookla.mobile4.views;

import android.animation.Animator;
import android.content.Context;
import android.content.SharedPreferences;
import android.provider.Settings;
import android.widget.CompoundButton;

/**
 * Android adapter for the privacy-safe reduced-motion preference.
 *
 * <p>The setting is local, presentation-only, and intentionally does not
 * touch measured values or network configuration.  Native gauge and guide
 * animations should call {@link #configureAnimator(Animator, Context)}
 * before starting.</p>
 */
public final class SpeedPlusMotion {
    private static final String PREFS = "speedtest_plus_mod";
    private static final String KEY = "reduce_motion";

    private SpeedPlusMotion() { }

    public static boolean isReduced(Context context) {
        if (context == null) return false;
        SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        if (prefs.getBoolean(KEY, false)) return true;
        // Android's global animator scale is readable without a special
        // permission.  A zero scale is the system's "remove animations"
        // convention; malformed or unavailable values fail open.
        try {
            float scale = Settings.Global.getFloat(context.getContentResolver(),
                    Settings.Global.ANIMATOR_DURATION_SCALE, 1.0f);
            return scale <= 0.0f;
        } catch (RuntimeException ignored) {
            return false;
        }
    }

    public static void setReduced(Context context, boolean enabled) {
        if (context == null) return;
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putBoolean(KEY, enabled).apply();
    }

    /**
     * Binds a controls-panel switch without forcing a particular widget
     * implementation.  The caller can still style the switch normally.
     */
    public static void bindSwitch(final CompoundButton control, final Context context) {
        if (control == null || context == null) return;
        control.setChecked(isReduced(context));
        control.setOnCheckedChangeListener((button, checked) -> setReduced(context, checked));
        control.setContentDescription("Reduce gauge motion; presentation only");
    }

    /**
     * Removes animator movement when reduced motion is active.  A null
     * animator is accepted so callers can safely use this at lifecycle edges.
     */
    public static void configureAnimator(Animator animator, Context context) {
        if (animator == null) return;
        if (isReduced(context)) animator.setDuration(0L);
    }
}
