package com.tefire.meetbuddy.vo;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 他人个人主页。手机号等隐私字段刻意不返回；banned 让前端置灰——封禁是状态不是消失，
 * 参与者列表里同样看得到被封的人。规则见 docs/06。
 */
@Data
public class UserProfileVO {

    private Long userId;

    private String nickname;

    private String avatar;

    private String bio;

    private Integer creditScore;

    private boolean banned;

    /** 已解锁徽章，按 BadgeEnum 枚举序 */
    private List<BadgeVO> badges;

    /** 完成（FINISHED）的自己组织的活动数 */
    private int hostedCount;

    /** 完成（FINISHED）的有效参与活动数，不含取消与缺席 */
    private int joinedCount;

    /** 兴趣标签，公开展示，用于匹配与主页呈现 */
    private List<String> tags;

    /** 粉丝数：关注目标的用户数 */
    private long followerCount;

    /** 关注数：目标关注了多少人 */
    private long followingCount;

    /** 当前登录用户是否已关注目标；未登录、看自己时为 false */
    private boolean following;

    private List<RecentActivity> recentActivities;

    /** 最近活动摘要：组织与参加合并，按开始时间倒序，role 区分身份 */
    @Data
    public static class RecentActivity {

        private Long id;

        private String title;

        private String coverUrl;

        private String status;

        private LocalDateTime startTime;

        /** ORGANIZER 我组织的 / PARTICIPANT 我参加的 */
        private String role;
    }
}
