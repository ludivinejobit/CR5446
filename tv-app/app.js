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
      out.push({ ...info, url: line });
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
  sel.prepend(el('option', { value: 'ALL' }, '🌍 Monde entier (très long)'));
  sel.value = 'fr';
  sel.addEventListener('change', () => loadPlaylist(sel.value));
  loadPlaylist('fr');
}

async function loadPlaylist(code) {
  const url = code === 'ALL' ? `${IPTV}/iptv/index.m3u` : `${IPTV}/iptv/countries/${code}.m3u`;
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
  const list = allChannels.filter((c) => c.name.toLowerCase().includes(q) && (!g || c.group.split(';').includes(g)));
  $('#tvStatus').textContent = `${list.length} chaîne(s). Certaines peuvent être indisponibles ou géo-restreintes.`;
  const frag = document.createDocumentFragment();
  for (const c of list.slice(0, 1500)) {
    frag.append(el('button', { class: 'card', onclick: () => playStream(c.name, c.url) },
      el('img', { src: c.logo || 'data:,', alt: '', loading: 'lazy' }),
      el('span', { class: 'name' }, c.name),
      el('span', { class: 'meta' }, c.group)));
  }
  $('#channels').replaceChildren(frag);
}

// ---------- Films du domaine public ----------
async function searchFilms() {
  const q = $('#filmSearch').value.trim();
  const query = `collection:(feature_films) AND mediatype:(movies)${q ? ` AND title:(${q})` : ''}`;
  const url = `https://archive.org/advancedsearch.php?q=${encodeURIComponent(query)}&fl[]=identifier&fl[]=title&fl[]=year&sort[]=downloads+desc&rows=60&output=json`;
  $('#films').replaceChildren(el('p', { class: 'status' }, 'Recherche…'));
  try {
    const data = await (await fetch(url)).json();
    const frag = document.createDocumentFragment();
    for (const d of data.response.docs) {
      frag.append(el('button', { class: 'card', onclick: () => playEmbed(d.title, `https://archive.org/embed/${d.identifier}`) },
        el('img', { src: `https://archive.org/services/img/${d.identifier}`, alt: '', loading: 'lazy' }),
        el('span', { class: 'name' }, d.title),
        el('span', { class: 'meta' }, d.year || '')));
    }
    $('#films').replaceChildren(frag.childNodes.length ? frag : el('p', { class: 'status' }, 'Aucun résultat.'));
  } catch {
    $('#films').replaceChildren(el('p', { class: 'status' }, 'Recherche indisponible pour le moment.'));
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
  $('#filmGo').addEventListener('click', searchFilms);
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
