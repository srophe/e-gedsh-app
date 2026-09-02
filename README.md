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
├── siteGenerator/
│   ├── build-json.sh      # Local TEI → JSON build script
│   ├── xsl/json.xsl       # TEI → JSON transform (XSLT)
│   └── components/
│       └── repo-config.xml # Search field configuration
└── infrastructure/
    ├── cloudformation.yml # AWS infrastructure
    └── README.md          # Deployment guide
```

## Local Development

### Static Site (Recommended)

The simplest way to run e-GEDSH locally is as a static site:

1. Clone the repository:
   ```bash
   git clone https://github.com/srophe/e-gedsh-app.git
   cd e-gedsh-app
   ```

2. Start a local web server:

   Using Python:
   ```bash
   python3 -m http.server 8000
   ```

   Using Node.js:
   ```bash
   npx serve -l 8000
   ```

3. Navigate to http://localhost:8000

Search works out of the box using the bundled `json/combined.json` file — no backend required.

### eXist-db (Legacy)

The app can also run on eXist-db for full XQuery functionality (SPARQL proxy, content negotiation, OAI-PMH):

1. Install [eXist-db](http://exist-db.org/) (version 5.x or later)

2. Build the XAR package:
   ```bash
   ant xar
   ```
   This creates `build/e-gedsh-<version>.xar`

3. Deploy via eXist-db Package Manager:
   - Open the eXist-db Dashboard at http://localhost:8080/exist/apps/dashboard
   - Go to Package Manager → Upload and select the `.xar` file
   - Also install the `e-gedsh-data` package from the [e-gedsh](https://github.com/srophe/e-gedsh) repository

4. Access the app at http://localhost:8080/exist/apps/e-gedsh

### Docker (eXist-db)

To run the eXist-db version in a container:

1. Build the XAR package first:
   ```bash
   ant xar
   mkdir -p autodeploy
   cp build/*.xar autodeploy/
   ```

2. Build and run the Docker image:
   ```bash
   docker build --build-arg ADMIN_PASSWORD=<password> -t e-gedsh .
   docker run -d -p 8080:8080 --name e-gedsh e-gedsh
   ```

3. Access the app at http://localhost:8080/exist/apps/e-gedsh

## Search Data

Search data is sourced from the [e-gedsh](https://github.com/srophe/e-gedsh) repository (TEI XML) and transformed into per-entry JSON files plus an aggregated `json/combined.json` that the search UI loads client-side.

### JSON Structure
```json
{
  "fullText": "...",
  "title": "...",
  "contributor": "Lucas Van Rompay",
  "idno": "https://gedsh.bethmardutho.org/...",
  "displayTitleEnglish": "...",
  "infobox": "(ca. 400)",
  "persName": ["..."],
  "placeName": ["..."]
}
```

- `contributor` — the article author (from the TEI `byline`/`author`), shown in search results.
- `infobox` — the entry's date/qualifier string (from `<ab type="infobox">`, e.g. `(ca. 400)`), shown next to the title.

### Generating the JSON Locally

The JSON is produced from the TEI XML by an XSLT stylesheet (`siteGenerator/xsl/json.xsl`) run through Saxon. The same transform runs in CI (`.github/workflows/dataToAWS.yml`); the steps below reproduce it on your machine.

**Requirements**

- Java 11+ (`java -version` to check)
- The TEI source data checked out alongside this repo. The build script defaults to `../e-gedsh/data/tei/articles/tei`:
  ```bash
  # from the parent directory of e-gedsh-app
  git clone https://github.com/srophe/e-gedsh.git
  ```
- Saxon-HE 10.6 — the build script downloads it automatically to `/tmp/saxon.jar` if it isn't present.

**Build script (recommended)**

```bash
# from the e-gedsh-app root
siteGenerator/build-json.sh
```

This converts every TEI article to `json/<id>.json`, skips non-article files (front/back matter), and rebuilds `json/combined.json`. To point at a TEI directory somewhere else, pass it as the first argument:

```bash
siteGenerator/build-json.sh /path/to/e-gedsh/data/tei/articles/tei
```

Set `SAXON_JAR` to reuse an existing Saxon jar instead of downloading one:

```bash
SAXON_JAR=/path/to/saxon.jar siteGenerator/build-json.sh
```

**Manual invocation (single file)**

To transform one entry and print it to stdout:

```bash
java -jar /tmp/saxon.jar \
  -s:/path/to/e-gedsh/data/tei/articles/tei/Aba.xml \
  -xsl:siteGenerator/xsl/json.xsl
```

The stylesheet locates its field configuration (`siteGenerator/components/repo-config.xml`) relative to itself, so no extra parameters are required regardless of the working directory. To read the config from a different app root instead, pass `staticSitePath=<app-root>`.

After regenerating, restart your local web server (or hard-refresh) so the browser picks up the new `json/combined.json`.

## Deployment

### AWS

See [infrastructure/README.md](infrastructure/README.md) for AWS deployment instructions.

### GitHub Pages

The static site can be hosted for free on GitHub Pages.

1. Go to your repo **Settings → Pages**
2. Under **Source**, select **GitHub Actions**
3. Add `.github/workflows/pages.yml`:
   ```yaml
   name: Deploy to GitHub Pages

   on:
     push:
       branches: [main]

   permissions:
     contents: read
     pages: write
     id-token: write

   jobs:
     deploy:
       runs-on: ubuntu-latest
       environment:
         name: github-pages
         url: ${{ steps.deployment.outputs.page_url }}
       steps:
         - uses: actions/checkout@v4
         - uses: actions/configure-pages@v4
         - uses: actions/upload-pages-artifact@v3
           with:
             path: .
         - id: deployment
           uses: actions/deploy-pages@v4
   ```
4. Push to `main` — the site will be live at `https://<org>.github.io/e-gedsh-app/`

**Path fix:** GitHub Pages serves from a subdirectory (`/e-gedsh-app/`), so root-relative paths need updating. Convert `/resources/...` to `./resources/...`:
```bash
find . -name "*.html" -exec sed -i '' 's|href="/resources|href="./resources|g; s|src="/resources|src="./resources|g' {} +
```

Alternatively, if you use a **custom domain** (e.g., `gedsh.bethmardutho.org`), root paths work without changes — just add a `CNAME` file containing your domain to the repo root.

Search works automatically since it loads `json/combined.json` client-side.

## License

Content licensed under Creative Commons. See footer for details.
