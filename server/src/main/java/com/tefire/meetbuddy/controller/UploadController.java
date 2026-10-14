package com.tefire.meetbuddy.controller;

import com.tefire.meetbuddy.common.Result;
import com.tefire.meetbuddy.common.error.BizAssert;
import com.tefire.meetbuddy.common.error.CommonErrorCode;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDate;
import java.util.Set;
import java.util.UUID;

/**
 * 图片上传。存本地磁盘、经 {@code /uploads/**} 静态映射回读，不引入对象存储——
 * 毕设单机演示场景下这是零依赖的方案，代价是水平扩容时要换成共享存储。
 *
 * <p>安全性只做三件事，都不复杂但必须做：扩展名白名单（挡可执行文件）、
 * 体积上限（挡磁盘打满，另在 application.yml 配了 multipart 双保险）、
 * UUID 重命名（原文件名可能带路径穿越或与既有文件冲突）。
 */
@Slf4j
@RestController
@RequestMapping("/api/upload")
public class UploadController {

    private static final Set<String> ALLOWED_EXT = Set.of("jpg", "jpeg", "png", "webp", "gif");

    /** 与 application.yml 的 max-file-size 保持一致，给出比 Spring 默认 400 更友好的错误 */
    private static final long MAX_SIZE = 5L * 1024 * 1024;

    @Value("${meetbuddy.upload.dir:uploads}")
    private String uploadDir;

    /**
     * 上传单张图片，返回可直接用于 {@code <image src>} 的完整 URL。
     *
     * <p>URL 用当前请求的 scheme/host/port 拼绝对地址：小程序端存的是这个字符串，
     * 之后详情页 {@code <image>} 直接渲染，不能再拼错base。
     */
    @PostMapping("/image")
    public Result<String> image(@RequestParam("file") MultipartFile file, HttpServletRequest request) {
        BizAssert.isTrue(!file.isEmpty(), CommonErrorCode.PARAM_ERROR, "文件为空");
        BizAssert.isTrue(file.getSize() <= MAX_SIZE, CommonErrorCode.PARAM_ERROR, "图片不能超过 5MB");

        String contentType = file.getContentType();
        BizAssert.isTrue(contentType != null && contentType.startsWith("image/"),
                CommonErrorCode.PARAM_ERROR, "只支持图片文件");

        String ext = resolveExt(file.getOriginalFilename());
        BizAssert.isTrue(ALLOWED_EXT.contains(ext), CommonErrorCode.PARAM_ERROR,
                "只支持 jpg / png / webp / gif");

        // 按天分目录，单目录文件数可控，清理过期文件也有的放矢
        String relPath = LocalDate.now() + "/" + UUID.randomUUID().toString().replace("-", "") + "." + ext;
        Path target = Paths.get(uploadDir).toAbsolutePath().normalize().resolve(relPath);
        try {
            Files.createDirectories(target.getParent());
            try (InputStream in = file.getInputStream()) {
                Files.copy(in, target);
            }
        } catch (IOException ex) {
            log.error("[upload] 保存失败 path={}", target, ex);
            throw CommonErrorCode.SYSTEM_ERROR.ex("图片保存失败");
        }

        String base = request.getScheme() + "://" + request.getServerName() + ":" + request.getServerPort();
        return Result.ok(base + "/uploads/" + relPath);
    }

    /** 取小写扩展名；原文件名缺失或没有扩展名时返回空串，由白名单挡掉 */
    private String resolveExt(String filename) {
        if (filename == null) {
            return "";
        }
        int dot = filename.lastIndexOf('.');
        if (dot < 0 || dot == filename.length() - 1) {
            return "";
        }
        return filename.substring(dot + 1).toLowerCase();
    }
}
