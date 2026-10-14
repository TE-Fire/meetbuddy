package com.tefire.meetbuddy.mapper;

import com.tefire.meetbuddy.vo.AdminActivityVO;
import com.tefire.meetbuddy.vo.AdminReportVO;
import com.tefire.meetbuddy.vo.AdminUserVO;
import com.tefire.meetbuddy.vo.CategoryCount;
import com.tefire.meetbuddy.vo.DayCount;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import java.util.List;

/**
 * 管理端专用只读聚合 + 列表查询。写操作（下架/处理举报/封禁/调分）走各自 Mapper 的细粒度语句，
 * 这里只放需要联表或分组的读取，避免把一堆 @Select 散到业务 Service 里。
 */
@Mapper
public interface AdminMapper {

    /* ── 看板计数 ── */
    @Select("SELECT COUNT(*) FROM user")
    long countAllUsers();

    @Select("SELECT COUNT(*) FROM activity")
    long countAllActivities();

    @Select("SELECT COUNT(*) FROM activity WHERE status = 'OPEN' AND admin_status = 0")
    long countOpenActivities();

    @Select("SELECT COUNT(*) FROM report WHERE status = 'PENDING'")
    long countPendingReports();

    /* ── 近 7 天趋势（三条线）── */
    @Select("SELECT DATE(created_at) AS date, COUNT(*) AS count FROM activity "
            + "WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY) GROUP BY DATE(created_at)")
    List<DayCount> activityDaily();

    @Select("SELECT DATE(created_at) AS date, COUNT(*) AS count FROM activity_signup "
            + "WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY) GROUP BY DATE(created_at)")
    List<DayCount> signupDaily();

    @Select("SELECT DATE(created_at) AS date, COUNT(*) AS count FROM message "
            + "WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY) GROUP BY DATE(created_at)")
    List<DayCount> messageDaily();

    @Select("SELECT category, COUNT(*) AS count FROM activity GROUP BY category")
    List<CategoryCount> categoryStats();

    /* ── 活动列表 ── */
    @Select("<script>SELECT a.id, a.title, a.category, a.status, a.admin_status AS adminStatus, "
            + "a.start_time AS startTime, a.end_time AS endTime, a.current_participants AS currentParticipants, "
            + "a.max_participants AS maxParticipants, a.address, a.created_at AS createdAt, u.nickname AS organizerNickname "
            + "FROM activity a LEFT JOIN user u ON a.organizer_id = u.id "
            + "<where>"
            + "<if test='status != null and status != \"\"'>AND a.status = #{status}</if>"
            + "<if test='keyword != null and keyword != \"\"'>AND a.title LIKE CONCAT('%', #{keyword}, '%')</if>"
            + "</where> ORDER BY a.created_at DESC LIMIT #{offset}, #{size}</script>")
    List<AdminActivityVO> listActivities(@Param("status") String status,
                                        @Param("keyword") String keyword,
                                        @Param("offset") long offset,
                                        @Param("size") long size);

    @Select("<script>SELECT COUNT(*) FROM activity a "
            + "<where>"
            + "<if test='status != null and status != \"\"'>AND a.status = #{status}</if>"
            + "<if test='keyword != null and keyword != \"\"'>AND a.title LIKE CONCAT('%', #{keyword}, '%')</if>"
            + "</where></script>")
    long countActivitiesFiltered(@Param("status") String status, @Param("keyword") String keyword);

    /* ── 举报列表（PENDING 置顶）── */
    @Select("<script>SELECT r.id, ru.nickname AS reporterNickname, r.target_type AS targetType, r.target_id AS targetId, "
            + "r.reason, r.evidence, r.status, r.handle_result AS handleResult, r.created_at AS createdAt, "
            + "CASE r.target_type WHEN 'ACTIVITY' THEN (SELECT title FROM activity WHERE id = r.target_id) "
            + "WHEN 'USER' THEN (SELECT nickname FROM user WHERE id = r.target_id) ELSE '' END AS targetTitle "
            + "FROM report r LEFT JOIN user ru ON r.reporter_id = ru.id "
            + "<where><if test='status != null and status != \"\"'>AND r.status = #{status}</if></where> "
            + "ORDER BY (r.status = 'PENDING') DESC, r.created_at DESC LIMIT #{offset}, #{size}</script>")
    List<AdminReportVO> listReports(@Param("status") String status,
                                    @Param("offset") long offset,
                                    @Param("size") long size);

    @Select("<script>SELECT COUNT(*) FROM report r "
            + "<where><if test='status != null and status != \"\"'>AND r.status = #{status}</if></where></script>")
    long countReportsFiltered(@Param("status") String status);

    /* ── 用户列表 ── */
    @Select("<script>SELECT id, phone, nickname, avatar, gender, credit_score AS creditScore, "
            + "status, role, last_active_at AS lastActiveAt, created_at AS createdAt FROM user "
            + "<where><if test='keyword != null and keyword != \"\"'>"
            + "AND (phone LIKE CONCAT('%', #{keyword}, '%') OR nickname LIKE CONCAT('%', #{keyword}, '%'))</if></where> "
            + "ORDER BY created_at DESC LIMIT #{offset}, #{size}</script>")
    List<AdminUserVO> listUsers(@Param("keyword") String keyword,
                                @Param("offset") long offset,
                                @Param("size") long size);

    @Select("<script>SELECT COUNT(*) FROM user "
            + "<where><if test='keyword != null and keyword != \"\"'>"
            + "AND (phone LIKE CONCAT('%', #{keyword}, '%') OR nickname LIKE CONCAT('%', #{keyword}, '%'))</if></where></script>")
    long countUsersFiltered(@Param("keyword") String keyword);

    /* ── 写操作（细粒度）── */
    @Update("UPDATE activity SET admin_status = #{s} WHERE id = #{id}")
    int setAdminStatus(@Param("id") Long id, @Param("s") int s);

    @Update("UPDATE report SET status = #{status}, handler_id = #{handlerId}, "
            + "handle_result = #{result}, updated_at = NOW() WHERE id = #{id}")
    int handleReport(@Param("id") Long id,
                     @Param("status") String status,
                     @Param("handlerId") Long handlerId,
                     @Param("result") String result);

    @Update("UPDATE user SET status = #{s} WHERE id = #{id}")
    int setUserStatus(@Param("id") Long id, @Param("s") int s);
}
