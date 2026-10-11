package com.tefire.meetbuddy.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/** 发布与编辑活动共用，编辑时同样要求字段完整——部分更新会让"编辑后字段丢失"的责任难以界定。 */
@Data
public class ActivityCreateRequest {

    @NotBlank
    @Size(max = 64)
    private String title;

    @Size(max = 2000)
    private String description;

    /** 剧本杀 / 运动 / 探店 / 拼车 / 其他 */
    @NotBlank
    private String category;

    private String coverUrl;

    @NotNull
    private BigDecimal lng;

    @NotNull
    private BigDecimal lat;

    @NotBlank
    private String address;

    @NotNull
    private LocalDateTime startTime;

    @NotNull
    private LocalDateTime endTime;

    /** 可报名人数上限，不含组织者 */
    @NotNull
    @Min(1)
    @Max(200)
    private Integer maxParticipants;

    /** 参与所需最低信用分，缺省 60 */
    private Integer creditRequired;

    private List<String> tags;

    private List<String> images;
}
