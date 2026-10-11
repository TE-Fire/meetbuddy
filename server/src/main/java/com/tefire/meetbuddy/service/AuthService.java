package com.tefire.meetbuddy.service;

import com.tefire.meetbuddy.dto.PasswordLoginRequest;
import com.tefire.meetbuddy.dto.RefreshRequest;
import com.tefire.meetbuddy.dto.RegisterRequest;
import com.tefire.meetbuddy.dto.SmsLoginRequest;
import com.tefire.meetbuddy.vo.TokenVO;

public interface AuthService {

    TokenVO register(RegisterRequest request);

    TokenVO loginByPassword(PasswordLoginRequest request);

    void sendSmsCode(String phone);

    TokenVO loginBySms(SmsLoginRequest request);

    TokenVO refresh(RefreshRequest request);

    /** 传入完整的 Authorization 头，内部自行剥离 Bearer 前缀 */
    void logout(String authorizationHeader);
}
