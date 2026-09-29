let searchData = [];
let allResults = [];
let currentPage = 1;
const perPage = 20;
// Query terms currently being searched, used to highlight matches in results.
let activeTerms = [];
// Number of characters of context to show on each side of a match in the snippet.
const snippetContext = 120;

fetch('/json/combined.json')
  .then(response => response.json())
  .then(data => { 
    searchData = data;
    processUrlParams();
  });

function getContributor(entry) {
  // Prefer the dedicated contributor field emitted from the TEI author/byline.
  if (entry.contributor) return entry.contributor.replace(/\s+/g, ' ').trim();
  // Fallback for older JSON: last persName entry.
  const persName = entry.persName;
  if (!Array.isArray(persName) || !persName.length) return '';
  return persName[persName.length - 1].replace(/\s+/g, ' ').trim();
}

function getDate(entry) {
  // Prefer the dedicated infobox field, e.g. "(ca. 400)" or "(d. 552) [Ch. of E.]".
  if (entry.infobox) return entry.infobox.replace(/\s+/g, ' ').replace(/\(\s+/, '(').replace(/\s+\)/, ')').trim();
  // Fallback for older JSON: scrape the date out of fullText.
  const fullText = entry.fullText;
  if (!fullText) return '';
  const m = fullText.match(/\b(?:person|place|work)\b[^()]*(\([^)]+\))/);
  return m ? m[1].replace(/\s+/g, ' ').replace(/\(\s+/, '(').replace(/\s+\)/, ')') : '';
}

