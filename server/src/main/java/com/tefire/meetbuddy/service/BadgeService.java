package com.tefire.meetbuddy.service;

import com.tefire.meetbuddy.common.BadgeEnum;
import com.tefire.meetbuddy.vo.BadgeVO;

import java.util.List;

/**
 * 成就徽章。规则见 docs/06-成就勋章与个人主页.md。
 *
 * <p>两类触发：{@link #checkInstant} 给事务方法末尾的即时挂点用（当场能判定）；
 * {@link #checkScanned} 给 BadgeScanJob 用（活动结束后的扫描类）。两者最终都走
 * {@code unlock}，幂等靠 user_badge 的唯一索引。
 */
public interface BadgeService {

    /** 我的徽章：全部徽章（含未解锁与进度），按 BadgeEnum 枚举序 */
    List<BadgeVO> myBadges(Long userId);

    /** 已解锁徽章（他人主页用），按 BadgeEnum 枚举序 */
    List<BadgeVO> unlockedBadges(Long userId);

    /**
     * 即时挂点调用。对 NONE 组（首次报名/首次发起）直接解锁；对带组徽章
     * （如 ATTENDED_3）按该组当前值判定，达到 target 才解锁。
     */
    void checkInstant(Long userId, BadgeEnum badge);

    /** 扫描挂点调用：对该用户的全部 SCAN 类徽章跑一遍阈值检查 */
    void checkScanned(Long userId);
}
