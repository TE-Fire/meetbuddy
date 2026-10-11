package com.tefire.meetbuddy.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.util.List;

/** 覆盖式更新：传什么就是什么，不做增量合并——增量合并无法表达"删掉某个标签"。 */
@Data
public class TagsRequest {

    @NotNull
    @Size(max = 20)
    private List<String> tags;
}
