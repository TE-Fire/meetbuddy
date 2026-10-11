-- meetbuddy 建表脚本
-- 与 docs/02-数据库设计.md 一一对应；改表结构请先改文档再改这里。

CREATE DATABASE IF NOT EXISTS meetbuddy
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE meetbuddy;

-- ---------- 用户域 ----------

CREATE TABLE IF NOT EXISTS `user` (
  id              BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
  phone           VARCHAR(11)  NOT NULL COMMENT '手机号，登录账号',
  password_hash   VARCHAR(100) DEFAULT NULL COMMENT 'BCrypt 哈希，纯验证码注册时为空',
  nickname        VARCHAR(32)  NOT NULL COMMENT '昵称',
  avatar          VARCHAR(255) DEFAULT NULL COMMENT '头像 URL',
  gender          TINYINT      NOT NULL DEFAULT 0 COMMENT '0 未知 / 1 男 / 2 女',
  bio             VARCHAR(200) DEFAULT NULL COMMENT '个人简介',
  credit_score    INT          NOT NULL DEFAULT 100 COMMENT '信用分，区间 [0,100]',
  status          TINYINT      NOT NULL DEFAULT 0 COMMENT '0 正常 / 1 封禁',
  last_lng        DECIMAL(10,7) DEFAULT NULL COMMENT '最近一次上报的经度',
  last_lat        DECIMAL(10,7) DEFAULT NULL COMMENT '最近一次上报的纬度',
  last_active_at  DATETIME     DEFAULT NULL COMMENT '最近活跃时间',
  created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_phone (phone),
  KEY idx_status (status)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '用户';

CREATE TABLE IF NOT EXISTS user_tag (
  id         BIGINT      NOT NULL AUTO_INCREMENT,
  user_id    BIGINT      NOT NULL,
  tag_name   VARCHAR(32) NOT NULL COMMENT '开放集合，不用字典表',
  created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_user_tag (user_id, tag_name),
  KEY idx_tag (tag_name)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '用户兴趣标签';

CREATE TABLE IF NOT EXISTS favorite (
  id          BIGINT   NOT NULL AUTO_INCREMENT,
  user_id     BIGINT   NOT NULL,
  activity_id BIGINT   NOT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_user_activity (user_id, activity_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '收藏';

-- ---------- 活动域 ----------

CREATE TABLE IF NOT EXISTS activity (
  id                   BIGINT        NOT NULL AUTO_INCREMENT,
  organizer_id         BIGINT        NOT NULL COMMENT '组织者',
  title                VARCHAR(64)   NOT NULL,
  description          VARCHAR(2000) DEFAULT NULL,
  category             VARCHAR(32)   NOT NULL COMMENT '剧本杀/运动/探店/拼车/其他',
  cover_url            VARCHAR(255)  DEFAULT NULL,
  lng                  DECIMAL(10,7) NOT NULL COMMENT '活动地点经度',
  lat                  DECIMAL(10,7) NOT NULL COMMENT '活动地点纬度',
  address              VARCHAR(255)  NOT NULL COMMENT '地点文字描述',
  start_time           DATETIME      NOT NULL,
  end_time             DATETIME      NOT NULL,
  max_participants     INT           NOT NULL COMMENT '人数上限',
  current_participants INT           NOT NULL DEFAULT 0 COMMENT '冗余计数，由报名锁保证正确',
  status               VARCHAR(16)   NOT NULL DEFAULT 'OPEN' COMMENT 'OPEN/FULL/ONGOING/FINISHED/CANCELLED',
  credit_required      INT           NOT NULL DEFAULT 60 COMMENT '参与所需最低信用分',
  group_id             BIGINT        DEFAULT NULL COMMENT '关联群聊，活动创建时生成',
  created_at           DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at           DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_status_time (status, start_time),
  KEY idx_organizer (organizer_id),
  KEY idx_category (category)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '活动';

CREATE TABLE IF NOT EXISTS activity_tag (
  id          BIGINT      NOT NULL AUTO_INCREMENT,
  activity_id BIGINT      NOT NULL,
  tag_name    VARCHAR(32) NOT NULL,
  created_at  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_activity_tag (activity_id, tag_name),
  KEY idx_tag (tag_name)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '活动标签';

CREATE TABLE IF NOT EXISTS activity_image (
  id          BIGINT       NOT NULL AUTO_INCREMENT,
  activity_id BIGINT       NOT NULL,
  image_url   VARCHAR(255) NOT NULL,
  sort        INT          NOT NULL DEFAULT 0,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_activity (activity_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '活动图片，单独建表以便对单张图做审核';

CREATE TABLE IF NOT EXISTS activity_signup (
  id          BIGINT      NOT NULL AUTO_INCREMENT,
  activity_id BIGINT      NOT NULL,
  user_id     BIGINT      NOT NULL,
  status      VARCHAR(16) NOT NULL DEFAULT 'SIGNED' COMMENT 'SIGNED/CANCELED/ATTENDED/ABSENT',
  remark      VARCHAR(200) DEFAULT NULL COMMENT '报名留言',
  created_at  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_activity_user (activity_id, user_id) COMMENT '防超员的最后一道防线',
  KEY idx_user (user_id),
  KEY idx_activity_status (activity_id, status)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '报名记录';

-- ---------- 搭子域 ----------

CREATE TABLE IF NOT EXISTS buddy_request (
  id          BIGINT        NOT NULL AUTO_INCREMENT,
  user_id     BIGINT        NOT NULL,
  title       VARCHAR(64)   NOT NULL,
  description VARCHAR(2000) DEFAULT NULL,
  category    VARCHAR(32)   NOT NULL,
  lng         DECIMAL(10,7) NOT NULL,
  lat         DECIMAL(10,7) NOT NULL,
  time_range  VARCHAR(64)   DEFAULT NULL COMMENT '自由文本，如"周末下午"',
  status      VARCHAR(16)   NOT NULL DEFAULT 'OPEN' COMMENT 'OPEN/CLOSED',
  created_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_user (user_id),
  KEY idx_status (status)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '搭子需求，无人数上限与截止时间';

CREATE TABLE IF NOT EXISTS buddy_tag (
  id         BIGINT      NOT NULL AUTO_INCREMENT,
  request_id BIGINT      NOT NULL,
  tag_name   VARCHAR(32) NOT NULL,
  created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_request_tag (request_id, tag_name),
  KEY idx_tag (tag_name)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '搭子标签';

-- ---------- 通信域 ----------

CREATE TABLE IF NOT EXISTS chat_group (
  id           BIGINT      NOT NULL AUTO_INCREMENT,
  activity_id  BIGINT      DEFAULT NULL COMMENT '活动群非空，预留非活动群',
  name         VARCHAR(64) NOT NULL,
  member_count INT         NOT NULL DEFAULT 0,
  created_at   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_activity (activity_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '群组，活动创建时同步建立';

CREATE TABLE IF NOT EXISTS chat_group_member (
  id        BIGINT   NOT NULL AUTO_INCREMENT,
  group_id  BIGINT   NOT NULL,
  user_id   BIGINT   NOT NULL,
  role      VARCHAR(16) NOT NULL DEFAULT 'MEMBER' COMMENT 'OWNER/MEMBER',
  joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_group_user (group_id, user_id),
  KEY idx_user (user_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '群成员';

CREATE TABLE IF NOT EXISTS message (
  id          BIGINT        NOT NULL AUTO_INCREMENT,
  group_id    BIGINT        DEFAULT NULL COMMENT '群聊非空，单聊为空',
  sender_id   BIGINT        NOT NULL,
  receiver_id BIGINT        DEFAULT NULL COMMENT '单聊非空，群聊为空',
  msg_type    VARCHAR(16)   NOT NULL DEFAULT 'TEXT' COMMENT 'TEXT/IMAGE/SYSTEM',
  content     VARCHAR(2000) NOT NULL,
  read_status TINYINT       NOT NULL DEFAULT 0 COMMENT '0 未读 / 1 已读',
  created_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_group_time (group_id, created_at),
  KEY idx_receiver_time (receiver_id, created_at)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '消息，单聊与群聊共用';

-- ---------- 运营域 ----------

CREATE TABLE IF NOT EXISTS credit_log (
  id            BIGINT   NOT NULL AUTO_INCREMENT,
  user_id       BIGINT   NOT NULL,
  change_value  INT      NOT NULL COMMENT '正数为加，负数为减',
  reason        VARCHAR(100) NOT NULL,
  related_id    BIGINT   DEFAULT NULL COMMENT '关联活动或举报',
  operator_id   BIGINT   DEFAULT NULL COMMENT '管理端调整时非空',
  balance_after INT      NOT NULL COMMENT '变动后余额',
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_user_time (user_id, created_at)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '信用分流水，只追加不修改';

CREATE TABLE IF NOT EXISTS report (
  id            BIGINT       NOT NULL AUTO_INCREMENT,
  reporter_id   BIGINT       NOT NULL,
  target_type   VARCHAR(16)  NOT NULL COMMENT 'ACTIVITY/USER/MESSAGE',
  target_id     BIGINT       NOT NULL,
  reason        VARCHAR(200) NOT NULL,
  evidence      VARCHAR(500) DEFAULT NULL COMMENT '图片 URL，逗号分隔',
  status        VARCHAR(16)  NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING/APPROVED/REJECTED',
  handler_id    BIGINT       DEFAULT NULL,
  handle_result VARCHAR(200) DEFAULT NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_status (status),
  KEY idx_target (target_type, target_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '举报';
