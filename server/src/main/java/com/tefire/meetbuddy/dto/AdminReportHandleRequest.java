package com.tefire.meetbuddy.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record AdminReportHandleRequest(
        @NotNull Boolean approved,
        @NotBlank(message = "处理结果必填") String handleResult
) {
}