// Escape text for safe insertion into HTML.
function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// Escape a string for use as a literal inside a RegExp.
function escapeRegExp(str) {
  return String(str).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// Transliteration marks (Syriac ʿayn/alaph and various apostrophes/quotes) that
// searching should ignore, so e.g. "Abdisho" matches "ʿAbdishoʿ".
const IGNORED_MARKS = /[ʿʾ'’‘`´ʼʻ]/g;

// Fold a single character to its search-normalized form: lowercase, strip
// combining diacritics, and drop ignored transliteration marks. Returns a
// string because one source char can fold to zero chars (a mark) or several.
function foldChar(ch) {
  return ch
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(IGNORED_MARKS, '');
}

// Fold a whole string for diacritic/punctuation-insensitive comparison.
function foldText(str) {
  return String(str)
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(IGNORED_MARKS, '');
}

// Fold a string and build a map from each folded-index to the original-string
// index it came from, so matches found in the folded text can be located back
// in the original for highlighting.
function foldWithMap(str) {
  let folded = '';
  const map = [];
  for (let i = 0; i < str.length; i++) {
    const f = foldChar(str[i]);
    for (let j = 0; j < f.length; j++) map.push(i);
    folded += f;
  }
  // Sentinel so map[folded.length] resolves to the end of the string.
  map.push(str.length);
  return { folded, map };
}

// Turn a user query into a RegExp source that matches on folded text.
// Supports "*" (any run of characters), "?" (a single character), and treats
// a query wrapped in double quotes as an exact phrase. All other characters
// are matched literally (regex-escaped).
function queryToRegExpSource(query) {
  let q = query.trim();
  // A quoted query is an exact phrase; strip the surrounding quotes. Inner
  // wildcards still apply.
  if (q.length >= 2 && q.startsWith('"') && q.endsWith('"')) {
    q = q.slice(1, -1);
  }
  const folded = foldText(q);
  let src = '';
  for (const ch of folded) {
    if (ch === '*') src += '.*';
    else if (ch === '?') src += '.';
    else src += escapeRegExp(ch);
  }
  return src;
}

// Does the folded form of `text` contain a match for `query`?
function foldedMatches(text, query) {
  if (typeof text !== 'string') return false;
  const src = queryToRegExpSource(query);
  if (!src) return false;
  return new RegExp(src, 'i').test(foldText(text));
}

// Build one RegExp (matching on folded text) from all active terms, for
// locating matches to highlight. Returns null when there is nothing to match.
function buildHighlightRegExp() {
  const parts = activeTerms
    .map(queryToRegExpSource)
    .filter(Boolean)
    // Longest sources first so overlapping matches prefer the fuller term.
    .sort((a, b) => b.length - a.length);
  if (!parts.length) return null;
  return new RegExp('(' + parts.join('|') + ')', 'gi');
}

// Wrap matches of the active search terms in the ORIGINAL text with <mark>,
// locating them via the folded text + index map, then HTML-escaping each
// segment. Returns HTML that is safe to inject.
function highlightOriginal(text) {
  const re = buildHighlightRegExp();
  if (!re) return escapeHtml(text);
  const { folded, map } = foldWithMap(text);
  let out = '';
  let lastOrig = 0;
  let m;
  while ((m = re.exec(folded)) !== null) {
    // Skip zero-width matches (e.g. a lone "*") to avoid an infinite loop.
    if (m[0].length === 0) { re.lastIndex++; continue; }
    const origStart = map[m.index];
    const origEnd = map[m.index + m[0].length];
    out += escapeHtml(text.slice(lastOrig, origStart));
    out += '<mark style="background-color:#deda10;color:#000;">'
      + escapeHtml(text.slice(origStart, origEnd)) + '</mark>';
    lastOrig = origEnd;
  }
  out += escapeHtml(text.slice(lastOrig));
  return out;
}

// Build a fullText snippet centered on the first matching term, with the
// matched terms highlighted. Returns '' when there is no fullText.
function buildSnippet(entry) {
  const fullText = (entry.fullText || '').replace(/\s+/g, ' ').trim();
  if (!fullText) return '';

  let start = 0;
  let end = Math.min(fullText.length, snippetContext * 2);

  const re = buildHighlightRegExp();
  if (re) {
    const { folded, map } = foldWithMap(fullText);
    const m = re.exec(folded);
    if (m && m[0].length) {
      const origIdx = map[m.index];
      start = Math.max(0, origIdx - snippetContext);
      end = Math.min(fullText.length, origIdx + snippetContext);
    }
  }

  let snippet = fullText.slice(start, end);
  const prefix = start > 0 ? '… ' : '';
  const suffix = end < fullText.length ? ' …' : '';

  // Highlight within the snippet (prefix/suffix are added un-highlighted).
  return prefix + highlightOriginal(snippet) + suffix;
}

function performSearch(query, field = 'all') {
  if (!query) return [];
  // Require at least two non-wildcard characters to avoid matching everything.
  if (foldText(query).replace(/[*?"]/g, '').length < 2) return [];
  return searchData.filter(entry => {
    if (field === 'all') {
      return Object.values(entry).some(value => {
        if (typeof value === 'string') return foldedMatches(value, query);
        if (Array.isArray(value)) return value.some(v => foldedMatches(v, query));
        return false;
      });
    }
    const fieldValue = entry[field];
    if (typeof fieldValue === 'string') return foldedMatches(fieldValue, query);
    if (Array.isArray(fieldValue)) return fieldValue.some(v => foldedMatches(v, query));
    return false;
  });
}

function displayResults(page = 1) {
  const container = document.getElementById('search-results');
  if (!container) return;
  
  if (allResults.length === 0) {
    container.innerHTML = '<div class="well well-small">'
      + '<p style="margin:0;"><strong>Results: 0</strong></p>'
      + '<p style="margin:.5em 0 0;">No results found. Try different or fewer search terms.</p>'
      + '</div>';
    return;
  }
  
  const start = (page - 1) * perPage;
  const end = start + perPage;
  const pageResults = allResults.slice(start, end);
  const totalPages = Math.ceil(allResults.length / perPage);
  
  let paginationNav = '';
  if (totalPages > 1) {
    paginationNav = '<nav style="display:inline-block;margin-left:20px;"><ul class="pagination" style="margin:0;">';
    if (page > 1) paginationNav += `<li><a href="#" onclick="changePage(${page - 1}); return false;">&laquo;</a></li>`;
    for (let i = 1; i <= totalPages; i++) {
      if (i === page) paginationNav += `<li class="active"><a href="#">${i}</a></li>`;
      else paginationNav += `<li><a href="#" onclick="changePage(${i}); return false;">${i}</a></li>`;
    }
    if (page < totalPages) paginationNav += `<li><a href="#" onclick="changePage(${page + 1}); return false;">&raquo;</a></li>`;
    paginationNav += '</ul></nav>';
  }
  
  let html = `<div style="display:flex;align-items:center;justify-content:space-between;"><p style="margin:0;">Found ${allResults.length} results (showing ${start + 1}-${Math.min(end, allResults.length)})</p>${paginationNav}</div>`;
  
  html += pageResults.map(entry => {
    const contributor = getContributor(entry);
    const date = getDate(entry);
    const uri = entry.idno || entry.uri || '';
    const snippet = buildSnippet(entry);
    return `
    <div class="search-result" style="margin-bottom:1.5em;border-bottom:1px solid #eee;padding-bottom:1em;">
      <h3><a href="${uri}">${entry.title || entry.displayTitleEnglish}</a>${date ? ` ${date}` : ''}</h3>
      ${contributor ? `<p>Contributor: ${contributor}</p>` : ''}
      <p>URI: <a href="${uri}">${uri}</a></p>
      ${snippet ? `<p class="search-snippet" style="color:#333;">${snippet}</p>` : ''}
      
    </div>
  `;
  }).join('');
  
  if (totalPages > 1) {
    html += paginationNav.replace('display:inline-block;margin-left:20px;', '').replace('margin:0;', '');
  }
  
  container.innerHTML = html;
}

function changePage(page) {
  currentPage = page;
  displayResults(page);
  window.scrollTo(0, document.getElementById('search-results').offsetTop - 100);
}

function processUrlParams() {
  const urlParams = new URLSearchParams(window.location.search);
  const params = {
    q: urlParams.get('q'),
    persName: urlParams.get('persName'),
    placeName: urlParams.get('placeName'),
    contributor: urlParams.get('contributor'),
    uri: urlParams.get('uri'),
    title: urlParams.get('title')
  };
  
  const fieldMap = {
    q: { id: ['q', 'qs'], field: 'all' },
    persName: { id: ['persName'], field: 'persName' },
    placeName: { id: ['placeName'], field: 'placeName' },
    contributor: { id: ['contributor'], field: 'contributor' },
    uri: { id: ['uri'], field: 'all' },
    title: { id: ['title'], field: 'title' }
  };
  
  // Reset the terms highlighted in result snippets for this search.
  activeTerms = [];

  let combinedResults = [];
  let searched = false;
  for (const [param, value] of Object.entries(params)) {
    if (value) {
      searched = true;
      const config = fieldMap[param];
      const input = config.id.map(id => document.getElementById(id)).find(el => el);
      if (input) input.value = value;
      // Highlight the query in the fullText snippet, except for URI lookups.
      if (param !== 'uri') {
        const term = value.trim();
        if (term.length >= 2) activeTerms.push(term);
      }
      const results = performSearch(value, config.field);
      combinedResults = combinedResults.length ? combinedResults.filter(r => results.includes(r)) : results;
    }
  }
  
  // Render whenever a search was actually run, so a zero-match search still
  // shows the "no results" message instead of leaving the page blank.
  if (searched) {
    allResults = combinedResults;
    displayResults(1);
  }
}

// Clear the search form inputs, rendered results, in-memory state, and the
// query string in the URL. Wired to the "Clear" button on the search form.
function clearSearch() {
  // Empty every field the search form uses.
  ['q', 'qs', 'persName', 'placeName', 'contributor', 'uri', 'title'].forEach(function (id) {
    const el = document.getElementById(id);
    if (el) el.value = '';
  });

  // Clear rendered results and reset in-memory state.
  const container = document.getElementById('search-results');
  if (container) container.innerHTML = '';
  allResults = [];
  activeTerms = [];
  currentPage = 1;

  // Strip the query string from the URL without reloading the page.
  window.history.replaceState({}, document.title, window.location.pathname);
}

document.addEventListener('DOMContentLoaded', function () {
  processUrlParams();

  // The Clear button is a native form reset; also clear results and the URL.
  const resetBtn = document.querySelector('form[role="form"] button[type="reset"]');
  if (resetBtn) {
    resetBtn.addEventListener('click', function () {
      // Defer so this runs after the browser's native form reset.
      window.setTimeout(clearSearch, 0);
    });
  }
});
