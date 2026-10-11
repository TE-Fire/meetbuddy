package com.tefire.meetbuddy.service.impl;

import com.tefire.meetbuddy.entity.CreditLog;
import com.tefire.meetbuddy.entity.User;
import com.tefire.meetbuddy.mapper.CreditLogMapper;
import com.tefire.meetbuddy.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CreditServiceImpl implements com.tefire.meetbuddy.service.CreditService {

    private static final int MIN = 0;
    private static final int MAX = 100;

    private final UserMapper userMapper;
    private final CreditLogMapper creditLogMapper;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void change(Long userId, int delta, String reason, Long relatedId, Long operatorId) {
        User user = userMapper.selectById(userId);
        if (user == null) {
            return;
        }
        int balance = clamp(user.getCreditScore() + delta);
        user.setCreditScore(balance);
        userMapper.updateById(user);

        CreditLog log = new CreditLog();
        log.setUserId(userId);
        log.setChangeValue(delta);
        log.setReason(reason);
        log.setRelatedId(relatedId);
        log.setOperatorId(operatorId);
        log.setBalanceAfter(balance);
        creditLogMapper.insert(log);
    }

    private int clamp(int score) {
        return Math.max(MIN, Math.min(MAX, score));
    }
}
