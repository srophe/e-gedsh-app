# e-GEDSH App

Electronic edition of the Gorgias Encyclopedic Dictionary of the Syriac Heritage (e-GEDSH) by Beth Mardutho.

All publications are made available online in a free and open format using Creative Commons licenses.

## Features

- Static HTML site with client-side search
- Search by keyword, person name, place name, contributor, bibliography, and URI
- Pagination support (20 results per page)
- CloudFront CDN distribution
- GitHub Actions CI/CD deployment

## Project Structure

```
e-gedsh-app/
├── index.html              # Homepage
├── search.html             # Search interface
├── resources/
│   ├── css/               # Stylesheets
│   ├── js/
│   │   ├── search.js      # Search functionality
│   │   └── footer.js      # Footer component
│   └── img/               # Images
├── json/
│   ├── combined.json      # Aggregated search data
│   └── *.json            # Individual entry files
└── infrastructure/
    ├── cloudformation.yml # AWS infrastructure
    └── README.md          # Deployment guide
```

## Local Development

1. Clone the repository
2. Open `index.html` in a browser
3. For search functionality, serve via local web server:
Ex.
   ```bash
   python -m http.server 8000
   ```
4. Navigate to `http://localhost:8000`

## Search Data

Search data is sourced from [e-gedsh](https://github.com/srophe/e-gedsh) repository and combined into `json/combined.json`.

### JSON Structure
```json
{
  "fullText": "...",
  "title": "...",
  "idno": "https://gedsh.bethmardutho.org/...",
  "displayTitleEnglish": "...",
  "persName": ["..."],
  "placeName": ["..."]
}
```

## Deployment

See [infrastructure/README.md](infrastructure/README.md) for AWS deployment instructions.

## License

Content licensed under Creative Commons. See footer for details.
