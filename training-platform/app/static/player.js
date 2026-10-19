// Recording player + mistake marking (schema tibyan.mistakes/1).
// Needs vendor/wavesurfer/wavesurfer.min.js + regions.min.js (BSD-3, local).
(function () {
  'use strict';

  var TYPES = ['substitution', 'deletion', 'insertion', 'haraka', 'repetition', 'tajweed'];
  var SUBS = ['madd', 'ghunna', 'idgham', 'ikhfa', 'qalqala', 'other'];
  var COLORS = {
    substitution: '#C0392B', deletion: '#7D3C98', insertion: '#1F6FA8',
    haraka: '#B9770E', repetition: '#566573', tajweed: '#117A65'
  };
  var LETTER = /[ء-يٱ-ۓ]/;

  function $(sel, root) { return (root || document).querySelector(sel); }
  function el(tag, attrs, text) {
    var n = document.createElement(tag);
    if (attrs) Object.keys(attrs).forEach(function (k) {
      if (k === 'class') n.className = attrs[k];
      else if (k.indexOf('on') === 0) n.addEventListener(k.slice(2), attrs[k]);
      else n.setAttribute(k, attrs[k]);
    });
    if (text != null) n.textContent = text;
    return n;
  }
  function fmt(ms) {
    var s = Math.max(0, ms) / 1000;
    var m = Math.floor(s / 60);
    var r = (s - m * 60).toFixed(1);
    return m + ':' + (r.length < 4 ? '0' + r : r);
  }
  function csrf() {
    var m = $('meta[name="csrf-token"]');
    return m ? m.content : '';
  }
  function store(key, value) {
    try {
      if (value === null) localStorage.removeItem(key);
      else localStorage.setItem(key, JSON.stringify(value));
    } catch (e) { /* storage blocked: draft backup is optional */ }
  }

  // Mirror pointer X inside a horizontally flipped element so wavesurfer's
  // own seeking / region dragging works on an RTL (right-to-left) timeline.
  function mirrorPointer(host) {
    var active = false;
    ['pointerdown', 'pointermove', 'pointerup', 'pointercancel', 'click', 'dblclick'].forEach(function (type) {
      window.addEventListener(type, function (e) {
        if (e.__mirrored) return;
        var inside = host.contains(e.target);
        if (type === 'pointerdown' && inside) active = true;
        if (!inside && !active) return;
        if ((type === 'click' || type === 'dblclick') && !inside) return;
        var r = host.getBoundingClientRect();
        var init = {
          bubbles: true, cancelable: true, composed: true,
          clientX: r.left + r.right - e.clientX, clientY: e.clientY,
          screenX: e.screenX, screenY: e.screenY, button: e.button, buttons: e.buttons,
          pointerId: e.pointerId, pointerType: e.pointerType, isPrimary: e.isPrimary
        };
        var target = (e.composedPath && e.composedPath()[0]) || e.target;
        e.stopImmediatePropagation();
        var copy = type.indexOf('pointer') === 0 ? new PointerEvent(type, init) : new MouseEvent(type, init);
        copy.__mirrored = true;
        target.dispatchEvent(copy);
        if (type === 'pointerup' || type === 'pointercancel') active = false;
      }, true);
    });
  }

  function Player(root, data) {
    this.root = root;
    this.d = data;
    this.T = data.i18n;
    this.rtl = document.documentElement.dir === 'rtl';
    this.role = data.role;            // reciter | reviewer | admin | null
    // An admin is never the owner here (owners save as reciter), so an
    // admin edits like a reviewer: confirm / change / not a mistake / add.
    this.reviewer = data.role === 'reviewer' || data.role === 'admin';
    this.mode = data.role ? (root.dataset.startMode || 'listen') : 'listen';
    this.marks = (data.mistakes || []).map(function (m, i) { return Object.assign({ _id: i + 1 }, m); });
    this.nextId = this.marks.length + 1;
    this.words = data.words;
    this.timing = data.timing.words;
    this.base = data.base_version;
    this.dirty = false;
    this.sel = null;       // selected mark _id
    this.edit = null;      // draft being edited
    this.loop = null;
    this.durMs = data.duration_ms;
    this.build();
  }

  Player.prototype.t = function (k) { return this.T[k] || k; };

  Player.prototype.build = function () {
    var self = this, R = this.root;
    this.waveEl = $('.wave', R);
    this.curEl = $('.pl-cur', R);
    this.wordsEl = $('.words', R);
    this.listEl = $('.ml', R);
    this.cntEl = $('.pl-count', R);
    this.msgEl = $('.saved', R);
    this.editor = $('.editor', R);
    this.saveBtn = $('.pl-save', R);
    this.dlBtn = $('.pl-download', R);
    this.playBtn = $('.ic.play', R);

    R.querySelectorAll('[data-mode]').forEach(function (b) {
      b.addEventListener('click', function () { self.setMode(b.dataset.mode); });
    });
    R.querySelectorAll('[data-rate]').forEach(function (b) {
      b.addEventListener('click', function () {
        self.ws && self.ws.setPlaybackRate(+b.dataset.rate);
        R.querySelectorAll('[data-rate]').forEach(function (x) { x.setAttribute('aria-pressed', String(x === b)); });
      });
    });
    $('.pl-back', R).addEventListener('click', function () { self.skip(-5); });
    $('.pl-fwd', R).addEventListener('click', function () { self.skip(5); });
    this.playBtn.addEventListener('click', function () { self.toggle(); });
    var loopBtn = $('.pl-loop', R);
    if (loopBtn) loopBtn.addEventListener('click', function () { self.toggleLoop(); });
    var markBtn = $('.pl-mark', R);
    if (markBtn) markBtn.addEventListener('click', function () { self.markAtPlayhead(); });
    if (this.saveBtn) this.saveBtn.addEventListener('click', function () { self.save(); });
    $('.pl-retry', R) && $('.pl-retry', R).addEventListener('click', function () { self.loadWave(); });
    this.buildEditor();
    this.setMode(this.mode);
    this.renderWords();
    this.renderList();
    this.loadWave();
    document.addEventListener('keydown', function (e) { self.key(e); });
    window.addEventListener('beforeunload', function (e) {
      if (self.dirty) { e.preventDefault(); e.returnValue = ''; }
    });
  };

  // ------------------------------------------------------------- waveform
  Player.prototype.loadWave = function () {
    var self = this, R = this.root;
    $('.pl-loading', R).hidden = false;
    $('.pl-error', R).hidden = true;
    fetch(this.d.peaks, { credentials: 'same-origin' })
      .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
      .then(function (p) { self.createWave(p.peaks); })
      .catch(function () {
        $('.pl-loading', R).hidden = true;
        $('.pl-error', R).hidden = false;
      });
  };

  Player.prototype.createWave = function (peaks) {
    var self = this, R = this.root;
    if (this.ws) this.ws.destroy();
    var css = getComputedStyle(document.documentElement);
    this.regions = WaveSurfer.Regions.create();
    this.ws = WaveSurfer.create({
      container: this.waveEl,
      height: window.matchMedia('(max-width: 640px)').matches ? 84 : 110,
      waveColor: (css.getPropertyValue('--gold').trim() || '#B0855A') + '99',
      progressColor: css.getPropertyValue('--bronze').trim() || '#7A4A26',
      cursorColor: css.getPropertyValue('--brown').trim() || '#3A2B20',
      cursorWidth: 2,
      barWidth: 2, barGap: 1, barRadius: 2,
      url: this.d.audio,
      peaks: [peaks],
      duration: this.durMs / 1000,
      dragToSeek: true,
      plugins: [this.regions]
    });
    if (this.rtl) {
      this.waveEl.classList.add('flip');
      if (!this.mirrored) { mirrorPointer(this.waveEl); this.mirrored = true; }
    }
    this.ws.on('ready', function () {
      $('.pl-loading', R).hidden = true;
      self.drawRegions();
    });
    this.ws.on('error', function () {
      $('.pl-loading', R).hidden = true;
      $('.pl-error', R).hidden = false;
    });
    this.ws.on('timeupdate', function (t) { self.tick(t * 1000); });
    this.ws.on('play', function () { self.setPlayIcon(true); });
    this.ws.on('pause', function () { self.setPlayIcon(false); });
    this.ws.on('finish', function () { self.setPlayIcon(false); });
    this.regions.on('region-updated', function (reg) {
      if (reg.id === 'loop') { self.loop = [reg.start, reg.end]; return; }
      var m = self.find(+reg.id);
      if (!m) return;
      m.start_ms = Math.round(reg.start * 1000);
      m.end_ms = Math.round(reg.end * 1000);
      if (m.marked_by === 'reciter' && self.reviewer) m.review = 'changed';
      self.touch();
      self.renderList();
      self.syncEditorTime(m);
    });
    this.regions.on('region-clicked', function (reg, e) {
      e.stopPropagation();
      if (reg.id === 'loop') return;
      self.select(+reg.id, true);
    });
    this.regions.on('region-out', function (reg) {
      if (reg.id === 'loop' && self.loop && self.ws.isPlaying()) reg.play();
    });
    // Keyboard on the waveform itself (role=slider).
    this.waveEl.setAttribute('aria-valuemax', (this.durMs / 1000).toFixed(1));
  };

  Player.prototype.drawRegions = function () {
    if (!this.regions || !this.ws) return;
    var self = this, editable = this.mode === 'mark';
    this.regions.clearRegions();
    this.marks.forEach(function (m) {
      if (m.review === 'not_mistake') return;
      self.regions.addRegion({
        id: String(m._id), start: m.start_ms / 1000, end: m.end_ms / 1000,
        color: COLORS[m.type] + (self.sel === m._id ? '77' : '44'),
        drag: editable, resize: editable
      });
    });
    if (this.loop) {
      this.regions.addRegion({ id: 'loop', start: this.loop[0], end: this.loop[1], color: 'rgba(58,43,32,.12)', drag: true, resize: true });
    }
  };

  Player.prototype.setPlayIcon = function (playing) {
    this.playBtn.innerHTML = playing
      ? '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 5h4v14H6zM14 5h4v14h-4z"/></svg>'
      : '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M8 5v14l11-7z"/></svg>';
    this.playBtn.setAttribute('aria-label', this.t(playing ? 'pl_pause' : 'pl_play'));
  };

  Player.prototype.toggle = function () { if (this.ws) this.ws.playPause(); };
  Player.prototype.now = function () { return this.ws ? this.ws.getCurrentTime() * 1000 : 0; };
  Player.prototype.seekMs = function (ms) {
    if (!this.ws) return;
    this.ws.setTime(Math.max(0, Math.min(this.durMs, ms)) / 1000);
    this.tick(this.now());
  };
  Player.prototype.skip = function (sec) { this.seekMs(this.now() + sec * 1000); };

  Player.prototype.tick = function (ms) {
    this.curEl.textContent = fmt(ms);
    this.waveEl.setAttribute('aria-valuenow', (ms / 1000).toFixed(1));
    this.waveEl.setAttribute('aria-valuetext', fmt(ms));
    var idx = this.wordAt(ms);
    if (idx !== this.nowIdx) {
      var prev = this.wordsEl.querySelector('.chip.now');
      if (prev) prev.classList.remove('now');
      var c = this.wordsEl.querySelector('.chip[data-i="' + idx + '"]');
      if (c) c.classList.add('now');
      this.nowIdx = idx;
    }
  };

  Player.prototype.wordAt = function (ms) {
    for (var i = 0; i < this.timing.length; i++) {
      if (ms < this.timing[i].end_ms) return i;
    }
    return this.timing.length - 1;
  };

  Player.prototype.toggleLoop = function () {
    var b = $('.pl-loop', this.root);
    if (this.loop) { this.loop = null; }
    else {
      var t = this.now() / 1000, d = this.durMs / 1000;
      this.loop = [Math.max(0, t - 1), Math.min(d, t + 3)];
    }
    b.setAttribute('aria-pressed', String(!!this.loop));
    this.drawRegions();
  };

  // ---------------------------------------------------------------- words
  Player.prototype.setMode = function (mode) {
    if (!this.role) mode = 'listen';
    this.mode = mode;
    this.root.classList.toggle('mark-off', mode !== 'mark');
    this.root.querySelectorAll('[data-mode]').forEach(function (b) {
      b.setAttribute('aria-pressed', String(b.dataset.mode === mode));
    });
    this.root.querySelectorAll('.mark-only').forEach(function (n) { n.hidden = mode !== 'mark'; });
    if (mode !== 'mark') this.closeEditor();
    this.drawRegions();
  };

  Player.prototype.markOn = function (i, insertion) {
    return this.marks.filter(function (m) {
      return m.word_index === i && (m.type === 'insertion') === !!insertion && m.review !== 'not_mistake';
    })[0];
  };

  Player.prototype.renderWords = function () {
    var self = this, W = this.wordsEl;
    W.innerHTML = '';
    var gap = function (i) {
      var ins = self.markOn(i, true);
      var g = el('button', {
        type: 'button', class: 'gap' + (ins ? ' ins' : ''),
        'aria-label': self.t('pl_gap_label').replace('{n}', i + 1),
        onclick: function () { ins ? self.select(ins._id, true) : self.newMark(i, 'insertion'); }
      });
      W.appendChild(g);
    };
    this.words.forEach(function (w, i) {
      if (!LETTER.test(w.text)) {      // ayah-number marker: not a word to mark
        W.appendChild(el('span', { class: 'word-sep', 'aria-hidden': 'true' }, w.text));
        return;
      }
      gap(i);
      var m = self.markOn(i, false);
      var b = el('button', { type: 'button', class: 'chip', 'data-i': i }, w.text);
      var label = self.t('pl_word_label').replace('{n}', i + 1);
      if (m) {
        b.classList.add('err');
        b.style.borderColor = COLORS[m.type];
        var dot = el('span', { class: 'dot', 'aria-hidden': 'true' });
        dot.style.background = COLORS[m.type];
        b.appendChild(dot);
        label += self.t('pl_word_marked').replace('{type}', self.t('pl_type_' + m.type));
      }
      if (self.sel && m && m._id === self.sel) b.classList.add('sel');
      b.setAttribute('aria-label', label);
      b.addEventListener('click', function () {
        if (self.mode !== 'mark') { self.seekMs(self.timing[i].start_ms); return; }
        if (m) self.select(m._id, true); else self.newMark(i, 'substitution');
      });
      W.appendChild(b);
    });
    gap(this.words.length);
    if (this.nowIdx != null) {
      var c = W.querySelector('.chip[data-i="' + this.nowIdx + '"]');
      if (c) c.classList.add('now');
    }
  };

  // ---------------------------------------------------------------- marks
  Player.prototype.find = function (id) {
    return this.marks.filter(function (m) { return m._id === id; })[0];
  };

  Player.prototype.markAtPlayhead = function () {
    if (!this.role) return;
    if (this.mode !== 'mark') this.setMode('mark');
    var i = this.wordAt(this.now());
    while (i > 0 && !LETTER.test(this.words[i].text)) i--;
    var existing = this.markOn(i, false);
    if (existing) { this.select(existing._id, true); return; }
    this.newMark(i, 'substitution', true);
  };

  Player.prototype.newMark = function (i, type, atPlayhead) {
    if (!this.role || this.mode !== 'mark') return;
    var t = this.timing[Math.min(i, this.timing.length - 1)] || { start_ms: 0, end_ms: Math.min(800, this.durMs) };
    var start = atPlayhead ? Math.round(this.now()) : (type === 'insertion' ? Math.max(0, t.start_ms - 300) : t.start_ms);
    var end = atPlayhead ? Math.min(this.durMs, start + 800) : (type === 'insertion' ? t.start_ms + 300 : t.end_ms);
    if (end <= start) end = Math.min(this.durMs, start + 400);
    if (end <= start) start = Math.max(0, end - 400);
    this.openEditor({
      _new: true, word_index: i, type: type, subtype: type === 'tajweed' ? 'madd' : null,
      start_ms: start, end_ms: end, said: null, note: null,
      marked_by: this.role === 'reciter' ? 'reciter' : this.role,
      review: this.role === 'reciter' ? null : 'added'
    });
  };

  Player.prototype.select = function (id, open) {
    this.sel = id;
    var m = this.find(id);
    if (m) this.seekMs(m.start_ms);
    this.renderWords();
    this.renderList();
    this.drawRegions();
    if (open && m && this.mode === 'mark' && this.canEdit(m)) this.openEditor(Object.assign({}, m));
  };

  Player.prototype.canEdit = function () { return !!this.role; };

  Player.prototype.remove = function (id) {
    this.marks = this.marks.filter(function (m) { return m._id !== id; });
    if (this.sel === id) this.sel = null;
    this.closeEditor();
    this.touch();
    this.refresh();
  };

  Player.prototype.review = function (id, verdict) {
    var m = this.find(id);
    if (!m) return;
    m.review = verdict;
    this.touch();
    this.refresh();
  };

  Player.prototype.refresh = function () {
    this.renderWords();
    this.renderList();
    this.drawRegions();
  };

  Player.prototype.typeLabel = function (m) {
    var s = this.t('pl_type_' + m.type);
    if (m.subtype) s += ' · ' + this.t('pl_sub_' + m.subtype);
    return s;
  };

  Player.prototype.renderList = function () {
    var self = this, L = this.listEl;
    L.innerHTML = '';
    var live = this.marks.filter(function (m) { return m.review !== 'not_mistake'; });
    this.cntEl.textContent = '(' + live.length + ')';
    if (!this.marks.length) {
      L.appendChild(el('li', { class: 'empty' }, this.t(this.role ? 'pl_none_editable' : 'pl_none')));
      return;
    }
    this.marks.slice().sort(function (a, b) { return a.start_ms - b.start_ms; }).forEach(function (m) {
      var li = el('li', { class: m.review === 'not_mistake' ? 'rejected' : '' });
      var sw = el('span', { class: 'sw', 'aria-hidden': 'true' });
      sw.style.background = COLORS[m.type];
      li.appendChild(sw);
      var body = el('div');
      var where = m.type === 'insertion'
        ? self.t('pl_before_word').replace('{n}', m.word_index + 1)
        : self.t('pl_word_n').replace('{n}', m.word_index + 1);
      body.appendChild(el('div', { class: 't' }, self.typeLabel(m) + ' — ' + where));
      var sub = fmt(m.start_ms) + ' – ' + fmt(m.end_ms);
      if (m.said) sub += ' · ' + self.t('pl_said') + ' «' + m.said + '»';
      if (m.note) sub += ' · ' + m.note;
      body.appendChild(el('div', { class: 's num', dir: 'auto' }, sub));
      var who = self.t('pl_by_' + (m.marked_by || 'reciter'));
      if (m.review) who += ' · ' + self.t('pl_review_' + m.review);
      body.appendChild(el('div', { class: 's' }, who));
      li.appendChild(body);
      var acts = el('div', { class: 'acts' });
      acts.appendChild(el('button', { type: 'button', class: 'btn sm', 'aria-label': self.t('pl_listen'), onclick: function () { self.playMark(m); } }, '▶'));
      if (self.role && self.mode === 'mark') {
        if (self.reviewer && m.marked_by === 'reciter') {
          acts.appendChild(el('button', { type: 'button', class: 'btn sm ok', 'aria-pressed': String(m.review === 'confirmed'), onclick: function () { self.review(m._id, 'confirmed'); } }, '✓ ' + self.t('pl_confirm')));
          acts.appendChild(el('button', { type: 'button', class: 'btn sm', onclick: function () { self.select(m._id, true); } }, '✎ ' + self.t('pl_change')));
          acts.appendChild(el('button', { type: 'button', class: 'btn sm no', 'aria-pressed': String(m.review === 'not_mistake'), onclick: function () { self.review(m._id, m.review === 'not_mistake' ? 'confirmed' : 'not_mistake'); } }, '✕ ' + self.t('pl_not_mistake')));
        } else {
          acts.appendChild(el('button', { type: 'button', class: 'btn sm', 'aria-label': self.t('pl_edit'), onclick: function () { self.select(m._id, true); } }, '✎'));
          acts.appendChild(el('button', { type: 'button', class: 'btn sm no', 'aria-label': self.t('pl_delete'), onclick: function () { self.remove(m._id); } }, '✕'));
        }
      }
      li.appendChild(acts);
      L.appendChild(li);
    });
  };

  Player.prototype.playMark = function (m) {
    if (!this.ws) return;
    var reg = this.regions.getRegions().filter(function (r) { return r.id === String(m._id); })[0];
    if (reg) reg.play(); else this.seekMs(m.start_ms);
  };

  // --------------------------------------------------------------- editor
  Player.prototype.buildEditor = function () {
    var self = this, E = this.editor;
    if (!E) return;
    var types = $('.types', E);
    TYPES.forEach(function (ty, i) {
      types.appendChild(el('button', {
        type: 'button', class: 'type c-' + ty, role: 'radio', 'aria-checked': 'false', 'data-type': ty,
        onclick: function () { self.setDraftType(ty); }
      }, (i + 1) + ' ' + self.t('pl_type_' + ty)));
      types.lastChild.appendChild(el('small', null, self.t('pl_hint_' + ty)));
    });
    var subs = $('.subs', E);
    SUBS.forEach(function (s) {
      subs.appendChild(el('button', {
        type: 'button', 'aria-pressed': 'false', 'data-sub': s,
        onclick: function () { self.edit.subtype = s; self.paintEditor(); }
      }, self.t('pl_sub_' + s)));
    });
    E.querySelectorAll('[data-nudge]').forEach(function (b) {
      b.addEventListener('click', function () {
        var p = b.dataset.nudge.split(':');
        var k = p[0] === 's' ? 'start_ms' : 'end_ms';
        self.edit[k] = Math.max(0, Math.min(self.durMs, self.edit[k] + (+p[1])));
        if (self.edit.end_ms <= self.edit.start_ms) self.edit.end_ms = Math.min(self.durMs, self.edit.start_ms + 100);
        self.paintEditor();
      });
    });
    $('.ed-save', E).addEventListener('click', function () { self.commitEditor(); });
    $('.ed-cancel', E).addEventListener('click', function () { self.closeEditor(); });
    $('.ed-delete', E).addEventListener('click', function () { if (self.edit && !self.edit._new) self.remove(self.edit._id); });
  };

  Player.prototype.setDraftType = function (ty) {
    if (!this.edit) return;
    this.edit.type = ty;
    if (ty === 'tajweed' && !this.edit.subtype) this.edit.subtype = 'madd';
    if (ty !== 'tajweed') this.edit.subtype = null;
    this.paintEditor();
  };

  Player.prototype.openEditor = function (draft) {
    if (!this.editor) return;
    this.edit = draft;
    $('.said input', this.editor).value = draft.said || '';
    $('textarea', this.editor).value = draft.note || '';
    this.editor.hidden = false;
    this.editor.classList.add('open');
    this.paintEditor();
    var first = this.editor.querySelector('.type[aria-checked="true"]') || this.editor.querySelector('.type');
    if (first) first.focus();
  };

  Player.prototype.paintEditor = function () {
    var d = this.edit, E = this.editor;
    if (!d) return;
    var where = d.type === 'insertion'
      ? this.t('pl_before_word').replace('{n}', d.word_index + 1)
      : this.t('pl_word_n').replace('{n}', d.word_index + 1);
    $('.ed-title', E).textContent = this.t('pl_type_title') + ' — ' + where;
    E.querySelectorAll('.type').forEach(function (b) { b.setAttribute('aria-checked', String(b.dataset.type === d.type)); });
    $('.subs', E).hidden = d.type !== 'tajweed';
    E.querySelectorAll('[data-sub]').forEach(function (b) { b.setAttribute('aria-pressed', String(b.dataset.sub === d.subtype)); });
    $('.said', E).hidden = d.type !== 'substitution';
    $('.ed-range', E).textContent = fmt(d.start_ms) + ' ← ' + fmt(d.end_ms);
    $('.ed-delete', E).hidden = !!d._new;
  };

  Player.prototype.syncEditorTime = function (m) {
    if (this.edit && this.edit._id === m._id) {
      this.edit.start_ms = m.start_ms; this.edit.end_ms = m.end_ms; this.paintEditor();
    }
  };

  Player.prototype.commitEditor = function () {
    var d = this.edit;
    if (!d) return;
    d.said = d.type === 'substitution' ? ($('.said input', this.editor).value.trim().slice(0, 200) || null) : null;
    d.note = $('textarea', this.editor).value.trim().slice(0, 500) || null;
    if (d._new) {
      delete d._new;
      d._id = this.nextId++;
      this.marks.push(d);
    } else {
      var m = this.find(d._id);
      var changed = m && (m.type !== d.type || m.subtype !== d.subtype || m.start_ms !== d.start_ms || m.end_ms !== d.end_ms || m.said !== d.said);
      Object.assign(m, d);
      if (this.reviewer && m.marked_by === 'reciter') m.review = changed ? 'changed' : (m.review || 'confirmed');
    }
    this.sel = d._id;
    this.closeEditor();
    this.touch();
    this.refresh();
  };

  Player.prototype.closeEditor = function () {
    this.edit = null;
    if (this.editor) { this.editor.hidden = true; this.editor.classList.remove('open'); }
  };

  // ---------------------------------------------------------------- save
  Player.prototype.touch = function () {
    this.dirty = true;
    this.msgEl.className = 'saved';
    this.msgEl.textContent = this.t('pl_unsaved');
    if (this.dlBtn) this.dlBtn.setAttribute('aria-disabled', 'true');
  };

  Player.prototype.payload = function () {
    return {
      base_version: this.base,
      mistakes: this.marks.map(function (m) {
        return {
          word_index: m.word_index, type: m.type, subtype: m.subtype,
          start_ms: Math.round(m.start_ms), end_ms: Math.round(m.end_ms),
          said: m.said, note: m.note, review: m.review, marked_by: m.marked_by
        };
      })
    };
  };

  Player.prototype.save = function () {
    var self = this;
    if (!this.role) return Promise.resolve(false);
    if (this.saveBtn) this.saveBtn.disabled = true;
    return fetch(this.d.save, {
      method: 'POST', credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrf() },
      body: JSON.stringify(this.payload())
    }).then(function (r) {
      return r.json().catch(function () { return {}; }).then(function (b) { return { ok: r.ok, status: r.status, body: b }; });
    }).then(function (res) {
      if (self.saveBtn) self.saveBtn.disabled = false;
      if (!res.ok) {
        var key = res.status === 409 ? 'pl_err_conflict' : res.status === 429 ? 'pl_err_rate' : 'pl_err_save';
        self.msgEl.className = 'saved err';
        self.msgEl.textContent = self.t(key);
        store('tibyan-marks-' + self.d.id, self.payload());
        return false;
      }
      self.base = res.body.version;
      self.dirty = false;
      store('tibyan-marks-' + self.d.id, null);
      self.msgEl.className = 'saved';
      self.msgEl.textContent = '✓ ' + self.t('pl_saved').replace('{v}', res.body.version).replace('{role}', self.t('pl_role_' + res.body.author_role));
      if (self.dlBtn) {
        self.dlBtn.href = res.body.download;
        self.dlBtn.removeAttribute('aria-disabled');
      }
      var hs = $('.pl-has-mistakes', self.root);
      if (hs) hs.hidden = !res.body.has_mistakes;
      return true;
    }).catch(function () {
      if (self.saveBtn) self.saveBtn.disabled = false;
      self.msgEl.className = 'saved err';
      self.msgEl.textContent = self.t('pl_err_save');
      store('tibyan-marks-' + self.d.id, self.payload());
      return false;
    });
  };

  // ------------------------------------------------------------- keyboard
  Player.prototype.key = function (e) {
    var tag = e.target.tagName;
    if (/INPUT|TEXTAREA|SELECT/.test(tag) || e.target.isContentEditable) {
      if (e.key === 'Escape' && this.edit) this.closeEditor();
      return;
    }
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    var k = e.key;
    if (this.edit) {
      if (/^[1-6]$/.test(k)) { e.preventDefault(); this.setDraftType(TYPES[+k - 1]); return; }
      if (k === 'Enter' && !/BUTTON|A/.test(tag)) { e.preventDefault(); this.commitEditor(); return; }
      if (k === 'Escape') { e.preventDefault(); this.closeEditor(); return; }
    }
    if (k === ' ' || e.code === 'Space') {
      if (tag === 'BUTTON' || tag === 'A') return;
      e.preventDefault(); this.toggle();
    } else if (k === 'ArrowLeft' || k === 'ArrowRight') {
      if (tag === 'BUTTON' && e.target.closest('.seg')) return;
      e.preventDefault();
      var forward = (k === 'ArrowLeft') === this.rtl;
      this.skip(forward ? 5 : -5);
    } else if (k === 'm' || k === 'M' || k === 'م') {
      e.preventDefault(); this.markAtPlayhead();
    } else if (/^[1-6]$/.test(k) && this.sel && this.mode === 'mark') {
      var m = this.find(this.sel);
      if (m) { this.openEditor(Object.assign({}, m)); this.setDraftType(TYPES[+k - 1]); }
    } else if (k === 'l' || k === 'L' || k === 'ل') {
      this.toggleLoop();
    } else if ((k === '[' || k === ']') && this.loop) {
      var t = this.now() / 1000;
      if (k === '[' && t < this.loop[1]) this.loop[0] = t;
      if (k === ']' && t > this.loop[0]) this.loop[1] = t;
      this.drawRegions();
    } else if ((k === 'Delete' || k === 'Backspace') && this.sel && this.mode === 'mark' && !this.reviewer) {
      e.preventDefault(); this.remove(this.sel);
    }
  };

  // ---------------------------------------------------- reviewer hand-off
  function hookReviewForms(player) {
    document.querySelectorAll('form[data-save-marks]').forEach(function (form) {
      form.addEventListener('submit', function (e) {
        if (!player.dirty) return;
        e.preventDefault();
        player.save().then(function (ok) { if (ok) form.submit(); });
      });
    });
  }

  // ------------------------------------------------- «تسجيلاتي» mini rows
  function drawMini(canvas, peaks, progress) {
    var r = canvas.getBoundingClientRect(), dpr = window.devicePixelRatio || 1;
    canvas.width = Math.max(1, r.width * dpr); canvas.height = Math.max(1, r.height * dpr);
    var c = canvas.getContext('2d'); c.scale(dpr, dpr);
    var css = getComputedStyle(document.documentElement);
    var bars = Math.max(1, Math.floor(r.width / 3));
    for (var i = 0; i < bars; i++) {
      var v = peaks[Math.floor(i / bars * peaks.length)] || 0;
      var h = Math.max(2, v * r.height * 0.9);
      c.fillStyle = (i / bars) < progress ? css.getPropertyValue('--bronze') : css.getPropertyValue('--gold') + '99';
      c.fillRect(i * 3, (r.height - h) / 2, 2, h);
    }
  }

  function initMiniRows() {
    var rtl = document.documentElement.dir === 'rtl';
    document.querySelectorAll('.rec[data-id]').forEach(function (row) {
      var id = row.dataset.id, canvas = row.querySelector('canvas.mini'), btn = row.querySelector('.ic.play');
      var audio = row.querySelector('audio'), peaks = null;
      if (rtl) canvas.classList.add('flip');
      fetch('/recordings/' + id + '/peaks.json', { credentials: 'same-origin' })
        .then(function (r) { return r.ok ? r.json() : null; })
        .then(function (p) { if (p) { peaks = p.peaks; drawMini(canvas, peaks, 0); } });
      btn.addEventListener('click', function () {
        document.querySelectorAll('.rec audio').forEach(function (a) { if (a !== audio) a.pause(); });
        if (audio.paused) audio.play(); else audio.pause();
      });
      audio.addEventListener('play', function () { btn.setAttribute('aria-pressed', 'true'); btn.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 5h4v14H6zM14 5h4v14h-4z"/></svg>'; });
      audio.addEventListener('pause', function () { btn.setAttribute('aria-pressed', 'false'); btn.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M8 5v14l11-7z"/></svg>'; });
      audio.addEventListener('timeupdate', function () {
        if (peaks && audio.duration) drawMini(canvas, peaks, audio.currentTime / audio.duration);
      });
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    var root = document.querySelector('.player-root');
    if (root && window.WaveSurfer) {
      var data = JSON.parse(document.getElementById('player-data').textContent);
      var p = new Player(root, data);
      window.tibyanPlayer = p;
      hookReviewForms(p);
    }
    initMiniRows();
  });
})();
