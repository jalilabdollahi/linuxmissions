#!/bin/bash
# CDN Cutover: 40 HTML templates (30 pages + 10 e-mails in a subfolder) with
# old CDN URLs (sometimes two per line), DD/MM/YYYY dates (sometimes two per
# line) and links to a partner whose domain differs from the old CDN only
# where the CDN has dots. The expected result is generated alongside and
# kept only as checksums.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state templates/emails .lm-state/want/emails

awk -v seed="$RANDOM$$" '
function d2(n) { return sprintf("%02d", n) }
function date(   d, m, y) {
  d = int(rand() * 28) + 1; m = int(rand() * 12) + 1; y = 2025 + int(rand() * 2)
  OLD = d2(d) "/" d2(m) "/" y; NEW = y "-" d2(m) "-" d2(d)
}
function emit(o, n) { print o > of; print n > nf }
BEGIN {
  srand(seed)
  ncss = split("site layout print forms", css, " ")
  njs = split("app cart analytics menu", js, " ")
  nimg = split("hero logo banner-autumn team product-01 product-02 map", img, " ")
  npage = split("index about contact pricing blog careers faq support terms privacy press partners shop cart checkout account login signup reset-password status changelog events webinar team history security docs api download newsletter", page, " ")
  nmail = split("welcome invoice receipt password-reset shipping-update order-cancelled renewal-reminder survey trial-ending event-invite", mail, " ")
  O = "http://old-cdn.example.com/"; N = "https://cdn.example.net/v2/"
  for (f = 1; f <= 40; f++) {
    isMail = (f > npage)
    name = isMail ? "emails/" mail[f - npage] : page[f]
    of = "templates/" name ".html"; nf = ".lm-state/want/" name ".html"
    emit("<!DOCTYPE html>", "<!DOCTYPE html>")
    emit("<html lang=\"en\">", "<html lang=\"en\">")
    emit("<head>", "<head>")
    c = css[int(rand() * ncss) + 1]
    emit("  <link rel=\"stylesheet\" href=\"" O "css/" c ".css\">", "  <link rel=\"stylesheet\" href=\"" N "css/" c ".css\">")
    if (!isMail) { j = js[int(rand() * njs) + 1]; emit("  <script src=\"" O "js/" j ".js\" defer></script>", "  <script src=\"" N "js/" j ".js\" defer></script>") }
    emit("  <title>{{ title }}</title>", "  <title>{{ title }}</title>")
    emit("</head>", "</head>")
    emit("<body>", "<body>")
    k = 2 + int(rand() * 5)
    for (i = 0; i < k; i++) {
      r = rand()
      if (r < 0.3) {
        im = img[int(rand() * nimg) + 1]
        emit("  <img src=\"" O "img/" im ".png\" srcset=\"" O "img/" im "@2x.png 2x\" alt=\"\">", "  <img src=\"" N "img/" im ".png\" srcset=\"" N "img/" im "@2x.png 2x\" alt=\"\">")
      } else if (r < 0.55) {
        date(); emit("  <p class=\"date\">Published " OLD "</p>", "  <p class=\"date\">Published " NEW "</p>")
      } else if (r < 0.75) {
        date(); o1 = OLD; n1 = NEW; date()
        emit("  <p>Offer valid from " o1 " to " OLD ", while stocks last.</p>", "  <p>Offer valid from " n1 " to " NEW ", while stocks last.</p>")
      } else if (r < 0.88) {
        emit("  <p>Questions? Write to support@example.com or call +41 44 123 45 67.</p>", "  <p>Questions? Write to support@example.com or call +41 44 123 45 67.</p>")
      } else {
        emit("  <p>Version 2.4.1 of the app, released 2026-10-30, is available.</p>", "  <p>Version 2.4.1 of the app, released 2026-10-30, is available.</p>")
      }
    }
    if (rand() < 0.5 || f == 1) emit("  <a href=\"http://old-cdn-example.com/partners/" name "\">Old CDN Example Ltd, our print partner</a>", "  <a href=\"http://old-cdn-example.com/partners/" name "\">Old CDN Example Ltd, our print partner</a>")
    date()
    emit("  <footer>Last updated " OLD " &middot; <a href=\"" O "legal/imprint.pdf\">Imprint</a></footer>", "  <footer>Last updated " NEW " &middot; <a href=\"" N "legal/imprint.pdf\">Imprint</a></footer>")
    emit("</body>", "</body>")
    emit("</html>", "</html>")
    close(of); close(nf)
  }
}'

(cd .lm-state/want && find . -type f | sort | while read -r f; do echo "${f#./} $(cksum < "$f")"; done) > .lm-state/want.sums
grep -rho 'old-cdn-example\.com' templates | wc -l | tr -d ' ' > .lm-state/partner.count
rm -rf .lm-state/want
