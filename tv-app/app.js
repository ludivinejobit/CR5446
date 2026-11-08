// Ma TV Libre — application web pour TV connectée / navigateur.
// Sources : playlists publiques iptv-org (chaînes en accès libre),
// Internet Archive (films du domaine public), plateformes officielles gratuites.
'use strict';

const IPTV = 'https://iptv-org.github.io';
const $ = (s) => document.querySelector(s);

const PLATFORMS = [
  { name: 'france.tv', desc: 'Direct + replay France Télévisions, films', url: 'https://www.france.tv' },
  { name: 'ARTE', desc: 'Films, documentaires, direct (FR/DE)', url: 'https://www.arte.tv/fr/' },
  { name: 'TF1+', desc: 'Direct TF1, TMC, TFX… + films gratuits', url: 'https://www.tf1.fr' },
  { name: 'M6+', desc: 'Direct M6, W9, 6ter… + replay', url: 'https://www.6play.fr' },
  { name: 'Pluto TV', desc: 'Chaînes thématiques et films gratuits', url: 'https://pluto.tv/fr' },
  { name: 'Rakuten TV', desc: 'Films gratuits avec publicité', url: 'https://www.rakuten.tv/fr' },
  { name: 'Plex', desc: 'Films et chaînes gratuits (FAST)', url: 'https://watch.plex.tv/fr' },
  { name: 'Samsung TV Plus', desc: 'Chaînes gratuites (TV Samsung / web)', url: 'https://www.samsungtvplus.com' },
  { name: 'LG Channels', desc: 'Chaînes gratuites (TV LG)', url: 'https://www.lg.com/fr/lg-channels/' },
  { name: 'YouTube', desc: 'Films gratuits avec pub (section Films)', url: 'https://www.youtube.com/feed/storefront' },
  { name: 'Internet Archive', desc: 'Milliers de films du domaine public', url: 'https://archive.org/details/feature_films' },
  { name: 'Molotov (offre gratuite)', desc: 'Chaînes TNT en direct, appli TV', url: 'https://www.molotov.tv' },
  { name: 'Rakuten Viki', desc: 'Séries asiatiques gratuites avec pub', url: 'https://www.viki.com' },
  { name: 'HENRI – Cinémathèque', desc: 'Films rares et restaurés, gratuits', url: 'https://www.cinematheque.fr/henri/' },
  { name: 'Médiathèque numérique', desc: 'Films gratuits avec votre carte de bibliothèque', url: 'https://www.mediatheque-numerique.com' },
  { name: 'Euronews / France 24', desc: 'Info en continu, multilingue', url: 'https://www.france24.com/fr/direct' },
];

let allChannels = [];
let hls = null;
let currentUrl = '';

// ---------- Utilitaires ----------
function el(tag, attrs = {}, ...children) {
  const n = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === 'onclick') n.addEventListener('click', v);
    else n.setAttribute(k, v);
  }
  for (const c of children) n.append(c);
  return n;
}

function parseM3U(text) {
  const lines = text.split(/\r?\n/);
  const out = [];
  let info = null;
  for (const raw of lines) {
    const line = raw.trim();
    if (line.startsWith('#EXTINF')) {
      const attr = (k) => (line.match(new RegExp(k + '="([^"]*)"')) || [])[1] || '';
      info = {
        name: line.slice(line.lastIndexOf(',') + 1).trim(),
        logo: attr('tvg-logo'),
        group: attr('group-title') || 'Autres',
      };
    } else if (line && !line.startsWith('#') && info) {
      const res = info.name.match(/\((\d{3,4})p\)/);
      out.push({ ...info, height: res ? Number(res[1]) : 0, url: line });
      info = null;
    }
  }
  return out;
}

// ---------- Chaînes TV ----------
async function loadCountries() {
  const sel = $('#country');
  try {
    const res = await fetch(`${IPTV}/api/countries.json`);
    const countries = (await res.json()).sort((a, b) => a.name.localeCompare(b.name));
    for (const c of countries) sel.append(el('option', { value: c.code.toLowerCase() }, `${c.flag || ''} ${c.name}`));
  } catch {
    for (const [code, name] of [['fr', 'France'], ['be', 'Belgique'], ['ch', 'Suisse'], ['ca', 'Canada'], ['us', 'États-Unis'], ['gb', 'Royaume-Uni'], ['de', 'Allemagne'], ['es', 'Espagne'], ['it', 'Italie'], ['ma', 'Maroc']]) {
      sel.append(el('option', { value: code }, name));
    }
  }
  sel.prepend(
    el('option', { value: 'categories/movies' }, '🎬 Chaînes Films 24h/24 (monde)'),
    el('option', { value: 'categories/series' }, '📺 Chaînes Séries 24h/24 (monde)'),
    el('option', { value: 'languages/fra' }, '🇫🇷 Chaînes en français (tous pays)'),
    el('option', { value: 'ALL' }, '🌍 Monde entier (très long)'));
  sel.value = 'fr';
  sel.addEventListener('change', () => loadPlaylist(sel.value));
  loadPlaylist('fr');
}

