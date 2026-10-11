package com.tefire.meetbuddy.dto;

import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class SignupRequest {

    /** 报名留言，让组织者判断要不要放人进来 */
    @Size(max = 200)
    private String remark;
}
