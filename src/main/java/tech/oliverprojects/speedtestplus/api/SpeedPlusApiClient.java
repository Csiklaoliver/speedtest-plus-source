package tech.oliverprojects.speedtestplus.api;

import java.util.List;

/**
 * Platform adapters implement transport. Implementations must follow the
 * OpenAPI, privacy, timeout, and consent contracts in this repository.
 */
public interface SpeedPlusApiClient {
    void submitConsentedEvents(List<String> validatedJsonEvents, Callback callback);

    void submitReviewedBugReport(String validatedJsonReport, Callback callback);

    interface Callback {
        void onSuccess();

        void onFailure(String safeUserMessage);
    }
}
