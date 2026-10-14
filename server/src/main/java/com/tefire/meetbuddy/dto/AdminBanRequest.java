package com.tefire.meetbuddy.dto;

import jakarta.validation.constraints.NotBlank;

public record AdminBanRequest(
        @NotBlank(message = "封禁原因必填") String reason
) {
}
