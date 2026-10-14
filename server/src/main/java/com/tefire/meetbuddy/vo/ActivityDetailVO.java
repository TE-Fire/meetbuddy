package com.tefire.meetbuddy.vo;

import com.fasterxml.jackson.annotation.JsonProperty;
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

    /** 是否已建群（有 groupId 即可进群聊） */
    private boolean hasGroup;

    /** 活动是否已关闭（非 OPEN/FULL，组织者不可再取消）。
     *  boolean 字段名以 is 开头时 Lombok 的 getter 是 isClosed()，Jackson 会按 bean 规则
     *  把属性序列化成 closed，与前端契约字段名不符，这里显式钉死。 */
    @JsonProperty("isClosed")
    private boolean isClosed;

    /** 当前用户是否可报名：登录、非组织者、未报名、OPEN、未满 */
    private boolean canSignUp;

    /** 当前用户是否可取消报名：已报名且活动仍在 OPEN/FULL */
    private boolean canCancelSignUp;

    /** 参与者摘要，详情接口一次带出，省掉前端的二次请求 */
    private List<ParticipantVO> participants;
}
