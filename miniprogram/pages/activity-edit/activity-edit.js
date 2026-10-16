const api = require('../../utils/api');
const fmt = require('../../utils/format');

const CATEGORIES = ['剧本杀', '运动', '探店', '桌游', '户外', '观影', '其他'];
const TAG_POOL = ['新手友好', '硬核', '深夜局', 'AA制', '免费', '带装备', '轻运动', '拍照'];

// 地标决定经纬度，与 Flutter 端 _venues 同一份清单。
const VENUES = [
  { name: '国贸商城', address: '朝阳区建国门外大街 1 号', lng: 116.461, lat: 39.9088 },
  { name: '三里屯太古里', address: '朝阳区三里屯路 19 号', lng: 116.455, lat: 39.933 },
  { name: '奥林匹克森林公园', address: '朝阳区科荟路 33 号', lng: 116.392, lat: 40.02 },
  { name: '五道口购物中心', address: '海淀区成府路 28 号', lng: 116.337, lat: 39.993 },
  { name: '南锣鼓巷', address: '东城区南锣鼓巷', lng: 116.404, lat: 39.937 },
  { name: '常营体育公园', address: '朝阳区常营北路', lng: 116.59, lat: 39.925 },
];

// 时间轴：一天 0~1440 分钟，30 分钟一档。
const TOTAL = 1440;
const STEP = 30;
const WEEK = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
const DATE_LABEL = ['今天', '明天', '后天', '大后天'];

