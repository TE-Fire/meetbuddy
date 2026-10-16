package com.tefire.meetbuddy.vo;

import lombok.Data;

import java.time.LocalDateTime;

/**
 * 徽章视图。未解锁时 progress/target 供前端画进度条，已解锁时 unlockedAt 供展示获得时间。
 * 我的徽章（/api/badge/mine）返回全部；他人主页只嵌已解锁的。
 */
@Data
public class BadgeVO {

    private String code;

    private String name;

    private String desc;

    private String icon;

    /** 进度所属统计组：NONE/JOINED/HOSTED/ATTENDED/FULL。NONE 为一次性徽章，不展示进度 */
    private String group;

    private boolean unlocked;

    private LocalDateTime unlockedAt;

    /** 当前进度值；NONE 组的一次性徽章为 0 */
    private int progress;

    /** 目标值；未解锁且达不目标时有意义，前端可显示 n/target */
    private int target;
}
