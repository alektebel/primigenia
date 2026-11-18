#!/usr/bin/env python3
"""Check `unverified` references against Crossref (articles) / OpenLibrary (books).

  python3 tools/lore/refcheck.py [--dry-run] [--only ID] [--root DIR]

Decision per reference:
  verified    title similarity >= 0.85, first-author family name matches, year within +-1.
              DOI/ISBN, container-title, real title and issued are filled; x-checked and x-note say what changed.
  rejected    no candidate plausible (no author+year match and no similar title).
  unverified  anything in between: kept, with an x-note naming the closest candidate.
HTTP responses are cached in tools/lore/.cache/ (gitignored); 1 request per second, generic User-Agent.
"""
import argparse, datetime, difflib, hashlib, html, json, os, re, sys, time, unicodedata, urllib.parse, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lorelib import ROOT, load, dump

UA = "cpore-lore-refcheck/1.0"
CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".cache")
_last = [0.0]


def http_json(url):
    os.makedirs(CACHE, exist_ok=True)
    p = os.path.join(CACHE, hashlib.sha1(url.encode()).hexdigest() + ".json")
    if os.path.exists(p):
        return json.load(open(p, encoding="utf-8"))
    wait = 1.0 - (time.time() - _last[0])
    if wait > 0: time.sleep(wait)
    _last[0] = time.time()
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.load(r)
    json.dump(data, open(p, "w", encoding="utf-8"))
    return data


def norm(s):
    s = html.unescape(re.sub(r"<[^>]+>", " ", s or ""))
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", " ", s).strip()


def main_title(t):
    return re.split(r"[:(]", t)[0]


def sim(a, b):
    full = difflib.SequenceMatcher(None, norm(a), norm(b)).ratio()
    ma, mb = norm(main_title(a)), norm(main_title(b))
    return max(full, difflib.SequenceMatcher(None, ma, mb).ratio() if len(ma) > 12 and len(mb) > 12 else 0)


def fam_ok(want, got_names):
    w = norm(want)
    return any(w and (w == norm(g) or w in norm(g).split() or norm(g) in w) for g in got_names)


def first_family(r):
    au = r.get("author") or [{}]
    return au[0].get("family") or au[0].get("literal") or ""


def candidates(r):
    """Normalised candidates: dicts with title, authors(family list), first_family, year, container, DOI, ISBN, source."""
    fam, title = first_family(r), r["title"]
    out = []
    short = main_title(title).strip()
    queries = [title] + ([short] if short and short != title else [])
    for title in queries:
        if r["type"] == "book":
            q = urllib.parse.urlencode({"q": f"{title} {fam}", "limit": 5, "fields": "title,author_name,first_publish_year,isbn,publisher"})
            for d in http_json("https://openlibrary.org/search.json?" + q).get("docs", []):
                names = d.get("author_name") or []
                isbns = d.get("isbn") or []
                isbn = next((i for i in isbns if len(i) == 13), isbns[0] if isbns else None)
                out.append({"title": d.get("title", ""), "authors": [n.split()[-1] for n in names], "first": names[0].split()[-1] if names else "",
                            "year": d.get("first_publish_year"), "container": None, "DOI": None, "ISBN": isbn, "source": "OpenLibrary"})
        else:
            q = urllib.parse.urlencode({"query.bibliographic": f"{title} {fam}", "rows": 3,
                                        "select": "title,author,issued,published,container-title,DOI,type"})
            for d in http_json("https://api.crossref.org/works?" + q)["message"]["items"]:
                fams = [a.get("family", "") for a in d.get("author", [])]
                dp = (d.get("issued") or d.get("published") or {}).get("date-parts", [[None]])[0]
                out.append({"title": re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", (d.get("title") or [""])[0]))).strip(),
                            "authors": fams, "first": fams[0] if fams else "", "year": dp[0] if dp else None,
                            "container": (d.get("container-title") or [None])[0], "DOI": d.get("DOI"), "ISBN": None, "source": "Crossref"})
    return out


def year_of(r):
    try: return r["issued"]["date-parts"][0][0]
    except (KeyError, IndexError, TypeError): return None


def decide(r, cands):
    """-> (decision, candidate|None, note)"""
    fam, yr = first_family(r), year_of(r)
    best, best_s = None, -1
    for c in cands:
        s = sim(r["title"], c["title"])
        ok_a = fam_ok(fam, [c["first"]]) if c["first"] else False
        ok_y = yr is None or c["year"] is None or abs(c["year"] - yr) <= 1
        score = s + (0.3 if ok_a else 0) + (0.1 if ok_y else 0)
        if score > best_s: best, best_s, best_info = c, score, (s, ok_a, ok_y)
    if best is None:
        return "rejected", None, "no candidate returned by the index"
    s, ok_a, ok_y = best_info
    if s >= 0.85 and ok_a and ok_y: return "verified", best, f"title {s:.2f}"
    if ok_a and (ok_y or s >= 0.6) or s >= 0.75:
        return "unverified", best, f"ambiguous: closest {best['source']} hit is '{best['title']}' ({best['first']}, {best['year']}" + \
               (f", doi {best['DOI']}" if best["DOI"] else "") + f"), title similarity {s:.2f}, author {'match' if ok_a else 'differs'}, year {'ok' if ok_y else 'off'}"
    return "rejected", best, f"nothing plausible; closest hit '{best['title']}' ({best['first']}, {best['year']}) title similarity {s:.2f}"


def apply(r, d, c, why, today):
    r = dict(r)
    changes = []
    if d == "verified":
        if c["title"] and norm(c["title"]) != norm(r["title"]) and (c["source"] == "Crossref" or difflib.SequenceMatcher(None, norm(c["title"]), norm(r["title"])).ratio() >= 0.85):
            changes.append(f"title corrected from '{r['title']}'"); r["title"] = c["title"]
        if c["container"] and c["container"] != r.get("container-title"):
            changes.append("container-title " + ("set" if "container-title" not in r else f"corrected from '{r['container-title']}'")); r["container-title"] = c["container"]
        if c["year"] and c["year"] != year_of(r):
            changes.append(f"year corrected from {year_of(r)}"); r["issued"] = {"date-parts": [[c["year"]]]}
        if c["DOI"]: r["DOI"] = c["DOI"]; changes.append("DOI added")
        if c["ISBN"]: r["ISBN"] = c["ISBN"]; changes.append("ISBN added")
        r["x-note"] = f"verified against {c['source']} ({why}); " + ("; ".join(changes) if changes else "no changes needed")
    elif d == "rejected":
        r["x-note"] = why
    else:
        r["x-note"] = why
    r["x-status"] = d
    r["x-checked"] = today
    return r


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--only")
    ap.add_argument("--root", default=ROOT)
    a = ap.parse_args()
    path = os.path.join(a.root, "lore", "references.json")
    refs = load(path)
    today = datetime.date.today().isoformat()
    changed = 0
    for i, r in enumerate(refs):
        if r["x-status"] != "unverified" or (a.only and r["id"] != a.only): continue
        try:
            d, c, why = decide(r, candidates(r))
        except Exception as e:
            print(f"{r['id']}: lookup failed ({e}); left unchanged"); continue
        new = apply(r, d, c, why, today)
        print(f"{r['id']}: {d.upper()}: {new['x-note']}")
        if new != r: refs[i] = new; changed += 1
    if not a.dry_run and changed:
        dump(refs, path)
        print(f"wrote {path}")


if __name__ == "__main__":
    main()
