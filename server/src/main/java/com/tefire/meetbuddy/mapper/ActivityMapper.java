package com.tefire.meetbuddy.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.tefire.meetbuddy.entity.Activity;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Update;

@Mapper
public interface ActivityMapper extends BaseMapper<Activity> {

    /**
     * 抢占名额：把计数自增和"是否已满"的判断压进同一条 SQL，靠数据库的行锁兜底。
     *
     * <p>这是防超员的最后一道防线——分布式锁只是让并发串行化、减少冲突，
     * 真正保证计数不会越过上限的是这条语句的 {@code current_participants < max_participants} 条件。
     * 返回影响行数，0 表示没抢到（已满或状态不允许报名）。
     */
    @Update("UPDATE activity SET current_participants = current_participants + 1 "
            + "WHERE id = #{id} AND status = 'OPEN' AND current_participants < max_participants")
    int reserveSlot(@Param("id") Long id);

    /** 计数达到上限后把状态推成 FULL，关闭报名入口。 */
    @Update("UPDATE activity SET status = 'FULL' "
            + "WHERE id = #{id} AND status = 'OPEN' AND current_participants >= max_participants")
    int markFull(@Param("id") Long id);

    /**
     * 无条件自增，只用于"无锁对照组"实验。
     *
     * <p>这条语句不做任何上限判断，纯粹模拟"先查再写"在高并发下会发生的超卖。
     * 生产路径走 {@link #reserveSlot(Long)}，不要调这个。
     */
    @Update("UPDATE activity SET current_participants = current_participants + 1 WHERE id = #{id}")
    int incrSlotUnchecked(@Param("id") Long id);

    /** 取消报名后归还名额。 */
    @Update("UPDATE activity SET current_participants = current_participants - 1 "
            + "WHERE id = #{id} AND current_participants > 0")
    int releaseSlot(@Param("id") Long id);

    /** 名额空出后从 FULL 退回 OPEN。 */
    @Update("UPDATE activity SET status = 'OPEN' "
            + "WHERE id = #{id} AND status = 'FULL' AND current_participants < max_participants")
    int reopen(@Param("id") Long id);
}
