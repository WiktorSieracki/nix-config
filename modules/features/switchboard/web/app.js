'use strict';

// switchboard web — the page. It draws what the server reports and sends back
// what was clicked. The rules (requires closure, refusals, file order) all
// live on the Go side, shared with the TUI: a toggle is a round trip to
// /api/toggle, never a decision made here.

(() => {
  const token = document.querySelector('meta[name="switchboard-token"]').content;
  const $ = (selector) => document.querySelector(selector);

  const KINDS = ['cli', 'gui', 'service', 'config', 'other'];
  const KIND_GLOSS = {
    cli: 'a binary on PATH',
    gui: 'holds a window in the session',
    service: 'a systemd unit',
    config: 'pure configuration',
    other: 'listed in a features.json, but not in the catalog',
  };
  const STATE_WORDS = {
    on: 'enabled',
    off: 'off',
    adding: 'will be enabled when you save',
    removing: 'will be disabled when you save',
  };
  const TOP_LEVEL = 'top level';

  const S = {
    data: null, // the last /api/state
    draft: {}, // host name → spec being edited
    selected: null, // feature shown in the inspector
    view: 'matrix',
    query: '',
    show: 'all',
    group: 'kind',
    lens: null, // host whose lamps the requires graph lights
    flash: new Set(), // cell keys that lit because of the last toggle
    touched: new Set(), // hosts saved or applied from this page
    rows: [], // feature names in display order (keyboard navigation)
    job: null,
    jobText: '',
    say: { text: '', level: 'info' },
    queue: Promise.resolve(), // toggles run one after another
  };

  // ── small helpers ─────────────────────────────────────────────────────────

  function h(tag, props, ...kids) {
    const el = document.createElement(tag);
    for (const [key, value] of Object.entries(props || {})) {
      if (value == null || value === false) continue;
      if (key === 'class') el.className = value;
      else if (key === 'text') el.textContent = value;
      else if (key === 'dataset') Object.assign(el.dataset, value);
      else if (key.startsWith('on')) el.addEventListener(key.slice(2), value);
      else el.setAttribute(key, value === true ? '' : value);
    }
    el.append(...kids.flat().filter((kid) => kid != null && kid !== false));
    return el;
  }

  // replaceChildren/append turn a null into the text "null"; drop them first.
  const fill = (el, ...kids) => el.replaceChildren(...kids.flat().filter((kid) => kid != null && kid !== false));

  function svg(tag, attrs, ...kids) {
    const el = document.createElementNS('http://www.w3.org/2000/svg', tag);
    for (const [key, value] of Object.entries(attrs || {})) {
      if (value != null && value !== false) el.setAttribute(key, value);
    }
    el.append(...kids.flat().filter((kid) => kid != null && kid !== false));
    return el;
  }

  async function api(path, body) {
    const headers = { 'X-Switchboard-Token': token };
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    let resp;
    try {
      resp = await fetch(path, {
        method: body === undefined ? 'GET' : 'POST',
        headers,
        body: body === undefined ? undefined : JSON.stringify(body),
      });
    } catch {
      throw new Error(
        'switchboard is not answering. It may have exited: run `switchboard web` again, then reload this page.',
      );
    }
    let data = null;
    try {
      data = await resp.json();
    } catch {
      // not JSON: the guard's plain-text refusals
    }
    if (!resp.ok) {
      const err = new Error((data && data.error) || `${resp.status} ${resp.statusText}`);
      err.status = resp.status;
      throw err;
    }
    return data;
  }

  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
  const plural = (n, word) => `${n} ${word}${n === 1 ? '' : 's'}`;
  const lamp = (state) => h('span', { dataset: { state } }, h('span', { class: 'lens' }));

  const feat = (name) => S.data.catalog[name];
  const hasCatalog = () => Object.keys(S.data.catalog).length > 0;
  const cellKey = (name, host) => `${name}|${host.name}`;

  function say(text, level = 'info') {
    S.say = { text, level };
    renderStatus();
  }

  // ── what the lamps show ───────────────────────────────────────────────────

  function cellState(host, name) {
    const inFile = host.features.includes(name);
    const inDraft = S.draft[host.name].includes(name);
    if (inFile && inDraft) return 'on';
    if (inDraft) return 'adding';
    if (inFile) return 'removing';
    return 'off';
  }

  // The unsaved difference between a host's file and its draft.
  function diffOf(host) {
    const draft = S.draft[host.name];
    return {
      added: draft.filter((name) => !host.features.includes(name)),
      removed: host.features.filter((name) => !draft.includes(name)),
    };
  }

  const changes = (diff) => diff.added.length + diff.removed.length;

  const unsavedHosts = () => S.data.hosts.filter((host) => changes(diffOf(host)) > 0);
  const enabledOn = (host, name) => S.draft[host.name].includes(name);

  // Catalog features plus whatever a features.json lists that the catalog lacks.
  function allNames() {
    const names = new Set(Object.keys(S.data.catalog));
    for (const host of S.data.hosts) {
      for (const name of host.features) names.add(name);
      for (const name of S.draft[host.name]) names.add(name);
    }
    return [...names].sort();
  }

  function visibleNames() {
    const query = S.query.trim().toLowerCase();
    const changed = new Set(S.data.hosts.flatMap((host) => Object.values(diffOf(host)).flat()));
    return allNames().filter((name) => {
      if (query && !name.toLowerCase().includes(query)) return false;
      const anywhere = S.data.hosts.some((host) => enabledOn(host, name));
      if (S.show === 'enabled') return anywhere;
      if (S.show === 'unused') return !anywhere;
      if (S.show === 'changed') return changed.has(name);
      return true;
    });
  }

  function groupsOf(names) {
    const byKey = new Map();
    for (const name of names) {
      const f = feat(name);
      const key = S.group === 'folder' ? (f ? f.group || TOP_LEVEL : 'other') : (f && f.kind) || 'other';
      if (!byKey.has(key)) byKey.set(key, []);
      byKey.get(key).push(name);
    }
    const rank = (key) => {
      if (S.group === 'kind') return KINDS.includes(key) ? KINDS.indexOf(key) : KINDS.length;
      return key === 'other' ? 2 : key === TOP_LEVEL ? 1 : 0;
    };
    return [...byKey.keys()]
      .sort((a, b) => rank(a) - rank(b) || a.localeCompare(b))
      .map((key) => ({
        key,
        gloss:
          S.group === 'kind'
            ? KIND_GLOSS[key]
            : key === TOP_LEVEL
              ? 'modules/features'
              : key === 'other'
                ? KIND_GLOSS.other
                : `modules/features/${key}`,
        names: byKey.get(key),
      }));
  }

  // ── loading ───────────────────────────────────────────────────────────────

  async function load(reload) {
    const data = await api('/api/state' + (reload ? '?reload=1' : ''));
    const before = S.data;
    // Unsaved edits are never rebased behind the user's back. A host that has
    // them keeps the file version they were made against, even once the file
    // has changed on disk (the TUI, an editor, git): it is flagged `moved`,
    // and the server refuses to save over the newer file (the rev no longer
    // matches) until the page takes the file's version.
    data.hosts = data.hosts.map((host) => {
      const old = before && before.hosts.find((x) => x.name === host.name);
      if (!old || !S.draft[host.name] || changes(diffOf(old)) === 0) {
        S.draft[host.name] = [...host.features];
        return host;
      }
      return old.rev === host.rev ? host : { ...old, moved: true };
    });
    S.data = data;
    if (!S.lens || !data.hosts.some((host) => host.name === S.lens)) {
      S.lens = (data.hosts.find((host) => host.local) || data.hosts[0]).name;
    }
    if (S.selected && !allNames().includes(S.selected)) S.selected = null;
    return before === null || JSON.stringify(before) !== JSON.stringify(data);
  }

  // Drops one host's unsaved edits so the next load adopts the file as it is.
  async function takeFile(host) {
    S.draft[host.name] = [...host.features];
    await refresh();
    say(`Loaded ${host.file} as it is on disk.`);
  }

  async function refresh() {
    try {
      if (await load(false)) render();
    } catch (err) {
      say(err.message, 'error');
    }
  }

  // ── editing ───────────────────────────────────────────────────────────────

  function toggle(host, name) {
    S.queue = S.queue.then(async () => {
      if (!hasCatalog()) {
        say('The feature catalog is not loaded, so the lists are read-only for now.', 'warn');
        return;
      }
      const before = S.draft[host.name];
      try {
        const res = await api('/api/toggle', { host: host.name, feature: name, features: before });
        S.draft[host.name] = res.features;
        // Everything that lit besides the clicked lamp: the pulled requires.
        S.flash = new Set(
          res.features
            .filter((pulled) => pulled !== name && !before.includes(pulled))
            .map((pulled) => cellKey(pulled, host)),
        );
        S.say = { text: res.message, level: res.refused ? 'warn' : 'info' };
      } catch (err) {
        S.say = { text: err.message, level: 'error' };
      }
      render();
      S.flash = new Set();
    });
  }

  async function discard() {
    for (const host of S.data.hosts) S.draft[host.name] = [...host.features];
    render();
    // With the edits gone, a host whose file moved on can take the new file.
    await refresh();
    say('Discarded the unsaved changes.');
  }

  function replaceHost(fresh) {
    S.data.hosts = S.data.hosts.map((host) => (host.name === fresh.name ? fresh : host));
    S.draft[fresh.name] = [...fresh.features];
  }

  async function save(dialog, failed, button) {
    const saved = [];
    // One save at a time: a second click would race the first one's write.
    button.disabled = true;
    try {
      for (const host of unsavedHosts()) {
        const res = await api('/api/save', { host: host.name, rev: host.rev, features: S.draft[host.name] });
        replaceHost(res.host);
        S.touched.add(host.name);
        saved.push(host.name);
      }
    } catch (err) {
      failed.textContent = err.message;
      failed.hidden = false;
      button.disabled = false;
      render();
      return;
    }
    dialog.close();
    say(`Saved ${saved.join(', ')}. Nothing is applied yet.`);
    render();
  }

  async function commit(host) {
    try {
      const res = await api('/api/commit', { host: host.name });
      replaceHost(res.host);
      S.touched.add(host.name);
      say(`Committed: ${res.message}`);
    } catch (err) {
      say(err.message, 'error');
    }
    render();
  }

  // ── jobs ──────────────────────────────────────────────────────────────────

  function adoptJob(job) {
    const finished = S.job && S.job.id === job.id && S.job.running && !job.running;
    if (!S.job || S.job.id !== job.id) S.jobText = '';
    S.jobText += job.output;
    S.job = job;
    if (finished) jobFinished(job);
  }

  function jobFinished(job) {
    const ok = job.exit === 0;
    if (job.action === 'check') {
      say(
        ok
          ? `The build check for ${job.host} passed — apply it on ${job.host}.`
          : `The build check for ${job.host} failed (exit ${job.exit}). Read the output before applying it.`,
        ok ? 'info' : 'error',
      );
    } else if (ok) {
      say(
        job.action === 'switch'
          ? 'nh os switch succeeded. Commit it when you are happy with it.'
          : 'nh os test succeeded. Nothing was committed.',
      );
    } else {
      say(`nh os ${job.action} failed (exit ${job.exit}).`, 'error');
    }
  }

  async function startJob(action, host) {
    try {
      const res = await api('/api/job', { action, host: host.name });
      S.touched.add(host.name);
      adoptJob(res.job);
      say('');
      renderDock();
      followJob();
    } catch (err) {
      say(err.message, 'error');
    }
  }

  let following = false;
  async function followJob() {
    if (following) return;
    following = true;
    try {
      while (S.job && S.job.running) {
        await sleep(600);
        let res;
        try {
          res = await api(`/api/job?id=${S.job.id}&offset=${S.job.next}`);
        } catch (err) {
          // One lost poll must not leave the job "running" forever with the
          // buttons disabled: say so and keep asking.
          say(err.message, 'error');
          await sleep(2400);
          continue;
        }
        if (!res.job) break;
        adoptJob(res.job);
        if (res.job.running) renderConsole();
        else renderDock();
      }
    } finally {
      following = false;
    }
  }

  async function stopJob() {
    try {
      await api('/api/job/stop', {});
    } catch (err) {
      say(err.message, 'error');
    }
  }

  // ── rendering ─────────────────────────────────────────────────────────────

  // Rebuilding a region drops the focused element; put focus back on the
  // element that stands for the same thing (same data-key) afterwards.
  function keepFocus(region, rebuild) {
    const active = document.activeElement;
    const key = active && region.contains(active) && active.dataset ? active.dataset.key : null;
    rebuild();
    if (key) {
      const again = region.querySelector(`[data-key="${CSS.escape(key)}"]`);
      if (again) again.focus({ preventScroll: true });
    }
  }

  function render() {
    renderBoard();
    keepFocus($('#inspector'), renderInspector);
    renderDock();
  }

  function renderBoard() {
    keepFocus($('#board'), buildBoard);
  }

  function buildBoard() {
    const board = $('#board');
    const kids = [];
    if (S.data.catalogError) {
      kids.push(
        h(
          'div',
          { class: 'notice', role: 'alert' },
          h(
            'p',
            {},
            'The feature catalog could not be evaluated, so the lists are read-only. ',
            h('code', { text: S.data.catalogError }),
          ),
          h('button', { class: 'btn', type: 'button', text: 'Evaluate again', onclick: reload }),
        ),
      );
    }
    kids.push(...(S.view === 'graph' ? graphView() : matrixView()));
    fill(board, kids);
    $('#group-field').hidden = S.view !== 'matrix';
  }

  function matrixView() {
    const hosts = S.data.hosts;
    const groups = groupsOf(visibleNames());
    S.rows = groups.flatMap((group) => group.names);
    if (S.rows.length === 0) {
      const why = S.query
        ? `No feature matches “${S.query}”.`
        : {
            changed: 'Nothing is unsaved.',
            enabled: 'No host enables anything yet.',
            unused: 'Every feature is enabled somewhere.',
          }[S.show] || 'There are no features.';
      return [h('p', { class: 'empty', text: why })];
    }

    const legend = h(
      'dl',
      { class: 'legend' },
      ...[
        ['on', 'enabled'],
        ['adding', 'will enable'],
        ['removing', 'will disable'],
      ].flatMap(([state, words]) => [h('dt', {}, lamp(state)), h('dd', { text: words })]),
    );

    // One column per host: a host has one list, and a feature is on it or not.
    const head = h(
      'thead',
      {},
      h(
        'tr',
        {},
        h('th', { class: 'corner' }, legend),
        ...hosts.map((host) =>
          h(
            'th',
            { class: 'host', scope: 'col' },
            host.name,
            hostFlags(host),
            h('span', { class: 'count', text: plural(S.draft[host.name].length, 'feature') }),
          ),
        ),
      ),
    );

    const bodies = groups.map((group) =>
      h(
        'tbody',
        {},
        h(
          'tr',
          { class: 'group' },
          h(
            'th',
            { colspan: hosts.length + 1, scope: 'rowgroup' },
            h(
              'span',
              { class: 'label' },
              group.key,
              h('span', { class: 'tally', text: String(group.names.length) }),
              h('span', { class: 'gloss', text: group.gloss }),
            ),
          ),
        ),
        ...group.names.map((name) =>
          h(
            'tr',
            { class: name === S.selected ? 'selected' : null },
            h(
              'th',
              { class: 'name', scope: 'row' },
              h('button', {
                type: 'button',
                class: feat(name) ? null : 'stray',
                dataset: { key: `${name}|name`, row: name, col: -1 },
                'aria-expanded': name === S.selected ? 'true' : 'false',
                title: 'Show details',
                text: name,
                onclick: () => select(name === S.selected ? null : name),
              }),
            ),
            ...hosts.map((host, col) => h('td', {}, jack(host, name, col))),
          ),
        ),
      ),
    );

    return [h('table', { class: 'matrix' }, head, ...bodies)];
  }

  function hostFlags(host) {
    const flags = [];
    if (host.local) flags.push(h('span', { class: 'flag', text: 'this machine' }));
    if (host.error) flags.push(h('span', { class: 'flag warn', text: host.error }));
    if (host.moved) {
      flags.push(
        h('button', {
          type: 'button',
          class: 'flag warn',
          text: 'changed on disk',
          title: `${host.file} changed since these edits began, so they cannot be saved over it. Click to drop this host's unsaved edits and load the file as it is now.`,
          onclick: () => takeFile(host),
        }),
      );
    } else if (changes(diffOf(host))) flags.push(h('span', { class: 'flag warn', text: 'unsaved' }));
    else if (changes(host.uncommitted)) flags.push(h('span', { class: 'flag', text: 'not committed' }));
    if (host.problems.length) {
      flags.push(
        h('button', {
          type: 'button',
          class: 'flag warn',
          text: plural(host.problems.length, 'problem'),
          title: host.problems.join('\n'),
          onclick: () => say(`${host.file}: ${host.problems.join('; ')}`, 'warn'),
        }),
      );
    }
    return h('span', { class: 'flags' }, flags);
  }

  function jack(host, name, col) {
    const state = cellState(host, name);
    const key = cellKey(name, host);
    return h(
      'button',
      {
        type: 'button',
        class: 'jack' + (S.flash.has(key) ? ' flash' : ''),
        dataset: { state, key, row: name, col },
        'aria-pressed': state === 'on' || state === 'adding' ? 'true' : 'false',
        'aria-label': `${name} on ${host.name}: ${STATE_WORDS[state]}`,
        title: `${host.name}: ${STATE_WORDS[state]}`,
        onclick: () => toggle(host, name),
      },
      h('span', { class: 'lens' }),
    );
  }

  function select(name) {
    S.selected = name;
    render();
  }

  // ── the requires graph ────────────────────────────────────────────────────

  const ROW = 26;
  const NODE = 184;
  const COLUMN = 276;

  // Lays the features that take part in a `requires` edge out in columns: a
  // feature sits one column right of the deepest thing it requires, so every
  // cord runs left, towards the foundations.
  function graphLayout() {
    const F = S.data.catalog;
    const names = Object.keys(F).sort();
    const requires = (name) => (F[name].requires || []).filter((dep) => F[dep]);
    const dependents = {};
    for (const name of names) for (const dep of requires(name)) (dependents[dep] ||= []).push(name);
    const linked = names.filter((name) => requires(name).length || dependents[name]);

    const column = {};
    const depth = (name, trail) => {
      if (column[name] !== undefined) return column[name];
      if (trail.has(name)) return 0; // a requires cycle: stop here
      trail.add(name);
      const below = requires(name).map((dep) => depth(dep, trail));
      trail.delete(name);
      return (column[name] = below.length ? 1 + Math.max(...below) : 0);
    };
    linked.forEach((name) => depth(name, new Set()));

    const cols = [];
    for (const name of linked) (cols[column[name]] ||= []).push(name);

    // Order each column by where its requirements sit, then walk back from the
    // right and centre every feature on the ones that require it.
    const order = {};
    cols.forEach((col, c) => {
      const mean = (name) => {
        const at = requires(name).map((dep) => order[dep]);
        return at.length ? at.reduce((a, b) => a + b, 0) / at.length : 0;
      };
      if (c === 0)
        col.sort((a, b) => (dependents[b] || []).length - (dependents[a] || []).length || a.localeCompare(b));
      else col.sort((a, b) => mean(a) - mean(b) || a.localeCompare(b));
      col.forEach((name, i) => (order[name] = i));
    });
    const y = {};
    for (let c = cols.length - 1; c >= 0; c--) {
      const wish = (name) => {
        const at = (dependents[name] || []).map((dep) => y[dep]).filter((v) => v !== undefined);
        return at.length ? at.reduce((a, b) => a + b, 0) / at.length : null;
      };
      const placed = cols[c].map((name) => ({ name, wish: wish(name) }));
      // Features nothing requires keep their order below the centred ones.
      placed.sort((a, b) => (a.wish === null) - (b.wish === null) || (a.wish ?? 0) - (b.wish ?? 0));
      let next = 0;
      for (const p of placed) {
        y[p.name] = Math.max(p.wish ?? next, next);
        next = y[p.name] + ROW;
      }
    }
    const height = Math.max(...linked.map((name) => y[name]), 0) + ROW;
    return {
      linked,
      loose: names.filter((name) => !linked.includes(name)),
      requires,
      dependents,
      column,
      y,
      width: cols.length * COLUMN - (COLUMN - NODE),
      height,
    };
  }

  function closure(start, next) {
    const seen = new Set();
    const stack = [start];
    while (stack.length) {
      for (const name of next(stack.pop()) || []) {
        if (!seen.has(name)) {
          seen.add(name);
          stack.push(name);
        }
      }
    }
    return seen;
  }

  function graphView() {
    if (!hasCatalog()) return [h('p', { class: 'empty', text: 'The requires graph needs the feature catalog.' })];
    const g = graphLayout();
    const lensHost = S.data.hosts.find((host) => host.name === S.lens);
    const lit = (name) => enabledOn(lensHost, name);
    const top = ROW / 2 + 6;

    const cords = [];
    const nodes = [];
    for (const name of g.linked) {
      const x = g.column[name] * COLUMN;
      const cy = g.y[name] + top;
      for (const dep of g.requires(name)) {
        const x1 = g.column[dep] * COLUMN + NODE;
        const y1 = g.y[dep] + top;
        const bend = (x - x1) / 2;
        cords.push(
          svg('path', {
            class: 'cord',
            'data-from': name,
            'data-to': dep,
            d: `M${x1} ${y1} C${x1 + bend} ${y1} ${x - bend} ${cy} ${x} ${cy}`,
          }),
        );
      }
      nodes.push(
        svg(
          'g',
          {
            class: 'node' + (lit(name) ? ' lit' : '') + (name === S.selected ? ' selected' : ''),
            'data-name': name,
            'data-key': `${name}|node`,
            tabindex: 0,
            role: 'button',
            'aria-label': `${name}${lit(name) ? `, enabled on ${S.lens}` : ''}`,
          },
          svg('rect', { class: 'plate', x, y: cy - ROW / 2 + 2, width: NODE, height: ROW - 4, rx: 6 }),
          svg('circle', { cx: x + 13, cy, r: 5.5 }),
          svg('text', { x: x + 27, y: cy + 4.5 }, name),
        ),
      );
    }

    const chart = svg(
      'svg',
      {
        class: 'graph',
        width: g.width,
        height: g.height + 12,
        viewBox: `0 0 ${g.width} ${g.height + 12}`,
        role: 'group',
        'aria-label': 'Requires graph',
      },
      ...cords,
      ...nodes,
    );

    // Hovering or focusing a feature lights the cords of everything it stands
    // on and everything that stands on it.
    const focus = (name) => {
      chart.classList.toggle('focused', Boolean(name));
      if (!name) return;
      const up = closure(name, g.requires).add(name);
      const down = closure(name, (n) => g.dependents[n]).add(name);
      for (const node of chart.querySelectorAll('.node')) {
        node.classList.toggle('near', up.has(node.dataset.name) || down.has(node.dataset.name));
      }
      for (const cord of chart.querySelectorAll('.cord')) {
        const { from, to } = cord.dataset;
        cord.classList.toggle('hot', (up.has(from) && up.has(to)) || (down.has(from) && down.has(to)));
      }
    };
    const rest = () => focus(S.selected && g.linked.includes(S.selected) ? S.selected : null);
    for (const node of chart.querySelectorAll('.node')) {
      const name = node.dataset.name;
      node.addEventListener('mouseenter', () => focus(name));
      node.addEventListener('mouseleave', rest);
      node.addEventListener('focus', () => focus(name));
      node.addEventListener('blur', rest);
      node.addEventListener('click', () => select(name === S.selected ? null : name));
      node.addEventListener('keydown', (event) => {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          select(name === S.selected ? null : name);
        }
      });
    }
    rest();

    const lens = h(
      'select',
      {
        id: 'lens',
        onchange: (event) => {
          S.lens = event.target.value;
          renderBoard();
        },
      },
      ...S.data.hosts.map((host) => h('option', { value: host.name, selected: host.name === S.lens, text: host.name })),
    );

    return [
      h(
        'div',
        { class: 'graph-view' },
        h(
          'div',
          { class: 'graph-tools' },
          h('label', { class: 'field' }, h('span', { text: 'Light what is enabled on' }), lens),
          h('p', { text: 'A cord runs from a feature to what it requires. Foundations are on the left.' }),
        ),
        chart,
        h(
          'div',
          { class: 'loose' },
          h(
            'h2',
            {},
            'Stand-alone',
            h('span', { class: 'tally', text: String(g.loose.length) }),
            h('span', { class: 'gloss', text: 'require nothing, and nothing requires them' }),
          ),
          h('ul', { class: 'chips' }, ...g.loose.map((name) => h('li', {}, chip(name, lit(name) ? 'on' : 'off')))),
        ),
      ),
    ];
  }

  function chip(name, state, extra) {
    return h(
      'button',
      {
        type: 'button',
        class: 'chip' + (extra ? ` ${extra}` : ''),
        dataset: state ? { state, key: `${name}|chip` } : { key: `${name}|chip` },
        onclick: () => select(name),
      },
      state ? h('span', { class: 'lens' }) : null,
      name,
    );
  }

  // ── side panel: an overview of the hosts, or one feature ───────────────────

  function renderInspector() {
    const el = $('#inspector');
    el.classList.toggle('idle', !S.selected);
    fill(el, S.selected ? featurePanel(S.selected) : overviewPanel());
  }

  // What each host ends up with, counting the unsaved edits.
  function overviewPanel() {
    return [
      h('header', {}, h('h2', { class: 'plain', text: 'What each host has' })),
      h('p', {
        class: 'what',
        text: 'Counted from the lamps as they are now, unsaved changes included. Pick a feature to see what it requires and where it is on.',
      }),
      h('div', { class: 'cards' }, ...S.data.hosts.map(hostCard)),
    ];
  }

  function hostCard(host) {
    const on = allNames().filter((name) => enabledOn(host, name));
    const kinds = KINDS.map((kind) => [
      kind,
      on.filter((name) => ((feat(name) || {}).kind || 'other') === kind).length,
    ]).filter(([, n]) => n > 0);
    // "sshd.service (ssh-server)": each thing once, with every feature that declares it.
    const provided = (pick) => {
      const from = new Map();
      for (const name of on) {
        for (const item of feat(name) ? pick(feat(name).provides) : []) {
          if (!from.has(item)) from.set(item, []);
          from.get(item).push(name);
        }
      }
      return [...from].map(([item, names]) => `${item} (${names.join(', ')})`);
    };
    const units = provided((p) => [...p.units, ...p.userUnits]);
    const ports = provided((p) => p.ports);
    const rows = [
      ['Features', String(on.length)],
      ['Kinds', kinds.map(([kind, n]) => `${kind} ${n}`).join(', ')],
      ['Units', units.join(', ')],
      ['Listens on', ports.join(', ')],
    ].filter(([, value]) => value);
    return h(
      'section',
      { class: 'card' },
      h('h3', {}, host.name, host.local ? h('span', { text: 'this machine' }) : null),
      h('p', { class: 'path', text: host.file }),
      h('dl', {}, ...rows.flatMap(([label, value]) => [h('dt', { text: label }), h('dd', { text: value })])),
      host.problems.length
        ? h('p', { class: 'trouble', text: `The loader rejects this file: ${host.problems.join('; ')}` })
        : null,
      host.error ? h('p', { class: 'trouble', text: host.error }) : null,
    );
  }

  function featurePanel(name) {
    const f = feat(name);
    const F = S.data.catalog;
    const block = (title, ...body) => h('section', { class: 'block' }, h('h3', { text: title }), ...body);
    const chips = (names, extra) => names.map((other) => h('li', {}, chip(other, null, extra)));
    const nothing = (text) => h('p', { class: 'none', text });

    const head = [
      h(
        'header',
        {},
        h('h2', { text: name }),
        h('button', {
          type: 'button',
          class: 'close',
          'aria-label': 'Close details',
          title: 'Back to the overview',
          text: '×',
          onclick: () => select(null),
        }),
      ),
    ];
    if (!f) {
      head.push(
        h('p', {
          class: 'what',
          text: 'A features.json lists this name, but the catalog has no such feature. The loader rejects it: switch it off, or fix the name.',
        }),
      );
    } else {
      head.push(h('p', { class: 'what', text: `A ${f.kind} feature: ${KIND_GLOSS[f.kind] || f.kind}.` }));
      if (f.runtimeUntestable) {
        head.push(
          h('p', {
            class: 'what',
            text: 'Its runtime cannot be checked in a VM; the feature test only guards eval and boot.',
          }),
        );
      }
    }

    const blocks = [
      block(
        'Where it is on',
        h(
          'table',
          { class: 'where' },
          ...S.data.hosts.map((host) =>
            h(
              'tr',
              {},
              h(
                'th',
                { scope: 'row' },
                host.name,
                host.local ? h('span', { class: 'of', text: ' this machine' }) : null,
              ),
              h('td', {}, jack(host, name, 0)),
            ),
          ),
        ),
      ),
    ];
    if (f) {
      const direct = f.requires;
      const through = [...closure(name, (n) => (F[n] ? F[n].requires : []))]
        .filter((dep) => !direct.includes(dep) && dep !== name)
        .sort();
      blocks.push(
        block(
          'Requires',
          direct.length ? h('ul', { class: 'chips' }, ...chips(direct), ...chips(through, 'far')) : nothing('Nothing.'),
          through.length ? nothing('Dashed: required through the others.') : null,
        ),
      );

      const dependents = Object.keys(F)
        .filter((other) => F[other].requires.includes(name))
        .sort();
      blocks.push(
        block(
          'Required by',
          dependents.length ? h('ul', { class: 'chips' }, ...chips(dependents)) : nothing('Nothing.'),
        ),
      );

      const conflicts = Object.keys(F)
        .filter((other) => other !== name && (f.conflicts.includes(other) || F[other].conflicts.includes(name)))
        .sort();
      if (conflicts.length) {
        blocks.push(block('Cannot be on together with', h('ul', { class: 'chips' }, ...chips(conflicts))));
      }

      const p = f.provides;
      const provided = [
        ['Commands', [...p.systemBins, ...p.userBins]],
        ['Units', [...p.units, ...p.userUnits]],
        ['Ports', p.ports],
        ['Files', [...p.files, ...p.userFiles]],
      ].filter(([, list]) => list.length);
      blocks.push(
        block(
          'Puts on the system',
          provided.length
            ? h(
                'dl',
                {},
                ...provided.flatMap(([label, list]) => [h('dt', { text: label }), h('dd', { text: list.join(', ') })]),
              )
            : nothing('Nothing declared.'),
        ),
      );

      if (f.source) {
        blocks.push(
          block(
            'Source',
            h('p', { class: 'path', text: f.source }),
            f.notes ? h('p', { class: 'path', text: f.notes }) : null,
          ),
        );
      }
    }
    return [...head, h('div', { class: 'blocks' }, ...blocks)];
  }

  // ── dock ──────────────────────────────────────────────────────────────────

  function diffSpans(diff) {
    return h(
      'span',
      { class: 'diff' },
      ...diff.added.map((name) => h('span', { class: 'plus', text: ` +${name}` })),
      ...diff.removed.map((name) => h('span', { class: 'minus', text: ` −${name}` })),
    );
  }

  function renderDock() {
    const dock = $('#dock');
    const busy = Boolean(S.job && S.job.running);
    const rows = [];
    for (const host of S.data.hosts) {
      const dirty = changes(host.uncommitted) > 0;
      if (!dirty && !S.touched.has(host.name)) continue;
      rows.push(
        h(
          'div',
          { class: 'apply' },
          h('span', { class: 'who', text: host.name }),
          h(
            'span',
            { class: 'what' },
            dirty
              ? 'Saved, not committed:'
              : host.tracked
                ? 'Saved and committed.'
                : 'Saved. git has no committed version of this list to compare it with.',
            dirty ? diffSpans(host.uncommitted) : null,
          ),
          h(
            'span',
            { class: 'actions' },
            host.local
              ? [
                  h('button', {
                    type: 'button',
                    class: 'btn',
                    disabled: busy,
                    text: 'Test',
                    title: 'nh os test — activate it now, without making it the boot default',
                    onclick: () => startJob('test', host),
                  }),
                  h('button', {
                    type: 'button',
                    class: 'btn',
                    disabled: busy,
                    text: 'Switch',
                    title: 'nh os switch — activate it and make it the boot default',
                    onclick: () => startJob('switch', host),
                  }),
                ]
              : h('button', {
                  type: 'button',
                  class: 'btn',
                  disabled: busy,
                  text: 'Check the build',
                  title: `nix build --dry-run — evaluate ${host.name} without building it. Activating it happens on ${host.name}.`,
                  onclick: () => startJob('check', host),
                }),
            h('button', {
              type: 'button',
              class: 'btn',
              disabled: !dirty,
              text: 'Commit',
              title: host.tracked
                ? 'git commit of this feature list only'
                : 'This list is not in git yet — add and commit it by hand once.',
              onclick: () => commit(host),
            }),
          ),
        ),
      );
    }
    fill(
      dock,
      rows,
      h('div', { class: 'console', id: 'console', hidden: !S.job }),
      h('div', { class: 'status', id: 'status' }),
    );
    if (S.job) {
      $('#console').append(
        h(
          'header',
          {},
          h('code', { id: 'console-cmd' }),
          h('span', { class: 'state', id: 'console-state' }),
          h('button', { type: 'button', class: 'btn quiet', id: 'console-stop', text: 'Stop', onclick: stopJob }),
          h('button', {
            type: 'button',
            class: 'btn quiet',
            id: 'console-hide',
            text: 'Hide',
            onclick: () => {
              S.job = null;
              renderDock();
            },
          }),
        ),
        h('pre', { id: 'console-out', tabindex: 0, 'aria-label': 'Command output' }),
      );
      renderConsole(true);
    }
    renderStatus();
  }

  function renderConsole(toEnd) {
    const out = $('#console-out');
    if (!out || !S.job) return;
    const pinned = toEnd || out.scrollHeight - out.scrollTop - out.clientHeight < 24;
    $('#console-cmd').textContent = `$ ${S.job.command}`;
    const state = $('#console-state');
    state.textContent = S.job.running ? 'running…' : S.job.exit === 0 ? 'finished' : `failed (exit ${S.job.exit})`;
    state.className = 'state' + (S.job.running ? '' : S.job.exit === 0 ? ' ok' : ' bad');
    // Only a build check is stopped half-way; an activation runs to its end.
    $('#console-stop').hidden = !(S.job.running && S.job.action === 'check');
    $('#console-hide').hidden = S.job.running;
    out.textContent = S.jobText;
    if (pinned) out.scrollTop = out.scrollHeight;
  }

  function renderStatus() {
    const bar = $('#status');
    if (!bar || !S.data) return;
    const unsaved = unsavedHosts();
    const count = unsaved.reduce((n, host) => n + changes(diffOf(host)), 0);
    fill(
      bar,
      h('p', { class: `say ${S.say.level}`, role: 'status', text: S.say.text }),
      unsaved.length
        ? h('span', {
            class: 'pending',
            text: `${plural(count, 'unsaved change')} on ${unsaved.map((host) => host.name).join(', ')}`,
          })
        : null,
      unsaved.length
        ? h(
            'span',
            { class: 'actions' },
            h('button', { type: 'button', class: 'btn', text: 'Discard', onclick: discard }),
            h('button', { type: 'button', class: 'btn primary', text: 'Review changes', onclick: review }),
          )
        : null,
    );
  }

  // ── review ────────────────────────────────────────────────────────────────

  function review() {
    const dialog = $('#review');
    const failed = h('p', { class: 'failed', role: 'alert', hidden: true });
    fill(
      dialog,
      h(
        'div',
        { class: 'form' },
        h('h2', { id: 'review-title', text: 'Review changes' }),
        h(
          'div',
          { class: 'body' },
          h('p', {
            class: 'lead',
            text: 'Saving rewrites these feature lists. Nothing is applied or committed until you say so.',
          }),
          ...unsavedHosts().flatMap((host) => [
            h('h3', {}, host.name, h('span', { text: host.file })),
            h(
              'ul',
              { class: 'diff' },
              ...diffOf(host).added.map((name) => h('li', { class: 'plus', text: `+ ${name}` })),
              ...diffOf(host).removed.map((name) => h('li', { class: 'minus', text: `− ${name}` })),
            ),
          ]),
          failed,
        ),
        h(
          'footer',
          {},
          h('button', { type: 'button', class: 'btn', text: 'Keep editing', onclick: () => dialog.close() }),
          h('button', {
            type: 'button',
            class: 'btn primary',
            text: 'Save changes',
            autofocus: true,
            onclick: (event) => save(dialog, failed, event.currentTarget),
          }),
        ),
      ),
    );
    dialog.showModal();
  }

  // ── wiring ────────────────────────────────────────────────────────────────

  async function reload() {
    say('Evaluating the feature catalog…');
    try {
      await load(true);
      say(S.data.catalogError ? '' : 'Reloaded.');
    } catch (err) {
      say(err.message, 'error');
    }
    render();
  }

  // Arrow keys and h/j/k/l walk the matrix like the TUI's grid.
  $('#board').addEventListener('keydown', (event) => {
    const cell = event.target.closest('[data-row]');
    if (!cell || event.ctrlKey || event.metaKey || event.altKey) return;
    const step = {
      ArrowDown: [1, 0],
      j: [1, 0],
      ArrowUp: [-1, 0],
      k: [-1, 0],
      ArrowLeft: [0, -1],
      h: [0, -1],
      ArrowRight: [0, 1],
      l: [0, 1],
    }[event.key];
    if (!step) return;
    event.preventDefault();
    const row = S.rows.indexOf(cell.dataset.row) + step[0];
    const col = Math.max(-1, Math.min(Number(cell.dataset.col) + step[1], S.data.hosts.length - 1));
    if (row < 0 || row >= S.rows.length) return;
    const next = $('#board').querySelector(`[data-row="${CSS.escape(S.rows[row])}"][data-col="${col}"]`);
    if (next) next.focus();
  });

  document.addEventListener('keydown', (event) => {
    const typing = event.target instanceof Element && event.target.matches('input, select, textarea');
    if (event.key === '/' && !typing && !$('#review').open) {
      event.preventDefault();
      $('#query').focus();
    } else if (event.key === 'Escape' && event.target === $('#query')) {
      $('#query').value = '';
      S.query = '';
      renderBoard();
      $('#board').focus();
    }
  });

  $('#query').addEventListener('input', (event) => {
    S.query = event.target.value;
    renderBoard();
  });
  $('#show').addEventListener('change', (event) => {
    S.show = event.target.value;
    renderBoard();
  });
  $('#group').addEventListener('change', (event) => {
    S.group = event.target.value;
    renderBoard();
  });
  $('#reload').addEventListener('click', reload);
  for (const tab of document.querySelectorAll('.tab')) {
    tab.addEventListener('click', () => {
      S.view = tab.dataset.view;
      for (const other of document.querySelectorAll('.tab')) other.setAttribute('aria-pressed', String(other === tab));
      renderBoard();
    });
  }

  window.addEventListener('beforeunload', (event) => {
    if (S.data && unsavedHosts().length) event.preventDefault();
  });
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden) refresh();
  });
  // Also what tells the server a page is still open (its idle shutdown).
  setInterval(refresh, 20000);

  (async () => {
    try {
      await load(false);
      $('#repo').textContent = S.data.repo;
      $('#repo').title = S.data.repo;
      render();
      // A build started before this page was (re)loaded is still worth watching.
      const res = await api('/api/job');
      if (res.job && res.job.running) {
        adoptJob(res.job);
        renderDock();
        followJob();
      }
    } catch (err) {
      $('#board').replaceChildren(h('p', { class: 'empty', role: 'alert', text: err.message }));
    }
  })();
})();
