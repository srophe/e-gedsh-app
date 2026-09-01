let searchData = [];
let allResults = [];
let currentPage = 1;
const perPage = 20;

fetch('/json/combined.json')
  .then(response => response.json())
  .then(data => { 
    searchData = data;
    processUrlParams();
  });

function extractContributor(persName) {
  if (!Array.isArray(persName) || !persName.length) return '';
  return persName[persName.length - 1].replace(/\s+/g, ' ').trim();
}

function extractDate(fullText) {
  if (!fullText) return '';
  const m = fullText.match(/\b(?:person|place|work)\b[^()]*(\([^)]+\))/);
  return m ? m[1].replace(/\s+/g, ' ').replace(/\(\s+/, '(').replace(/\s+\)/, ')') : '';
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
    const contributor = extractContributor(entry.persName);
    const date = extractDate(entry.fullText);
    return `
    <div class="search-result" style="margin-bottom:1.5em;border-bottom:1px solid #eee;padding-bottom:1em;">
      <h3><a href="${entry.uri}">${entry.title || entry.displayTitleEnglish}</a>${date ? ` ${date}` : ''}</h3>
      ${contributor ? `<p>Contributor: ${contributor}</p>` : ''}
      <p>URI: <a href="${entry.uri}">${entry.uri || ''}</a></p>
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
    uri: urlParams.get('uri'),
    title: urlParams.get('title')
  };
  
  const fieldMap = {
    q: { id: ['q', 'qs'], field: 'all' },
    persName: { id: ['persName'], field: 'persName' },
    placeName: { id: ['placeName'], field: 'placeName' },
    uri: { id: ['uri'], field: 'all' },
    title: { id: ['title'], field: 'title' }
  };
  
  let combinedResults = [];
  for (const [param, value] of Object.entries(params)) {
    if (value) {
      const config = fieldMap[param];
      const input = config.id.map(id => document.getElementById(id)).find(el => el);
      if (input) input.value = value;
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
