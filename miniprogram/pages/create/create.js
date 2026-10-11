const api = require('../../utils/api');

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

function pad2(v) {
  return String(v).padStart(2, '0');
}

function fmtPick(d) {
  if (!d) return '选择时间';
  return `${d.getMonth() + 1}月${d.getDate()}日 ${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

Page({
  data: {
    categories: CATEGORIES,
    tagPool: TAG_POOL,
    venueIndex: 0,
    venueNames: VENUES.map((v) => `${v.name} · ${v.address}`),
    title: '',
    address: '',
    desc: '',
    category: CATEGORIES[0],
    tags: [],
    maxParticipants: 6,
    creditRequired: 60,
    startText: '选择时间',
    endText: '选择时间',
    submitting: false,
  },

  start: null,
  end: null,

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

  pickStart() {
    this.pick(true);
  },
  pickEnd() {
    this.pick(false);
  },
  pick(isStart) {
    const base = (isStart ? this.start : this.end) || new Date(Date.now() + (isStart ? 3600000 : 10800000));
    wx.showModal({
      title: isStart ? '开始时间' : '结束时间',
      editable: true,
      placeholderText: '格式：10月17日 14:00（留空用默认值）',
      success: (res) => {
        if (!res.confirm) return;
        // 小程序的日期/时间选择要弹两次，这里用一次可编辑输入框减少打断；
        // 解析失败回落到默认时间。
        const m = (res.content || '').match(/(\d{1,2})月(\d{1,2})日\s*(\d{1,2}):(\d{2})/);
        let d;
        if (m) {
          d = new Date(new Date().getFullYear(), Number(m[1]) - 1, Number(m[2]), Number(m[3]), Number(m[4]));
        } else {
          d = base;
        }
        if (Number.isNaN(d.getTime())) d = base;
        if (isStart) {
          this.start = d;
          if (!this.end || this.end <= d) this.end = new Date(d.getTime() + 7200000);
        } else {
          this.end = d;
        }
        this.setData({ startText: fmtPick(this.start), endText: fmtPick(this.end) });
      },
    });
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
      await api.post('/api/activity', {
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
        tags: this.data.tags,
      });
      wx.showToast({ title: '活动已发布，群聊也已建好', icon: 'none' });
      setTimeout(() => wx.navigateBack(), 900);
    } catch (e) {
      wx.showToast({ title: e.message, icon: 'none' });
      this.setData({ submitting: false });
    }
  },

  /** 本地时间 → ISO（不带时区后缀，与后端 LocalDateTime 解析约定一致） */
  toIso(d) {
    return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}T${pad2(d.getHours())}:${pad2(d.getMinutes())}:00`;
  },
});
