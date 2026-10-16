// 分享海报：canvas 2d 绘制 + 存相册。规则与坐标约定见 docs/07-分享海报.md。
const api = require('../../utils/api');
const fmt = require('../../utils/format');

// —— 设计坐标（单位 px）——
// W / H 是画布位图尺寸（见 initCanvas：canvas.width = W * dpr），ctx.scale(dpr, dpr) 之后
// 下面所有数字都能直接当绘制坐标用，不做任何换算。显示尺寸另算（onLoad 里的 stageW/stageH），
// 两者分离——改成 rpx 会让换行点与裁切位置随机型漂移。
const W = 750;
const H = 1240;
const PAD = 56;
const COVER_H = 520;
const CARD_TOP = 460; // 白卡从封面里压上来，形成叠边
const CARD_RADIUS = 48;
const FOOT_BLOCK = 132;
const FOOT_BOTTOM = 50;
const FOOT_TOP = H - FOOT_BOTTOM - FOOT_BLOCK; // 1058
const DIVIDER_Y = 1038;

const FONT = '"PingFang SC", "HarmonyOS Sans SC", "Helvetica Neue", Arial, sans-serif';
const CATEGORY_ICONS = { 剧本杀: '🎭', 运动: '🏸', 探店: '🍜', 桌游: '🎲', 户外: '⛰️', 观影: '🎬', 其他: '✨' };
const INK = '#182028';
const INK2 = '#3C4A56';
const MUTED = '#93A1AD';
const BRAND = '#189BE0';
const BLACK = '#171A1D';

// ============ 绘制助手 ============

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

/** 只有上面两个角是圆角：白卡压在封面上时用，底边要贴到画布底 */
function roundTopPath(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x, y + h);
  ctx.lineTo(x, y + r);
  ctx.arcTo(x, y, x + r, y, r);
  ctx.lineTo(x + w - r, y);
  ctx.arcTo(x + w, y, x + w, y + r, r);
  ctx.lineTo(x + w, y + h);
  ctx.closePath();
}

/** 单行截断，超宽补省略号 */
function ellipsize(ctx, text, maxWidth) {
  let s = String(text == null ? '' : text);
  if (ctx.measureText(s).width <= maxWidth) return s;
  while (s.length && ctx.measureText(s + '…').width > maxWidth) s = s.slice(0, -1);
  return s + '…';
}

/** 按最大宽度折行（逐字累加测量，中文场景够用） */
function wrapLines(ctx, text, maxWidth) {
  const s = String(text == null ? '' : text);
  const lines = [];
  let cur = '';
  for (let i = 0; i < s.length; i++) {
    const ch = s[i];
    if (cur && ctx.measureText(cur + ch).width > maxWidth) {
      lines.push(cur);
      cur = ch;
    } else {
      cur += ch;
    }
  }
  if (cur) lines.push(cur);
  return lines;
}

/** 取前 maxLines 行，末行超长补省略号 */
function clampLines(ctx, text, maxWidth, maxLines) {
  const lines = wrapLines(ctx, text, maxWidth);
  if (lines.length <= maxLines) return lines;
  const out = lines.slice(0, maxLines);
  let last = out[maxLines - 1];
  while (last.length && ctx.measureText(last + '…').width > maxWidth) last = last.slice(0, -1);
  out[maxLines - 1] = last + '…';
  return out;
}

/** 胶囊 chip，返回占用宽度（含内边距），方便横向累加排布 */
function chip(ctx, text, x, y, bg, fg, fontSize) {
  const h = 52;
  ctx.font = `bold ${fontSize}px ${FONT}`;
  const w = ctx.measureText(text).width + 40;
  roundRect(ctx, x, y, w, h, h / 2);
  ctx.fillStyle = bg;
  ctx.fill();
  ctx.save();
  ctx.fillStyle = fg;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(text, x + w / 2, y + h / 2 + 1);
  ctx.restore();
  return w;
}

/** 封面图按 aspectFill 居中裁切铺满封面区（等价 <image mode="aspectFill">） */
function drawCoverImage(ctx, img, w, h) {
  const ir = img.width / img.height;
  const br = w / h;
  let sx = 0;
  let sy = 0;
  let sw = img.width;
  let sh = img.height;
  if (ir > br) {
    sw = img.height * br;
    sx = (img.width - sw) / 2;
  } else {
    sh = img.width / br;
    sy = (img.height - sh) / 2;
  }
  ctx.drawImage(img, sx, sy, sw, sh, 0, 0, w, h);
}

