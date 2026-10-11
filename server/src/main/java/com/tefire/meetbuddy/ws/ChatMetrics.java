package com.tefire.meetbuddy.ws;

import lombok.Getter;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;

import org.springframework.stereotype.Component;

/**
 * 消息投递计数，用来回答论文里那句"到达率可统计"。
 *
 * <p>关键是把"到达"拆成两段，否则这个比率恒等于 100%、没有信息量：
 *
 * <ul>
 *   <li>{@code accepted} —— 服务端落库成功的消息数（分母）</li>
 *   <li>{@code deliveredOnline} —— 落库时对方正好在线、当帧就推出去的</li>
 *   <li>{@code queuedOffline} —— 落库时对方不在线，进了离线队列等重连补发</li>
 *   <li>{@code replayed} —— 重连时真正补发成功的条数</li>
 * </ul>
 *
 * <p>于是有两个不同口径的比率：<b>实时到达率</b>
 * {@code deliveredOnline / accepted} 衡量"在线时消息能不能即时送到"；
 * <b>最终到达率</b> {@code (deliveredOnline + replayed) / accepted} 衡量
 * "把离线补发也算上，消息最终有没有丢"。只有前者高、后者低，说明离线补发链路有问题。
 *
 * <p>计数放内存（{@code AtomicLong}）而不是 Redis：单机演示环境一台实例，
 * 进程重启后归零可以接受；换成多实例时才需要挪到 Redis 去汇总。
 */
@Component
@Getter
public class ChatMetrics {

    private final AtomicLong accepted = new AtomicLong();
    private final AtomicLong deliveredOnline = new AtomicLong();
    private final AtomicLong queuedOffline = new AtomicLong();
    private final AtomicLong replayed = new AtomicLong();
    private final AtomicLong rejected = new AtomicLong();
    private final AtomicLong acks = new AtomicLong();

    public void onAccepted() {
        accepted.incrementAndGet();
    }

    public void onDeliveredOnline() {
        deliveredOnline.incrementAndGet();
    }

    public void onQueuedOffline() {
        queuedOffline.incrementAndGet();
    }

    public void onReplayed(int count) {
        if (count > 0) {
            replayed.addAndGet(count);
        }
    }

    public void onRejected() {
        rejected.incrementAndGet();
    }

    public void onAck() {
        acks.incrementAndGet();
    }

    /** 给 /api/chat/stats 用的快照，比率保留四位小数。 */
    public Map<String, Object> snapshot() {
        long total = accepted.get();
        long online = deliveredOnline.get();
        long replay = replayed.get();
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("accepted", total);
        m.put("deliveredOnline", online);
        m.put("queuedOffline", queuedOffline.get());
        m.put("replayed", replay);
        m.put("rejected", rejected.get());
        m.put("acks", acks.get());
        m.put("realtimeDeliveryRate", ratio(online, total));
        m.put("eventualDeliveryRate", ratio(online + replay, total));
        m.put("offlineBacklog", Math.max(0, queuedOffline.get() - replay));
        return m;
    }

    private double ratio(long part, long total) {
        return total == 0 ? 0.0 : Math.round(part * 10000.0 / total) / 10000.0;
    }
}
