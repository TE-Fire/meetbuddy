package com.tefire.meetbuddy.dto;

import jakarta.validation.constraints.NotBlank;

public record AdminTakedownRequest(
        @NotBlank(message = "下架原因必填") String reason
) {
}
