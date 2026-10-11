package com.tefire.meetbuddy.vo;

import lombok.Data;

/** 发布活动的出参。建群在建活动的同时完成，所以这里直接把 groupId 带回给前端，省一次查询。 */
@Data
public class CreateActivityVO {

    private Long id;

    private Long groupId;
}
