package com.tefire.meetbuddy.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.List;

/** 组织者在活动结束后批量确认到场与缺席，信用分按 docs/01 第四节加减。 */
@Data
public class AttendRequest {

    @NotNull
    private List<Long> attended;

    @NotNull
    private List<Long> absent;
}
