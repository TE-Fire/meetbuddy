package com.tefire.meetbuddy.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.tefire.meetbuddy.common.error.BizAssert;
import com.tefire.meetbuddy.common.error.CommonErrorCode;
import com.tefire.meetbuddy.common.error.SmsErrorCode;
import com.tefire.meetbuddy.dto.PasswordLoginRequest;
import com.tefire.meetbuddy.dto.RefreshRequest;
import com.tefire.meetbuddy.dto.RegisterRequest;
import com.tefire.meetbuddy.dto.SmsLoginRequest;
import com.tefire.meetbuddy.entity.User;
import com.tefire.meetbuddy.mapper.UserMapper;
import com.tefire.meetbuddy.service.AuthService;
import com.tefire.meetbuddy.util.JwtUtil;
import com.tefire.meetbuddy.vo.TokenVO;
import io.jsonwebtoken.Claims;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthServiceImpl implements AuthService {

    private static final String SMS_CODE_KEY = "sms:code:";
    private static final String SMS_LIMIT_KEY = "sms:limit:";
    private static final String BLACKLIST_KEY = "jwt:blacklist:";
    private static final String BEARER = "Bearer ";
    private static final long CODE_TTL_SECONDS = 300;
    private static final long LIMIT_TTL_SECONDS = 60;
    private static final int INITIAL_CREDIT = 100;

    private final UserMapper userMapper;
    private final StringRedisTemplate redisTemplate;
    private final JwtUtil jwtUtil;

    /** BCryptPasswordEncoder 无状态且线程安全，无需注册成容器 Bean */
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    @Value("${meetbuddy.dev.fixed-code-enabled:false}")
    private boolean fixedCodeEnabled;

    @Value("${meetbuddy.dev.fixed-code:123456}")
    private String fixedCode;

    @Override
    public TokenVO register(RegisterRequest request) {
        if (countByPhone(request.phone()) > 0) {
            throw CommonErrorCode.USER_EXISTS.ex();
        }
        verifyCode(request.phone(), request.smsCode());

        User user = new User();
        user.setPhone(request.phone());
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setNickname(request.nickname());
        user.setCreditScore(INITIAL_CREDIT);
        user.setGender(0);
        user.setStatus(0);
        user.setLastActiveAt(LocalDateTime.now());
        userMapper.insert(user);

        return issueTokens(user);
    }

    @Override
    public TokenVO loginByPassword(PasswordLoginRequest request) {
        User user = BizAssert.notNull(selectByPhone(request.phone()), CommonErrorCode.LOGIN_FAIL);
        checkBanned(user);
        if (user.getPasswordHash() == null
                || !passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw CommonErrorCode.LOGIN_FAIL.ex();
        }
        return issueTokens(user);
    }

    @Override
    public void sendSmsCode(String phone) {
        if (Boolean.FALSE.equals(
                redisTemplate.opsForValue().setIfAbsent(SMS_LIMIT_KEY + phone, "1",
                        Duration.ofSeconds(LIMIT_TTL_SECONDS)))) {
            throw SmsErrorCode.SMS_SEND_TOO_OFTEN.ex();
        }

        String code = fixedCodeEnabled ? fixedCode : randomCode();
        redisTemplate.opsForValue().set(SMS_CODE_KEY + phone, code, Duration.ofSeconds(CODE_TTL_SECONDS));
        log.info("[meetbuddy] 验证码 {} -> {}（演示环境不下发真实短信）", phone, code);
    }

    @Override
    public TokenVO loginBySms(SmsLoginRequest request) {
        verifyCode(request.phone(), request.code());
        User user = selectByPhone(request.phone());
        if (user == null) {
            user = new User();
            user.setPhone(request.phone());
            user.setNickname("用户" + request.phone().substring(7));
            user.setCreditScore(INITIAL_CREDIT);
            user.setGender(0);
            user.setStatus(0);
            user.setLastActiveAt(LocalDateTime.now());
            userMapper.insert(user);
        }
        checkBanned(user);
        return issueTokens(user);
    }

    @Override
    public TokenVO refresh(RefreshRequest request) {
        Claims claims = jwtUtil.parse(request.refreshToken());
        if (claims == null || !"refresh".equals(claims.get("type"))) {
            throw CommonErrorCode.UNAUTHORIZED.ex();
        }
        User user = BizAssert.notNull(userMapper.selectById(Long.valueOf(claims.getSubject())),
                CommonErrorCode.USER_NOT_FOUND);
        return issueTokens(user);
    }

    @Override
    public void logout(String authorizationHeader) {
        if (authorizationHeader == null || !authorizationHeader.startsWith(BEARER)) {
            return;
        }
        Claims claims = jwtUtil.parse(authorizationHeader.substring(BEARER.length()));
        if (claims == null || claims.getExpiration() == null) {
            return;
        }
        long ttl = (claims.getExpiration().getTime() - System.currentTimeMillis()) / 1000;
        if (ttl > 0) {
            redisTemplate.opsForValue().set(BLACKLIST_KEY + claims.getId(), "1", Duration.ofSeconds(ttl));
        }
    }

    private long countByPhone(String phone) {
        return userMapper.selectCount(new LambdaQueryWrapper<User>().eq(User::getPhone, phone));
    }

    private User selectByPhone(String phone) {
        return userMapper.selectOne(new LambdaQueryWrapper<User>().eq(User::getPhone, phone));
    }

    private void checkBanned(User user) {
        if (user.getStatus() != null && user.getStatus() == 1) {
            throw CommonErrorCode.USER_BANNED.ex();
        }
    }

    private void verifyCode(String phone, String code) {
        String cached = redisTemplate.opsForValue().get(SMS_CODE_KEY + phone);
        if (cached == null || !cached.equals(code)) {
            throw SmsErrorCode.SMS_CODE_ERROR.ex();
        }
        redisTemplate.delete(SMS_CODE_KEY + phone);
    }

    private TokenVO issueTokens(User user) {
        String accessToken = jwtUtil.createAccessToken(user.getId(), UUID.randomUUID().toString(), user.getRole());
        String refreshToken = jwtUtil.createRefreshToken(user.getId(), UUID.randomUUID().toString(), user.getRole());
        return new TokenVO(accessToken, refreshToken, com.tefire.meetbuddy.vo.UserVO.from(user));
    }

    private String randomCode() {
        return String.format("%06d", new SecureRandom().nextInt(1_000_000));
    }
}
