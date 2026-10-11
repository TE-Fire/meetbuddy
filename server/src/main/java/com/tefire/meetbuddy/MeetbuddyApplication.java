package com.tefire.meetbuddy;

import com.baomidou.mybatisplus.annotation.DbType;
import com.baomidou.mybatisplus.extension.plugins.MybatisPlusInterceptor;
import com.baomidou.mybatisplus.extension.plugins.inner.PaginationInnerInterceptor;
import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * {@code @EnableScheduling} 给 M4 的心跳巡检用（每 30 秒扫一次，90 秒没心跳的连接踢掉），
 * 后面活动状态推进的定时任务也挂在同一个调度器上。单机演示环境，不引调度中心。
 */
@SpringBootApplication
@EnableScheduling
@MapperScan("com.tefire.meetbuddy.mapper")
public class MeetbuddyApplication {

    public static void main(String[] args) {
        SpringApplication.run(MeetbuddyApplication.class, args);
    }

    /**
     * MyBatis-Plus 分页插件。不注册它，{@code selectPage} 会在底层退化成全表查询再内存截断，
     * 列表接口的数据量一大就会暴露出来。
     */
    @Bean
    public MybatisPlusInterceptor mybatisPlusInterceptor() {
        MybatisPlusInterceptor interceptor = new MybatisPlusInterceptor();
        interceptor.addInnerInterceptor(new PaginationInnerInterceptor(DbType.MYSQL));
        return interceptor;
    }
}
