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

// Wrap occurrences of the active search terms in <mark> tags.
// Operates on already HTML-escaped text so the result is safe to inject.
function highlightTerms(escapedText) {
  if (!activeTerms.length) return escapedText;
  // Longest terms first so overlapping matches prefer the fuller term.
  const parts = activeTerms
    .slice()
    .sort((a, b) => b.length - a.length)
    .map(escapeRegExp);
  const re = new RegExp(`(${parts.join('|')})`, 'gi');
  return escapedText.replace(re, '<mark>$1</mark>');
}

// Build a fullText snippet centered on the first matching term, with the
// matched terms highlighted. Returns '' when there is no fullText.
function buildSnippet(entry) {
  const fullText = (entry.fullText || '').replace(/\s+/g, ' ').trim();
  if (!fullText) return '';

  let start = 0;
  let end = Math.min(fullText.length, snippetContext * 2);

  if (activeTerms.length) {
    const lower = fullText.toLowerCase();
    let idx = -1;
    for (const term of activeTerms) {
      const found = lower.indexOf(term.toLowerCase());
      if (found !== -1 && (idx === -1 || found < idx)) idx = found;
    }
    if (idx !== -1) {
      start = Math.max(0, idx - snippetContext);
      end = Math.min(fullText.length, idx + snippetContext);
    }
  }

  let snippet = fullText.slice(start, end);
  if (start > 0) snippet = '… ' + snippet;
  if (end < fullText.length) snippet = snippet + ' …';

  return highlightTerms(escapeHtml(snippet));
}

function performSearch(query, field = 'all') {
  if (!query || query.length < 2) return [];
  const lowerQuery = query.toLowerCase();
  console.log("search", query);
  return searchData.filter(entry => {
    if (field === 'all') {
      return Object.values(entry).some(value => {
        if (typeof value === 'string') return value.toLowerCase().includes(lowerQuery);
        if (Array.isArray(value)) return value.some(v => v.toLowerCase().includes(lowerQuery));
        return false;
      });
    } else {
      console.log("entry field", entry, field)
      const fieldValue = entry[field];
      if (typeof fieldValue === 'string') return fieldValue.toLowerCase().includes(lowerQuery);
      if (Array.isArray(fieldValue)) return fieldValue.some(v => v.toLowerCase().includes(lowerQuery));
      return false;
    }
  });
}

function displayResults(page = 1) {
  const container = document.getElementById('search-results');
  if (!container) return;
  
  if (allResults.length === 0) {
    container.innerHTML = '<p>No results found.</p>';
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
  for (const [param, value] of Object.entries(params)) {
    if (value) {
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
  
  if (combinedResults.length) {
    allResults = combinedResults;
    displayResults(1);
  }
}

document.addEventListener('DOMContentLoaded', processUrlParams);
