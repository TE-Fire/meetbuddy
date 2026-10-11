/**
 * 地图插画：天空底 + 草地形 + 蓝色虚线路线 + 白色图钉 + 贴纸。
 * 整套设计的记忆点，与 Flutter 端 MapScene 同源。
 */
Component({
  options: { addGlobalClass: true },
  properties: {
    /** 左上角黑标签文案，空串不显示 */
    badge: { type: String, value: '' },
    badgeColor: { type: String, value: '#171A1D' },
    /** 图钉：[{text, x, y, accent}]，x/y 为 0~1 相对比例 */
    pins: { type: Array, value: [] },
    /** 贴纸 emoji */
    sticker: { type: String, value: '' },
    sticker2: { type: String, value: '' },
    /** 是否画虚线路线 */
    route: { type: Boolean, value: true },
    height: { type: Number, value: 240 },
    radius: { type: Number, value: 40 },
  },
});