Page({
  data: {
    a: null,
    ready: false,
    error: '',
    saving: false,
    stageW: 0,
    stageH: 0,
  },

  onLoad(options) {
    this.id = Number(options.id);
    const win = wx.getWindowInfo ? wx.getWindowInfo() : wx.getSystemInfoSync();
    this.dpr = win.pixelRatio || 2;
    // 预览尺寸：左右各留 32px，同时给标题/提示/按钮留出约 260px，两者取小保证一屏放得下。
    // ⚠ 只改 canvas 的 CSS 盒子（显示尺寸），位图尺寸仍是 750×1240 × dpr，导出分辨率不受影响。
    const byWidth = (win.windowWidth - 64) / W;
    const byHeight = ((win.windowHeight || win.windowWidth * 2) - 260) / H;
    const scale = Math.max(0.2, Math.min(byWidth, byHeight));
    this.setData({
      stageW: Math.round(W * scale),
      stageH: Math.round(H * scale),
    });
  },

  onReady() {
    this.load();
  },

  async load() {
    this.setData({ error: '', ready: false });
    try {
      const raw = await api.get(`/api/activity/${this.id}`);
      this.setData({ a: this.decorate(raw) });
      // canvas 在 wx:if 通过之后才存在，必须等这次渲染落地再取节点
      this.setData({ ready: true }, () => this.initCanvas());
    } catch (e) {
      this.setData({ error: e.message });
    }
  },

  /** 绘制要用的字段一次性算好，render 里不再做判断 */
  decorate(a) {
    const start = fmt.fmtTime(a.startTime);
    const end = fmt.fmtHm(a.endTime);
    const slotsLeft = Math.max(0, (a.maxParticipants || 0) - (a.currentParticipants || 0));
    return {
      title: a.title || '未命名活动',
      statusText: fmt.statusLabel(a.status),
      category: a.category || '其他',
      icon: CATEGORY_ICONS[a.category] || '✨',
      timeText: a.endTime ? `${start} — ${end}` : start,
      addrText: fmt.shortAddr(a.address) || '地点见群内通知',
      slotsText: `${a.currentParticipants || 0}/${a.maxParticipants || 0}${slotsLeft > 0 ? ` · 还剩 ${slotsLeft} 个名额` : ' · 已满'}`,
      creditRequired: a.creditRequired || 0,
      organizerFirst: a.organizerNickname ? a.organizerNickname[0] : '?',
      organizerNickname: a.organizerNickname || '匿名用户',
      coverUrl: fmt.imgUrl(a.coverUrl),
    };
  },

  initCanvas() {
    this.createSelectorQuery()
      .select('#poster')
      .fields({ node: true, size: true })
      .exec(async (res) => {
        const item = res && res[0];
        if (!item || !item.node) {
          this.setData({ error: '画布初始化失败，请退出重进' });
          return;
        }
        const canvas = item.node;
        const ctx = canvas.getContext('2d');
        // backing store 按 dpr 放大 → 导出即 750×1240 × dpr，任何机型都清晰
        canvas.width = W * this.dpr;
        canvas.height = H * this.dpr;
        ctx.scale(this.dpr, this.dpr);
        this.canvas = canvas;
        this.ctx = ctx;

        // 第一趟：无封面也能出完整海报（封面区用品牌渐变兜底），此时已可保存
        this.render();
        // 第二趟：封面图到位后整张重绘；图挂了就不重绘，留着渐变版
        const img = await this.loadCover(canvas, this.data.a.coverUrl);
        if (img) {
          this.coverImg = img;
          this.render();
        }
      });
  },

  /** 4s 未回就放弃，避免海报一直卡着不出来 */
  loadCover(canvas, url) {
    return new Promise((resolve) => {
      if (!url) {
        resolve(null);
        return;
      }
      let settled = false;
      const finish = (v) => {
        if (!settled) {
          settled = true;
          resolve(v);
        }
      };
      setTimeout(() => finish(null), 4000);

      const draw = (src) => {
        const img = canvas.createImage();
        img.onload = () => finish(img);
        img.onerror = () => finish(null);
        img.src = src;
      };

      // 包内资源（/images/…）直接给 canvas；网络图先落地成本地文件再画，兼容性更好
      if (url.charAt(0) === '/') {
        draw(url);
        return;
      }
      wx.getImageInfo({
        src: url,
        success: (info) => draw(info.path),
        fail: () => finish(null),
      });
    });
  },

  render() {
    const ctx = this.ctx;
    const a = this.data.a;
    if (!ctx || !a) return;
    ctx.clearRect(0, 0, W, H);
    this.drawCover(ctx, a);
    this.drawCard(ctx, a);
  },

  /** 封面区：图或渐变兜底 + 状态角标 */
  drawCover(ctx, d) {
    if (this.coverImg) {
      drawCoverImage(ctx, this.coverImg, W, COVER_H);
    } else {
      const g = ctx.createLinearGradient(0, 0, W, COVER_H);
      g.addColorStop(0, '#DDF0FC');
      g.addColorStop(0.55, '#CFEAFB');
      g.addColorStop(1, '#EFF9E8');
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, W, COVER_H);
      ctx.fillStyle = 'rgba(196, 236, 166, 0.55)';
      ctx.beginPath();
      ctx.arc(W - 70, 60, 150, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = 'rgba(56, 178, 242, 0.14)';
      ctx.beginPath();
      ctx.arc(80, COVER_H - 20, 160, 0, Math.PI * 2);
      ctx.fill();
      ctx.save();
      ctx.font = `120px ${FONT}`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(d.icon, W / 2, COVER_H / 2 + 4);
      ctx.restore();
    }
    chip(ctx, d.statusText, PAD, 44, BLACK, '#FFFFFF', 26);
  },

  /** 白卡：标题 / 标签 / 信息三行 / 组织者 / 分隔线 / 品牌区 */
  drawCard(ctx, d) {
    ctx.save();
    ctx.shadowColor = 'rgba(31, 102, 150, 0.18)';
    ctx.shadowBlur = 28;
    ctx.shadowOffsetY = -6;
    ctx.fillStyle = '#FFFFFF';
    roundTopPath(ctx, 0, CARD_TOP, W, H - CARD_TOP, CARD_RADIUS);
    ctx.fill();
    ctx.restore();

    const innerW = W - PAD * 2;

    // 标题：最多两行，超出以省略号收尾
    ctx.fillStyle = INK;
    ctx.font = `bold 54px ${FONT}`;
    const titleLines = clampLines(ctx, d.title, innerW, 2);
    const titleBase = CARD_TOP + 110;
    titleLines.forEach((ln, i) => ctx.fillText(ln, PAD, titleBase + i * 68));
    const titleBottom = titleBase + (titleLines.length - 1) * 68 + 16;

    // 标签行
    const chipY = titleBottom + 22;
    let cx = PAD;
    cx += chip(ctx, d.category, cx, chipY, '#EFF9E8', '#4E8F3C', 26) + 16;
    cx += chip(ctx, d.statusText, cx, chipY, '#E1F4FE', BRAND, 26) + 16;
    if (d.creditRequired > 0) {
      chip(ctx, `信用分 ≥ ${d.creditRequired}`, cx, chipY, '#F1F5F8', INK2, 26);
    }

    // 信息三行：标签占固定 96，值占余下宽度并截断
    const rows = [
      ['时间', d.timeText],
      ['地点', d.addrText],
      ['名额', d.slotsText],
    ];
    const rowBase = chipY + 114;
    rows.forEach(([label, value], i) => {
      const baseline = rowBase + i * 60;
      ctx.font = `bold 30px ${FONT}`;
      ctx.fillStyle = BRAND;
      ctx.fillText(label, PAD, baseline);
      ctx.font = `30px ${FONT}`;
      ctx.fillStyle = INK2;
      ctx.fillText(ellipsize(ctx, value, innerW - 96), PAD + 96, baseline);
    });

    // 组织者行（固定 y，标题一行/两行都不位移，版式稳定）
    const oy = 950;
    const g = ctx.createLinearGradient(PAD, oy, PAD + 64, oy + 64);
    g.addColorStop(0, '#59BCF5');
    g.addColorStop(1, '#189BE0');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(PAD + 32, oy + 32, 32, 0, Math.PI * 2);
    ctx.fill();
    ctx.save();
    ctx.fillStyle = '#FFFFFF';
    ctx.font = `bold 28px ${FONT}`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(d.organizerFirst, PAD + 32, oy + 33);
    ctx.restore();

    ctx.fillStyle = INK;
    ctx.font = `bold 30px ${FONT}`;
    ctx.fillText(ellipsize(ctx, d.organizerNickname, 400), PAD + 88, oy + 30);
    ctx.fillStyle = MUTED;
    ctx.font = `24px ${FONT}`;
    ctx.fillText('发起人', PAD + 88, oy + 62);

    // 虚线分隔
    ctx.save();
    ctx.strokeStyle = '#E4EEF6';
    ctx.lineWidth = 1;
    ctx.setLineDash([8, 8]);
    ctx.beginPath();
    ctx.moveTo(PAD, DIVIDER_Y);
    ctx.lineTo(W - PAD, DIVIDER_Y);
    ctx.stroke();
    ctx.restore();

    this.drawFooter(ctx);
  },

  /**
   * 底部：左品牌文案 + 右引导块。
   * 微信小程序码要正式 AppID + AppSecret 才能生成（本项目本地都没有），所以这里不画码，
   * 画的是纯文字引导块，不暗示"可扫"。升级路径见 docs/07-分享海报.md 第五节。
   */
  drawFooter(ctx) {
    ctx.fillStyle = INK;
    ctx.font = `bold 36px ${FONT}`;
    ctx.fillText('搭子', PAD, FOOT_TOP + 46);
    ctx.fillStyle = MUTED;
    ctx.font = `22px ${FONT}`;
    ctx.fillText('找个搭子，一起把想做的事做了', PAD, FOOT_TOP + 80);

    const bx = W - PAD - FOOT_BLOCK;
    const by = FOOT_TOP;
    roundRect(ctx, bx, by, FOOT_BLOCK, FOOT_BLOCK, 28);
    ctx.fillStyle = BLACK;
    ctx.fill();

    ctx.save();
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = '#8FA3B2';
    ctx.font = `18px ${FONT}`;
    ctx.fillText('微信小程序', bx + FOOT_BLOCK / 2, by + 52);
    ctx.fillStyle = '#FFFFFF';
    ctx.font = `bold 21px ${FONT}`;
    ctx.fillText('搜「搭子」', bx + FOOT_BLOCK / 2, by + 86);
    ctx.restore();
  },

  save() {
    if (this.data.saving || !this.canvas) return;
    this.setData({ saving: true });
    // 取景区（x/y/width/height）全部省略 = 整幅画布，不裁剪；
    // ⚠ 但 destWidth/destHeight 必须显式给：它的默认值是「CSS 尺寸 × dpr」，而预览盒比设计
    // 尺寸小（750px 缩到屏宽内），照默认走会导出一张小得多的图。这里按位图尺寸给，
    // 且上限压到 4096（微信临时图片文件的宽度限制，dpr=4 的机型会超）。
    const factor = Math.min(this.dpr, 4096 / H);
    wx.canvasToTempFilePath(
      {
        canvas: this.canvas,
        fileType: 'png',
        quality: 1,
        destWidth: Math.round(W * factor),
        destHeight: Math.round(H * factor),
        success: (res) => this.saveToAlbum(res.tempFilePath),
        fail: () => {
          this.setData({ saving: false });
          wx.showToast({ title: '生成图片失败，请重试', icon: 'none' });
        },
      },
      this,
    );
  },

  saveToAlbum(filePath) {
    const done = () => this.setData({ saving: false });
    wx.saveImageToPhotosAlbum({
      filePath,
      success: () => {
        done();
        wx.showToast({ title: '已存到相册', icon: 'success' });
      },
      fail: (err) => {
        done();
        const msg = String((err && err.errMsg) || '');
        // 拒绝授权 → 给可操作的引导；自己取消 → 不打扰；其余 → 提示重试
        if (msg.indexOf('auth') >= 0) {
          wx.showModal({
            title: '需要相册权限',
            content: '保存图片要授权「保存到相册」，可在设置里打开。',
            confirmText: '去设置',
            success: (r) => {
              if (r.confirm) wx.openSetting({});
            },
          });
          return;
        }
        if (msg.indexOf('cancel') >= 0) return;
        wx.showToast({ title: '保存失败，请重试', icon: 'none' });
      },
    });
  },
});