async function loadPlaylist(code) {
  const url = code === 'ALL' ? `${IPTV}/iptv/index.m3u`
    : code.includes('/') ? `${IPTV}/iptv/${code}.m3u`
    : `${IPTV}/iptv/countries/${code}.m3u`;
  $('#tvStatus').textContent = 'Chargement des chaînes…';
  try {
    const res = await fetch(url);
    if (!res.ok) throw new Error(res.status);
    setChannels(parseM3U(await res.text()));
  } catch (e) {
    $('#tvStatus').textContent = `Impossible de charger la liste (${e.message}). Vérifiez votre connexion.`;
  }
}

function setChannels(list) {
  allChannels = list;
  const cat = $('#category');
  const groups = [...new Set(list.flatMap((c) => c.group.split(';')))].sort();
  cat.replaceChildren(el('option', { value: '' }, 'Toutes'), ...groups.map((g) => el('option', { value: g }, g)));
  renderChannels();
}

function renderChannels() {
  const q = $('#search').value.toLowerCase();
  const g = $('#category').value;
  const minQ = Number($('#quality').value);
  const list = allChannels
    .filter((c) => c.name.toLowerCase().includes(q) && (!g || c.group.split(';').includes(g)) && c.height >= minQ)
    .sort((a, b) => b.height - a.height || a.name.localeCompare(b.name));
  $('#tvStatus').textContent = `${list.length} chaîne(s)${minQ ? ` en ${minQ}p ou plus` : ''}. Certaines peuvent être indisponibles ou géo-restreintes.`
    + (minQ && !list.length && allChannels.length ? ' Essayez « 720p et plus » ou « Toutes ».' : '');
  const frag = document.createDocumentFragment();
  for (const c of list.slice(0, 1500)) {
    frag.append(el('button', { class: 'card', onclick: () => playStream(c.name, c.url) },
      el('img', { src: c.logo || 'data:,', alt: '', loading: 'lazy' }),
      el('span', { class: 'name' }, c.name.replace(/\s*\(\d{3,4}p\)/, '')),
      el('span', { class: 'meta' }, c.height ? el('span', { class: 'badge' }, c.height >= 2160 ? '4K' : c.height >= 1080 ? 'Full HD' : `${c.height}p`) : '', ` ${c.group}`)));
  }
  $('#channels').replaceChildren(frag);
}

// ---------- Films du domaine public ----------
let filmPage = 1;

