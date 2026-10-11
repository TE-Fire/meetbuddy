package com.tefire.meetbuddy.common;

import lombok.Data;

import java.util.List;

/**
 * 分页出参，形状由接口契约第一节定死：{ list, total, page, size }。
 * 所有列表接口统一用这个，前端只写一套分页逻辑。
 */
@Data
public class PageVO<T> {

    private List<T> list;

    private long total;

    private long page;

    private long size;

    public PageVO(List<T> list, long total, long page, long size) {
        this.list = list;
        this.total = total;
        this.page = page;
        this.size = size;
    }
}
