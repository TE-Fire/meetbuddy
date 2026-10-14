package com.tefire.meetbuddy.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record AdminCreditRequest(
        @NotNull Integer changeValue,
        @NotBlank(message = "调整原因必填") String reason
) {
}
