package com.tefire.meetbuddy.vo;

import lombok.Data;
import lombok.EqualsAndHashCode;

import java.util.List;

@Data
@EqualsAndHashCode(callSuper = true)
public class ActivityDetailVO extends ActivityVO {

    private String description;

    private List<String> images;

    private Long groupId;

    /** 当前登录用户是否已报名，未登录时为 false */
    private boolean signedUp;

    /** 当前登录用户是否收藏 */
    private boolean favorited;

    /** 当前登录用户是否为组织者 */
    private boolean organizer;

    /** 参与者摘要，详情接口一次带出，省掉前端的二次请求 */
    private List<ParticipantVO> participants;
}
