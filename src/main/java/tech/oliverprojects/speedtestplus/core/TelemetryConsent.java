package tech.oliverprojects.speedtestplus.core;

/** Explicit consent state; UNKNOWN and DECLINED both disable collection. */
public final class TelemetryConsent {
    public enum Status {
        UNKNOWN,
        DECLINED,
        GRANTED
    }

    private final Status status;
    private final int policyVersion;

    public TelemetryConsent(Status status, int policyVersion) {
        if (status == null) throw new IllegalArgumentException("status is required");
        if (policyVersion < 1) throw new IllegalArgumentException("policyVersion must be positive");
        this.status = status;
        this.policyVersion = policyVersion;
    }

    public Status status() {
        return status;
    }

    public int policyVersion() {
        return policyVersion;
    }

    public boolean permitsCollection(int currentPolicyVersion) {
        return status == Status.GRANTED && policyVersion == currentPolicyVersion;
    }
}
