package com.tefire.meetbuddy.bootstrap;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.tefire.meetbuddy.entity.User;
import com.tefire.meetbuddy.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;

/**
 * 管理端种子账号引导：若库里还没有 13900000001，则创建管理员（role=1，密码 123456）。
 * 密码用 BCrypt 与登录校验同一套编码器，不写死哈希串。幂等：已存在就跳过。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class AdminSeedRunner implements CommandLineRunner {

    private static final String ADMIN_PHONE = "13900000001";

    private final UserMapper userMapper;

    @Override
    public void run(String... args) {
        if (userMapper.selectCount(new LambdaQueryWrapper<User>().eq(User::getPhone, ADMIN_PHONE)) > 0) {
            return;
        }
        BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
        User admin = new User();
        admin.setPhone(ADMIN_PHONE);
        admin.setPasswordHash(encoder.encode("123456"));
        admin.setNickname("管理员");
        admin.setCreditScore(100);
        admin.setGender(0);
        admin.setStatus(0);
        admin.setRole(1);
        admin.setLastActiveAt(LocalDateTime.now());
        userMapper.insert(admin);
        log.info("[meetbuddy] 已创建管理端种子账号 {} / 123456（role=1）", ADMIN_PHONE);
    }
}