async function searchFilms(more = false) {
  filmPage = more ? filmPage + 1 : 1;
  const q = $('#filmSearch').value.trim().replace(/[()"]/g, ' ');
  const parts = [`collection:(${$('#filmCollection').value})`, 'mediatype:(movies)'];
  if ($('#filmFrench').checked) parts.push('language:(French OR fre OR fra OR Français)');
  if (q) parts.push(`title:(${q})`);
  const url = `https://archive.org/advancedsearch.php?q=${encodeURIComponent(parts.join(' AND '))}`
    + `&fl[]=identifier&fl[]=title&fl[]=year&sort[]=downloads+desc&rows=60&page=${filmPage}&output=json`;
  const box = $('#films');
  const more_ = $('#filmMore');
  if (!more) box.replaceChildren(el('p', { class: 'status' }, 'Recherche…'));
  more_.hidden = true;
  try {
    const data = await (await fetch(url)).json();
    const docs = data.response.docs;
    const frag = document.createDocumentFragment();
    for (const d of docs) {
      frag.append(el('button', { class: 'card', onclick: () => playEmbed(d.title, `https://archive.org/embed/${d.identifier}`) },
        el('img', { src: `https://archive.org/services/img/${d.identifier}`, alt: '', loading: 'lazy' }),
        el('span', { class: 'name' }, d.title),
        el('span', { class: 'meta' }, d.year || '')));
    }
    if (!more) box.replaceChildren();
    if (!docs.length && !more) box.append(el('p', { class: 'status' }, 'Aucun résultat.'));
    box.append(frag);
    more_.hidden = filmPage * 60 >= data.response.numFound;
  } catch {
    if (!more) box.replaceChildren(el('p', { class: 'status' }, 'Recherche indisponible pour le moment.'));
  }
}

// ---------- Plateformes ----------
function renderPlatforms() {
  $('#platforms').replaceChildren(...PLATFORMS.map((p) =>
    el('a', { class: 'card', href: p.url, target: '_blank', rel: 'noopener' },
      el('span', { class: 'name' }, p.name), el('span', { class: 'meta' }, p.desc))));
}

// ---------- Lecteur ----------
function openPlayer(title) {
  $('#playerTitle').textContent = title;
  $('#playerError').textContent = '';
  $('#player').classList.remove('hidden');
  $('#closePlayer').focus();
}

function playStream(title, url) {
  stopPlayer();
  currentUrl = url;
  openPlayer(title);
  const video = $('#video');
  video.style.display = 'block';
  $('#frame').style.display = 'none';
  const fail = () => { $('#playerError').textContent = 'Flux indisponible dans le navigateur. Essayez « Copier l\'URL » puis ouvrez-la dans VLC.'; };
  if (window.Hls && Hls.isSupported() && /\.m3u8/i.test(url)) {
    hls = new Hls();
    hls.on(Hls.Events.ERROR, (_, d) => d.fatal && fail());
    hls.loadSource(url);
    hls.attachMedia(video);
  } else {
    video.src = url; // Safari / TV avec HLS natif, ou MP4
    video.onerror = fail;
  }
  video.play().catch(() => {});
}

function playEmbed(title, url) {
  stopPlayer();
  currentUrl = url;
  openPlayer(title);
  $('#video').style.display = 'none';
  const f = $('#frame');
  f.style.display = 'block';
  f.src = url;
}

function stopPlayer() {
  if (hls) { hls.destroy(); hls = null; }
  const v = $('#video');
  v.pause(); v.removeAttribute('src'); v.load();
  $('#frame').src = 'about:blank';
}

function closePlayer() {
  stopPlayer();
  $('#player').classList.add('hidden');
  if (document.fullscreenElement) document.exitFullscreen();
}

// ---------- Navigation (télécommande / clavier) ----------
function setupNavigation() {
  document.querySelectorAll('.tab').forEach((t) => t.addEventListener('click', () => {
    document.querySelectorAll('.tab').forEach((x) => x.classList.toggle('active', x === t));
    document.querySelectorAll('.view').forEach((v) => v.classList.toggle('active', v.id === `view-${t.dataset.view}`));
    if (t.dataset.view === 'films' && !$('#films').children.length) searchFilms();
  }));

  document.addEventListener('keydown', (e) => {
    // Touches retour des télécommandes (Tizen 10009, webOS 461)
    if (['Escape', 'Backspace', 'BrowserBack'].includes(e.key) || [10009, 461].includes(e.keyCode)) {
      if (!$('#player').classList.contains('hidden') && document.activeElement.tagName !== 'INPUT') {
        e.preventDefault(); closePlayer();
      }
      return;
    }
    const dirs = { ArrowRight: [1, 0], ArrowLeft: [-1, 0], ArrowDown: [0, 1], ArrowUp: [0, -1] };
    const d = dirs[e.key];
    const cur = document.activeElement;
    if (!d || !cur || !cur.classList.contains('card')) return;
    const cards = [...cur.parentElement.children];
    const cols = Math.max(1, Math.round(cur.parentElement.clientWidth / cur.offsetWidth));
    const next = cards[cards.indexOf(cur) + d[0] + d[1] * cols];
    if (next) { e.preventDefault(); next.focus(); next.scrollIntoView({ block: 'nearest' }); }
  });

  $('#search').addEventListener('input', renderChannels);
  $('#category').addEventListener('change', renderChannels);
  $('#quality').addEventListener('change', renderChannels);
  $('#filmGo').addEventListener('click', () => searchFilms());
  $('#filmMore').addEventListener('click', () => searchFilms(true));
  $('#filmCollection').addEventListener('change', () => searchFilms());
  $('#filmFrench').addEventListener('change', () => searchFilms());
  $('#filmSearch').addEventListener('keydown', (e) => e.key === 'Enter' && searchFilms());
  $('#closePlayer').addEventListener('click', closePlayer);
  $('#fullscreen').addEventListener('click', () => $('#player').requestFullscreen?.());
  $('#copyUrl').addEventListener('click', () => navigator.clipboard?.writeText(currentUrl).then(() => { $('#copyUrl').textContent = 'Copié ✓'; setTimeout(() => ($('#copyUrl').textContent = "Copier l'URL"), 1500); }));
  $('#m3uFile').addEventListener('change', async (e) => {
    const f = e.target.files[0];
    if (f) setChannels(parseM3U(await f.text()));
  });
}

setupNavigation();
renderPlatforms();
loadCountries();
