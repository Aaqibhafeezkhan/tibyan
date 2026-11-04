import router from '@system.router';
import configuration from '@system.configuration';
import * as data from '../../common/data.js';

export default {
  data: {
    hasData: false, title: '', surah: '', range: '', percentText: '',
    hint: '', empty: '', ringPercent: 0,
  },
  onInit() {
    data.load(() => this.show());
    data.listen(() => this.show());
  },
  onDestroy() { data.stopListening(); },
  show() {
    const ar = (configuration.getLocale().language || '').indexOf('ar') === 0;
    const num = (n) => data.number(n, ar);
    this.hasData = data.hasData();
    this.empty = this.$t('strings.open_phone');
    this.title = this.$t('strings.wird_title');
    this.hint = this.$t('strings.swipe_misbaha');
    const p = data.percent();
    this.ringPercent = this.hasData ? p : 0;
    this.percentText = ar ? num(p) + '٪' : p + '%';
    const w = data.wird();
    if (w === null) {
      this.surah = data.value('idle');
      this.range = '';
      return;
    }
    this.surah = w.surah || w.portion;
    if (w.from !== null && w.to !== null) {
      this.range = w.from === w.to
        ? this.$t('strings.page_one').replace('{from}', num(w.from))
        : this.$t('strings.page_range').replace('{from}', num(w.from)).replace('{to}', num(w.to));
    } else {
      this.range = '';
    }
  },
  swipe(e) {
    if (e.direction === 'up') router.replace({ uri: 'pages/misbaha/misbaha' });
  },
};
