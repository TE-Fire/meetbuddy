package com.tefire.meetbuddy.controller;

import com.tefire.meetbuddy.common.Result;
import com.tefire.meetbuddy.dto.PasswordLoginRequest;
import com.tefire.meetbuddy.dto.RefreshRequest;
import com.tefire.meetbuddy.dto.RegisterRequest;
import com.tefire.meetbuddy.dto.SmsLoginRequest;
import com.tefire.meetbuddy.dto.SmsSendRequest;
import com.tefire.meetbuddy.service.AuthService;
import com.tefire.meetbuddy.vo.TokenVO;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/register")
    public Result<TokenVO> register(@Valid @RequestBody RegisterRequest request) {
        return Result.ok(authService.register(request));
    }

    @PostMapping("/login/password")
    public Result<TokenVO> loginByPassword(@Valid @RequestBody PasswordLoginRequest request) {
        return Result.ok(authService.loginByPassword(request));
    }

    @PostMapping("/sms/send")
    public Result<Void> sendSmsCode(@Valid @RequestBody SmsSendRequest request) {
        authService.sendSmsCode(request.phone());
        return Result.ok();
    }

    @PostMapping("/sms/login")
    public Result<TokenVO> loginBySms(@Valid @RequestBody SmsLoginRequest request) {
        return Result.ok(authService.loginBySms(request));
    }

    @PostMapping("/token/refresh")
    public Result<TokenVO> refresh(@Valid @RequestBody RefreshRequest request) {
        return Result.ok(authService.refresh(request));
    }

    @PostMapping("/logout")
    public Result<Void> logout(@RequestHeader(value = "Authorization", required = false) String authorization) {
        authService.logout(authorization);
        return Result.ok();
    }
}
