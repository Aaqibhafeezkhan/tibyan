import router from '@system.router';
import vibrator from '@system.vibrator';
import configuration from '@system.configuration';
import * as data from '../../common/data.js';

// Counts in a row go to the phone together (1.5 s, as on Wear OS).
const SEND_DELAY = 1500;

export default {
  data: {
    stageText: '', label: '', countText: '', targetText: '',
    ringPercent: 0, sheet: false, resetLabel: '', wirdLabel: '',
  },
  timer: null,
  onInit() {
    this.resetLabel = this.$t('strings.tasbih_reset');
    this.wirdLabel = this.$t('strings.to_wird');
    data.load(() => this.show());
    data.listen(() => this.show());
  },
  onDestroy() {
    if (this.timer !== null) clearTimeout(this.timer);
    data.sendTotal();
    data.stopListening();
  },
  show() {
    const ar = (configuration.getLocale().language || '').indexOf('ar') === 0;
    const num = (n) => data.number(n, ar);
    const s = data.tasbih(data.session());
    this.ringPercent = s.target > 0 ? Math.round((s.count * 100) / s.target) : 0;
    this.stageText = s.stages > 1
      ? this.$t('strings.stage').replace('{i}', num(s.stage)).replace('{n}', num(s.stages)) : '';
    this.label = s.label || this.$t('strings.tasbih_title');
    this.countText = num(s.count);
    this.targetText = s.target > 0 ? this.$t('strings.of_target').replace('{n}', num(s.target)) : '';
  },
  tap() {
    if (this.sheet) { this.sheet = false; return; }
    const s = data.tasbih(data.count());
    // A round (or stage) done: a longer pulse.
    vibrator.vibrate({ mode: s.target > 0 && s.count === s.target ? 'long' : 'short' });
    this.show();
    if (this.timer !== null) clearTimeout(this.timer);
    this.timer = setTimeout(() => { this.timer = null; data.sendTotal(); }, SEND_DELAY);
  },
  openSheet() { this.sheet = true; },
  closeSheet() { this.sheet = false; },
  swipe(e) {
    if (e.direction === 'down') this.sheet = true;
  },
  reset() {
    data.reset();
    this.sheet = false;
    this.show();
  },
  toWird() {
    router.replace({ uri: 'pages/index/index' });
  },
};
