package tech.oliverprojects.speedtestplus;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import java.lang.ref.WeakReference;
import java.util.Locale;

/** Optional, local-only help after failure; never installs or enables a VPN. */
public final class SpeedPlusConnectionHelp {
    private static boolean shown;
    private SpeedPlusConnectionHelp() {}

    public static boolean needsVendorHint(String manufacturer, String brand) {
        String name = (manufacturer + " " + brand).toLowerCase(Locale.ROOT);
        for (String vendor : new String[]{"xiaomi", "redmi", "poco", "oppo", "realme",
                "vivo", "iqoo", "huawei", "honor", "oneplus"}) {
            if (name.contains(vendor)) return true;
        }
        return false;
    }

    public static void show(Activity activity) {
        if (activity == null) return;
        WeakReference<Activity> reference = new WeakReference<>(activity);
        new Handler(Looper.getMainLooper()).postDelayed(() -> {
            Activity owner = reference.get();
            if (shown || owner == null || owner.isFinishing() || owner.isDestroyed()) return;
            String message = "A test failed. Try another server or switch between Wi-Fi and mobile data. "
                    + "Check whether your network requires a sign-in.\n\n";
            if (needsVendorHint(Build.MANUFACTURER, Build.BRAND)) {
                message += "On this device, also check Speedtest+'s Wi-Fi/mobile-data permissions "
                        + "and battery restrictions in system settings. The brand alone does not mean it is incompatible.\n\n";
            }
            message += "If connections still fail, Cloudflare's 1.1.1.1 app with WARP is an optional "
                    + "workaround reported by a user, not a guaranteed fix. WARP uses a VPN and changes "
                    + "your network route, so measured speeds may differ.\n\n"
                    + "Offline simulation can run without a server. It is not a real connection measurement.";
            try {
                new AlertDialog.Builder(owner).setTitle("Connection help")
                        .setMessage(message).setNegativeButton("Close", null)
                        .setPositiveButton("WARP guide", (dialog, which) -> {
                            try {
                                owner.startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(
                                        "https://developers.cloudflare.com/warp-client/get-started/android/")));
                            } catch (RuntimeException unavailable) { /* No browser installed. */ }
                        }).show();
                shown = true;
            } catch (RuntimeException unavailable) { /* Activity stopped during dispatch. */ }
        }, 1500);
    }
}
