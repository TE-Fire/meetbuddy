package com.tefire.meetbuddy.common;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 成就徽章定义，规则见 docs/06-成就勋章与个人主页.md。
 *
 * <p><b>为什么放代码内枚举而不建 badge 定义表</b>：徽章是运营文案，改一次发一版；
 * 进库就要配管理端的增删改界面，收益不抵复杂度。解锁记录才进库（user_badge）。
 * 新增徽章在枚举末尾追加即可，对扩展开放。
 *
 * <p><b>触发方式</b>：INSTANT 挂在事务方法末尾当场判定；SCAN 由 BadgeScanJob 在活动
 * 结束后扫描（"完成 N 次"要等终态，当场判不了）。
 */
@Getter
@AllArgsConstructor
public enum BadgeEnum {

    // —— 即时类：操作当场就能判定 ——

    FIRST_SIGNUP("FIRST_SIGNUP", "初出茅庐", "首次报名活动", "🌱", Trigger.INSTANT, 1, Group.NONE),
    FIRST_HOST("FIRST_HOST", "初次组局", "首次发布活动", "📣", Trigger.INSTANT, 1, Group.NONE),
    ATTENDED_3("ATTENDED_3", "靠谱伙伴", "被组织者确认到场累计 3 次", "🤝", Trigger.INSTANT, 3, Group.ATTENDED),

    // —— 扫描类：等活动结束（FINISHED）后由 BadgeScanJob 判定 ——

    JOIN_3("JOIN_3", "渐入佳境", "完成 3 次活动", "🚶", Trigger.SCAN, 3, Group.JOINED),
    JOIN_10("JOIN_10", "组局常客", "完成 10 次活动", "🏃", Trigger.SCAN, 10, Group.JOINED),
    HOST_3("HOST_3", "小有名气", "完成 3 次自己组织的活动", "🎪", Trigger.SCAN, 3, Group.HOSTED),
    HOST_10("HOST_10", "金牌组局人", "完成 10 次自己组织的活动", "👑", Trigger.SCAN, 10, Group.HOSTED),
    FULL_HOUSE("FULL_HOUSE", "座无虚席", "组织的活动满员结束至少 1 次", "🎉", Trigger.SCAN, 1, Group.FULL),
    ;

    /** 触发方式 */
    public enum Trigger {
        /** 事务方法末尾当场判定 */
        INSTANT,
        /** BadgeScanJob 活动结束后扫描 */
        SCAN
    }

    /**
     * 进度所属统计组。同一组内多枚徽章共享一次计数（如 JOIN_3 与 JOIN_10 都数"完成活动次数"），
     * 未解锁徽章的 progress 就是该组的当前值。NONE 表示一次性徽章，不展示进度。
     */
    public enum Group {
        NONE, JOINED, HOSTED, ATTENDED, FULL
    }

    private final String code;
    private final String name;
    private final String desc;
    private final String icon;
    private final Trigger trigger;
    /** 解锁所需的目标值 */
    private final int target;
    private final Group group;
}
