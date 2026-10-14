package com.tefire.meetbuddy.config;

import com.tefire.meetbuddy.interceptor.AdminAuthInterceptor;
import com.tefire.meetbuddy.interceptor.AuthInterceptor;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * 登录校验只放行 /api/auth/**，其余 /api 接口一律要求登录。
 * 采用"先放行白名单"而不是"逐接口加注解"，是为了避免以后新增接口时漏加注解造成越权。
 *
 * <p>另配一份 CORS。Flutter Web 用浏览器预览，页面与后端不同源，没有这份映射
 * 浏览器会在预检阶段就把请求拦掉（表现为前端报 Failed to fetch，后端日志一条没有）。
 * 预检请求由 {@link AuthInterceptor} 先放行，两者缺一不可。
 */
@Configuration
@RequiredArgsConstructor
public class WebMvcConfig implements WebMvcConfigurer {

    private final AuthInterceptor authInterceptor;
    private final AdminAuthInterceptor adminAuthInterceptor;

    /**
     * 允许的来源。开发期 Flutter 每次跑起来的端口都不一样（`flutter run -d edge`
     * 的端口是随机的），写死某个端口第二天就失效，所以按 localhost / 127.0.0.1 通配。
     *
     * <p>用的是 allowedOriginPatterns 而不是 allowedOrigins：后者不接受通配符的端口段，
     * 而且在放开凭据时不能与 `*` 混用。这里走的是 Bearer 头而不是 Cookie，
     * 所以不放开 allowCredentials。
     *
     * <p>cors.allowed-origins 在配置里留了覆盖口子，上线前改成正式前端域名。
     */
    @Value("${meetbuddy.cors.allowed-origin-patterns:http://localhost:*,http://127.0.0.1:*}")
    private String[] allowedOriginPatterns;

    @Value("${meetbuddy.upload.dir:uploads}")
    private String uploadDir;

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(authInterceptor)
                .addPathPatterns("/api/**", "/admin/**")
                .excludePathPatterns("/api/auth/**");

        // 管理端闸门必须排在 AuthInterceptor 之后：先完成鉴权、写入 UserContext，再校验 role。
        registry.addInterceptor(adminAuthInterceptor)
                .addPathPatterns("/admin/**");
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {        registry.addMapping("/api/**")
                .allowedOriginPatterns(allowedOriginPatterns)
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("*")
                .exposedHeaders("X-Api-Version")
                .allowCredentials(false)
                .maxAge(3600);

        // WebSocket 握手走的是 /ws，不是普通 MVC 请求，CORS 映射管不到它；
        // 那边的来源校验在 WebSocketConfig.setAllowedOriginPatterns 里单独配。
    }

    /**
     * 上传目录按静态资源暴露。{@code file:} 定位符必须是绝对路径——工作目录随启动方式变化
     * （run-local.sh 在 server/ 下，IDE 直启可能在仓库根），相对路径会让图片时好时坏。
     *
     * <p>该路径刻意不挂 /api/**：登录拦截放不掉 {@code <image>} 组件（它发不了
     * Authorization 头），活动图片本来就是公开内容，无需鉴权。
     */
    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        Path uploadPath = Paths.get(uploadDir).toAbsolutePath().normalize();
        String location = uploadPath.toUri().toString();
        // ⚠ 尾斜杠不能省：Path.toUri() 对不带分隔符结尾的目录不补 /，而 Spring 按 URI
        // 语义做相对解析——基址少了尾斜杠会把最后一段当文件名替换掉：
        //   file:///…/server/uploads + 2026-10-14/x.png → file:///…/server/2026-10-14/x.png
        // 现象是文件明明在磁盘上却报 NoResourceFoundException。Boot 自带的
        // classpath:/static/ 一类位置都带尾斜杠，所以照抄它就不会踩。
        if (!location.endsWith("/")) {
            location += "/";
        }
        registry.addResourceHandler("/uploads/**")
                .addResourceLocations(location);
    }
}
