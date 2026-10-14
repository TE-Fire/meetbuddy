package com.tefire.meetbuddy.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record ReportSubmitRequest(
        @NotBlank String targetType,
        @NotNull Long targetId,
        @NotBlank String reason,
        String evidence
) {
}