function pad2(v) {
  return String(v).padStart(2, '0');
}
function minsToTxt(m) {
  return `${pad2(Math.floor(m / 60))}:${pad2(m % 60)}`;
}
function weekdayOf(d) {
  return WEEK[d.getDay()];
}
function fmtPick(d) {
  if (!d) return '选择时间';
  return `${d.getMonth() + 1}月${d.getDate()}日 ${weekdayOf(d)} ${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}
// 把分钟数对齐到 STEP 的整数倍
function snap(m) {
  return Math.round(m / STEP) * STEP;
}
// 当天 0 点
function midnight(offsetDays) {
  const d = new Date();
  d.setDate(d.getDate() + offsetDays);
  d.setHours(0, 0, 0, 0);
  return d;
}

Page({
  data: {
    id: 0,
    categories: CATEGORIES,
    tagPool: TAG_POOL,
    venueIndex: 0,
    venueNames: VENUES.map((v) => `${v.name} · ${v.address}`),
    title: '',
    address: '',
    desc: '',
    category: CATEGORIES[0],
    tags: [],
    images: [],
    uploading: false,
    maxParticipants: 6,
    minParticipants: 1, // 编辑时抬到已报名人数，避免改小把人踢出去
    creditRequired: 60,
    startText: '选择时间',
    endText: '选择时间',
    timeDur: '',

    // —— 时间滑动面板 ——
    showTime: false,
    rsDates: [],
    rsDateIdx: 0,
    rsStart: 14 * 60, // 默认 14:00
    rsEnd: 17 * 60, // 默认 17:00
    rsStartPct: 0,
    rsEndPct: 0,
    rsStartTxt: '',
    rsEndTxt: '',
    rsStartTag: '',
    rsEndTag: '',
    rsDur: '',
  },

  start: null,
  end: null,
  activeHandle: null,
  trackLeft: 0,
  trackWidth: 0,
  // 编辑模式下，活动真实日历日期（可能与 4 天窗口不符），confirm 用它拼时间，避免日期被截断
  _baseDate: null,

  onLoad(options) {
    this.id = Number(options.id);
    const rsDates = [];
    for (let i = 0; i < 4; i++) {
      const d = midnight(i);
      rsDates.push({ label: DATE_LABEL[i], sub: `${d.getMonth() + 1}/${d.getDate()}` });
    }
    this.setData({ id: this.id, rsDates });
    this.loadDetail();
  },

  async loadDetail() {
    this.setData({ loading: true, error: '' });
    try {
      const d = await api.get(`/api/activity/${this.id}`);
      // —— 分类 ——
      const category = CATEGORIES.includes(d.category) ? d.category : CATEGORIES[0];
      // —— 地点：地址形如 "国贸商城 · 详细地址"，按前缀拆回 venue ——
      let venueIndex = 0;
      let address = d.address || '';
      for (let i = 0; i < VENUES.length; i++) {
        const prefix = `${VENUES[i].name} · `;
        if (address.startsWith(prefix)) {
          venueIndex = i;
          address = address.slice(prefix.length);
          break;
        }
      }
      // —— 时间：真实日历日期存进 _baseDate ——
      const sd = new Date(d.startTime);
      const ed = new Date(d.endTime);
      this.start = sd;
      this.end = ed;
      this._baseDate = new Date(sd.getFullYear(), sd.getMonth(), sd.getDate());
      // —— 人数下限抬到已报名数 ——
      const minP = Math.max(1, d.currentParticipants || 0);
      this.setData({
        loading: false,
        title: d.title || '',
        desc: d.description || '',
        category,
        venueIndex,
        address,
        tags: d.tags || [],
        images: (d.images || []).map((u) => fmt.imgUrl(u)),
        maxParticipants: d.maxParticipants || 6,
        minParticipants: minP,
        creditRequired: d.creditRequired != null ? d.creditRequired : 60,
        startText: fmtPick(sd),
        endText: fmtPick(ed),
      });
      // timeDur 文案：start/end 已就绪后由面板逻辑补，这里直接算一次
      this.setData({ timeDur: this._durText(sd, ed) });
    } catch (e) {
      this.setData({ loading: false, error: e.message || '加载失败' });
    }
  },

  _durText(s, e) {
    if (!s || !e) return '';
    let m = Math.round((e.getTime() - s.getTime()) / 60000);
    if (m <= 0) m = 0;
    return m >= 60 ? `${Math.floor(m / 60)}小时${m % 60 ? ` ${m % 60}分` : ''}` : `${m}分钟`;
  },

  onTitle(e) {
    this.setData({ title: e.detail.value });
  },
  onAddress(e) {
    this.setData({ address: e.detail.value });
  },
  onDesc(e) {
    this.setData({ desc: e.detail.value });
  },
  onVenue(e) {
    this.setData({ venueIndex: Number(e.detail.value) });
  },
  pickCategory(e) {
    this.setData({ category: e.currentTarget.dataset.c });
  },
  toggleTag(e) {
    const t = e.currentTarget.dataset.t;
    const tags = this.data.tags.slice();
    const i = tags.indexOf(t);
    if (i >= 0) tags.splice(i, 1);
    else tags.push(t);
    this.setData({ tags });
  },
  onMax(e) {
    const { d, min, max } = e.currentTarget.dataset;
    const v = Math.min(Number(max), Math.max(Number(min), this.data.maxParticipants + Number(d)));
    this.setData({ maxParticipants: v });
  },
  onCredit(e) {
    const { d, min, max } = e.currentTarget.dataset;
    const v = Math.min(Number(max), Math.max(Number(min), this.data.creditRequired + Number(d)));
    this.setData({ creditRequired: v });
  },

  // ============ 时间滑动面板 ============
  openTime() {
    let idx = 0;
    let s = this.data.rsStart;
    let e = this.data.rsEnd;
    if (this.start) {
      // 从已选时间回填：取开始日相对今天的偏移，分钟数取时分。
      const today = midnight(0).getTime();
      idx = Math.min(3, Math.max(0, Math.floor((this.start.getTime() - today) / 86400000)));
      s = this.start.getHours() * 60 + this.start.getMinutes();
      e = this.end.getHours() * 60 + this.end.getMinutes();
      if (e <= s) e = Math.min(TOTAL, s + 120); // 不支持跨天，兜底
    }
    this.setData({ showTime: true, rsDateIdx: idx, rsStart: s, rsEnd: e }, () => {
      this._computeRs();
      this._queryTrack();
    });
  },
  closeTime() {
    this.setData({ showTime: false });
    this.activeHandle = null;
  },
  pickRsDate(e) {
    this.setData({ rsDateIdx: Number(e.currentTarget.dataset.i) }, () => this._computeRs());
  },
  _queryTrack() {
    this.createSelectorQuery()
      .select('.rs-track')
      .boundingClientRect((r) => {
        if (r) {
          this.trackLeft = r.left;
          this.trackWidth = r.width;
        }
      })
      .exec();
  },
  onRsDown(e) {
    this.activeHandle = e.currentTarget.dataset.h;
  },
  onRsEnd() {
    this.activeHandle = null;
  },
  onRsMove(e) {
    if (!this.activeHandle || !this.trackWidth) return;
    const x = e.touches[0].clientX - this.trackLeft;
    const ratio = Math.max(0, Math.min(1, x / this.trackWidth));
    const m = snap(ratio * TOTAL);
    if (this.activeHandle === 'start') {
      const ns = Math.min(m, this.data.rsEnd - STEP);
      this.setData({ rsStart: Math.max(0, ns) }, () => this._computeRs());
    } else {
      const ne = Math.max(m, this.data.rsStart + STEP);
      this.setData({ rsEnd: Math.min(TOTAL, ne) }, () => this._computeRs());
    }
  },
  _computeRs() {
    const s = this.data.rsStart;
    const e = this.data.rsEnd;
    const pct = (v) => Math.round((v / TOTAL) * 1000) / 10;
    const durMin = e - s;
    const dur =
      durMin >= 60
        ? `${Math.floor(durMin / 60)}小时${durMin % 60 ? ` ${durMin % 60}分` : ''}`
        : `${durMin}分钟`;
    // 编辑模式下用真实日历日期，避免 4 天窗口把远日期截断
    const day = this._baseDate || midnight(this.data.rsDateIdx);
    const dateStr = `${day.getMonth() + 1}月${day.getDate()}日 ${weekdayOf(day)}`;
    this.setData({
      rsStartPct: pct(s),
      rsEndPct: pct(e),
      rsStartTxt: `${dateStr} ${minsToTxt(s)}`,
      rsEndTxt: `${minsToTxt(e)}`,
      rsStartTag: minsToTxt(s),
      rsEndTag: minsToTxt(e),
      rsDur: dur,
    });
  },
  confirmTime() {
    // 编辑模式保留真实日期；新建模式用面板选的日期
    const base = this._baseDate || midnight(this.data.rsDateIdx);
    this.start = new Date(base.getTime() + this.data.rsStart * 60000);
    this.end = new Date(base.getTime() + this.data.rsEnd * 60000);
    this.setData({
      showTime: false,
      startText: fmtPick(this.start),
      endText: fmtPick(this.end),
      timeDur: this.data.rsDur,
    });
  },
  noop() {},

  // ============ 活动配图 ============
  async chooseImage() {
    const left = 9 - this.data.images.length;
    if (left <= 0 || this.data.uploading) return;
    let files = [];
    try {
      const res = await new Promise((resolve, reject) => {
        wx.chooseMedia({
          count: left,
          mediaType: ['image'],
          sizeType: ['compressed'],
          sourceType: ['album', 'camera'],
          success: resolve,
          fail: reject,
        });
      });
      files = (res.tempFiles || []).map((f) => f.tempFilePath);
    } catch (e) {
      return;
    }
    if (!files.length) return;
    this.setData({ uploading: true });
    const uploaded = [];
    try {
      for (const f of files) {
        uploaded.push(fmt.imgUrl(await api.upload(f)));
      }
    } catch (e) {
      wx.showToast({ title: e.message || '有图片上传失败', icon: 'none' });
    }
    this.setData({ images: this.data.images.concat(uploaded), uploading: false });
  },
  removeImage(e) {
    const i = Number(e.currentTarget.dataset.i);
    const images = this.data.images.slice();
    images.splice(i, 1);
    this.setData({ images });
  },

  async submit() {
    if (this.data.submitting) return;
    const title = this.data.title.trim();
    if (title.length < 2) {
      wx.showToast({ title: '至少写两个字', icon: 'none' });
      return;
    }
    if (!this.start || !this.end) {
      wx.showToast({ title: '先把时间选上', icon: 'none' });
      return;
    }
    if (this.end <= this.start) {
      wx.showToast({ title: '结束时间得晚于开始时间', icon: 'none' });
      return;
    }
    const venue = VENUES[this.data.venueIndex];
    const addressDetail = this.data.address.trim() || venue.address;
    this.setData({ submitting: true });
    try {
      await api.put(`/api/activity/${this.id}`, {
        title,
        category: this.data.category,
        description: this.data.desc.trim() || null,
        address: `${venue.name} · ${addressDetail}`,
        lng: venue.lng,
        lat: venue.lat,
        startTime: this.toIso(this.start),
        endTime: this.toIso(this.end),
        maxParticipants: this.data.maxParticipants,
        creditRequired: Math.round(this.data.creditRequired),
        coverUrl: this.data.images[0] || null,
        tags: this.data.tags,
        images: this.data.images,
      });
      wx.showToast({ title: '已保存修改', icon: 'none' });
      setTimeout(() => wx.navigateBack(), 900);
    } catch (e) {
      wx.showToast({ title: e.message, icon: 'none' });
      this.setData({ submitting: false });
    }
  },

  toIso(d) {
    return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}T${pad2(d.getHours())}:${pad2(d.getMinutes())}:00`;
  },
});
