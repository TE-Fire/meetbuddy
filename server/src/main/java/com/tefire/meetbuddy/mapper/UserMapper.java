package com.tefire.meetbuddy.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.tefire.meetbuddy.entity.User;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface UserMapper extends BaseMapper<User> {
}
