package com.tefire.meetbuddy.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.tefire.meetbuddy.common.PageVO;
import com.tefire.meetbuddy.common.error.CommonErrorCode;
import com.tefire.meetbuddy.common.error.BizAssert;
import com.tefire.meetbuddy.entity.Activity;
import com.tefire.meetbuddy.entity.CreditLog;
import com.tefire.meetbuddy.entity.Report;
import com.tefire.meetbuddy.entity.User;
import com.tefire.meetbuddy.mapper.ActivityMapper;
import com.tefire.meetbuddy.mapper.AdminMapper;
import com.tefire.meetbuddy.mapper.CreditLogMapper;
import com.tefire.meetbuddy.mapper.ReportMapper;
import com.tefire.meetbuddy.mapper.UserMapper;
import com.tefire.meetbuddy.service.AdminService;
import com.tefire.meetbuddy.service.CreditService;
import com.tefire.meetbuddy.vo.AdminActivityVO;
import com.tefire.meetbuddy.vo.AdminDashboardVO;
import com.tefire.meetbuddy.vo.AdminReportVO;
import com.tefire.meetbuddy.vo.AdminUserDetailVO;
import com.tefire.meetbuddy.vo.AdminUserVO;
import com.tefire.meetbuddy.vo.CategoryCount;
import com.tefire.meetbuddy.vo.CreditLogVO;
import com.tefire.meetbuddy.vo.DailyCount;
import com.tefire.meetbuddy.vo.DayCount;
import com.tefire.meetbuddy.vo.RegionCount;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.BeanUtils;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class AdminServiceImpl implements AdminService {

    private static final long DEFAULT_BAN_TTL = 7200;
    private static final String BAN_PREFIX = "ban:user:";

    /** 预设城市围栏（经度, 纬度），用户就近归类，对应 docs/04 第六节的地域分布口径。 */
    private static final double[][] CITY_CENTERS = {
            {116.40, 39.90, 0}, // 北京
            {121.47, 31.23, 1}, // 上海
            {113.26, 23.13, 2}, // 广州
            {104.06, 30.57, 3}, // 成都
    };
    private static final String[] CITY_NAMES = {"北京", "上海", "广州", "成都", "其他"};

    private final AdminMapper adminMapper;
    private final UserMapper userMapper;
    private final ActivityMapper activityMapper;
    private final ReportMapper reportMapper;
    private final CreditLogMapper creditLogMapper;
    private final CreditService creditService;
    private final StringRedisTemplate redisTemplate;

    @Override
    public AdminDashboardVO dashboard() {
        AdminDashboardVO vo = new AdminDashboardVO();
        vo.setTotalUsers(adminMapper.countAllUsers());
        vo.setTotalActivities(adminMapper.countAllActivities());
        vo.setOpenActivities(adminMapper.countOpenActivities());
        vo.setPendingReports(adminMapper.countPendingReports());
        vo.setTrend(buildTrend());
        vo.setCategories(adminMapper.categoryStats());
        vo.setRegions(buildRegions());
        return vo;
    }

    private List<DailyCount> buildTrend() {
        // 固定近 7 天（含今天）的日期轴，缺数据的那天补 0，保证前端折线连续。
        List<String> days = new ArrayList<>();
        DateTimeFormatter fmt = DateTimeFormatter.ofPattern("MM-dd");
        for (int i = 6; i >= 0; i--) {
            days.add(LocalDate.now().minusDays(i).format(fmt));
        }
        Map<String, DailyCount> byDate = new LinkedHashMap<>();
        for (String d : days) {
            DailyCount c = new DailyCount();
            c.setDate(d);
            c.setActivityCount(0L);
            c.setSignupCount(0L);
            c.setMessageCount(0L);
            byDate.put(d, c);
        }
        mergeActivity(adminMapper.activityDaily(), byDate);
        mergeSignup(adminMapper.signupDaily(), byDate);
        mergeMessage(adminMapper.messageDaily(), byDate);
        return new ArrayList<>(byDate.values());
    }

    private void mergeActivity(List<DayCount> src, Map<String, DailyCount> byDate) {
        for (DayCount c : src) {
            DailyCount target = byDate.get(trimDate(c.getDate()));
            if (target != null) {
                target.setActivityCount(c.getCount());
            }
        }
    }

    private void mergeSignup(List<DayCount> src, Map<String, DailyCount> byDate) {
        for (DayCount c : src) {
            DailyCount target = byDate.get(trimDate(c.getDate()));
            if (target != null) {
                target.setSignupCount(c.getCount());
            }
        }
    }

    private void mergeMessage(List<DayCount> src, Map<String, DailyCount> byDate) {
        for (DayCount c : src) {
            DailyCount target = byDate.get(trimDate(c.getDate()));
            if (target != null) {
                target.setMessageCount(c.getCount());
            }
        }
    }

    /** MySQL DATE() 返回 yyyy-MM-dd，看板轴用 MM-dd，截取后 5 位对齐。 */
    private String trimDate(String date) {
        return date == null ? "" : date.substring(Math.max(0, date.length() - 5));
    }

    private List<RegionCount> buildRegions() {
        List<User> users = userMapper.selectList(null);
        long[] counts = new long[CITY_NAMES.length];
        for (User u : users) {
            counts[nearestCity(u.getLastLng(), u.getLastLat())]++;
        }
        List<RegionCount> result = new ArrayList<>();
        for (int i = 0; i < CITY_NAMES.length; i++) {
            RegionCount rc = new RegionCount();
            rc.setRegion(CITY_NAMES[i]);
            rc.setCount(counts[i]);
            result.add(rc);
        }
        return result;
    }

    private int nearestCity(BigDecimal lng, BigDecimal lat) {
        if (lng == null || lat == null) {
            return CITY_NAMES.length - 1; // 其他
        }
        int best = CITY_NAMES.length - 1;
        double bestDist = Double.MAX_VALUE;
        for (int i = 0; i < CITY_CENTERS.length; i++) {
            double dx = lng.doubleValue() - CITY_CENTERS[i][0];
            double dy = lat.doubleValue() - CITY_CENTERS[i][1];
            double dist = dx * dx + dy * dy;
            if (dist < bestDist) {
                bestDist = dist;
                best = i;
            }
        }
        return best;
    }

    @Override
    public PageVO<AdminActivityVO> listActivities(String status, String keyword, long page, long size) {
        long offset = (page - 1) * size;
        List<AdminActivityVO> list = adminMapper.listActivities(status, keyword, offset, size);
        long total = adminMapper.countActivitiesFiltered(status, keyword);
        return new PageVO<>(list, total, page, size);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void takedown(Long activityId, String reason, Long adminId) {
        BizAssert.isTrue(adminMapper.setAdminStatus(activityId, 1) == 1,
                CommonErrorCode.NOT_FOUND, "活动 " + activityId + " 不存在");
        // 下架原因留痕：复用 report 的 handle_result 语义不合适，这里仅落库 admin_status，
        // 原因写入一条信用分流水之外的独立通道成本过高，先以日志形式记录，后续可扩 takedown_log 表。
        org.slf4j.LoggerFactory.getLogger(AdminServiceImpl.class)
                .info("[meetbuddy] 管理员 {} 下架活动 {}，原因：{}", adminId, activityId, reason);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void restore(Long activityId) {
        BizAssert.isTrue(adminMapper.setAdminStatus(activityId, 0) == 1,
                CommonErrorCode.NOT_FOUND, "活动 " + activityId + " 不存在");
    }

    @Override
    public PageVO<AdminReportVO> listReports(String status, long page, long size) {
        long offset = (page - 1) * size;
        List<AdminReportVO> list = adminMapper.listReports(status, offset, size);
        long total = adminMapper.countReportsFiltered(status);
        return new PageVO<>(list, total, page, size);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void handleReport(Long reportId, boolean approved, String handleResult, Long adminId) {
        Report report = BizAssert.notNull(reportMapper.selectById(reportId),
                CommonErrorCode.NOT_FOUND, "举报 " + reportId + " 不存在");
        BizAssert.isTrue("PENDING".equals(report.getStatus()),
                CommonErrorCode.PARAM_ERROR, "该举报已处理");

        if (approved) {
            if ("ACTIVITY".equals(report.getTargetType())) {
                Activity activity = activityMapper.selectById(report.getTargetId());
                if (activity != null) {
                    adminMapper.setAdminStatus(activity.getId(), 1);
                    creditService.change(activity.getOrganizerId(), -30,
                            "发布违规活动（举报成立，管理端判定）", reportId, adminId);
                }
            } else if ("USER".equals(report.getTargetType())) {
                creditService.change(report.getTargetId(), -20,
                        "被举报成立（管理端判定）", reportId, adminId);
            }
            adminMapper.handleReport(reportId, "APPROVED", adminId, handleResult);
        } else {
            adminMapper.handleReport(reportId, "REJECTED", adminId, handleResult);
        }
    }

    @Override
    public PageVO<AdminUserVO> listUsers(String keyword, long page, long size) {
        long offset = (page - 1) * size;
        List<AdminUserVO> list = adminMapper.listUsers(keyword, offset, size);
        long total = adminMapper.countUsersFiltered(keyword);
        return new PageVO<>(list, total, page, size);
    }

    @Override
    public AdminUserDetailVO userDetail(Long userId) {
        User user = BizAssert.notNull(userMapper.selectById(userId),
                CommonErrorCode.USER_NOT_FOUND);
        AdminUserDetailVO detail = new AdminUserDetailVO();
        detail.setUser(toUserVO(user));

        List<CreditLog> logs = creditLogMapper.selectList(
                new LambdaQueryWrapper<CreditLog>().eq(CreditLog::getUserId, userId)
                        .orderByDesc(CreditLog::getCreatedAt));
        List<CreditLogVO> logVOs = new ArrayList<>();
        for (CreditLog l : logs) {
            CreditLogVO v = new CreditLogVO();
            BeanUtils.copyProperties(l, v);
            logVOs.add(v);
        }
        detail.setCreditLogs(logVOs);

        List<Report> reports = reportMapper.selectList(new LambdaQueryWrapper<Report>()
                .and(w -> w.eq(Report::getTargetType, "USER").eq(Report::getTargetId, userId))
                .or(w -> w.eq(Report::getReporterId, userId))
                .orderByDesc(Report::getCreatedAt));
        detail.setReports(toReportVOs(reports));
        return detail;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void ban(Long userId, String reason, Long adminId) {
        User user = BizAssert.notNull(userMapper.selectById(userId),
                CommonErrorCode.USER_NOT_FOUND);
        adminMapper.setUserStatus(userId, 1);
        // 即时生效：写按人维度的封禁键，TTL 等于 access 有效期上限，过期自动解除。
        redisTemplate.opsForValue().set(BAN_PREFIX + userId, "1", Duration.ofSeconds(DEFAULT_BAN_TTL));
        org.slf4j.LoggerFactory.getLogger(AdminServiceImpl.class)
                .info("[meetbuddy] 管理员 {} 封禁用户 {}，原因：{}", adminId, userId, reason);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void unban(Long userId) {
        BizAssert.notNull(userMapper.selectById(userId), CommonErrorCode.USER_NOT_FOUND);
        adminMapper.setUserStatus(userId, 0);
        redisTemplate.delete(BAN_PREFIX + userId);
    }

    @Override
    public void adjustCredit(Long userId, int changeValue, String reason, Long adminId) {
        BizAssert.notNull(userMapper.selectById(userId), CommonErrorCode.USER_NOT_FOUND);
        creditService.change(userId, changeValue, reason, null, adminId);
    }

    private AdminUserVO toUserVO(User user) {
        AdminUserVO v = new AdminUserVO();
        BeanUtils.copyProperties(user, v);
        return v;
    }

    private List<AdminReportVO> toReportVOs(List<Report> reports) {
        List<AdminReportVO> result = new ArrayList<>();
        for (Report r : reports) {
            AdminReportVO v = new AdminReportVO();
            BeanUtils.copyProperties(r, v);
            result.add(v);
        }
        return result;
    }
}
