#!/usr/bin/env python3
"""Verify or re-download the twelve checked CC0 source images.

This never searches for or silently adds new sources. New photos require a
reviewed source, explicit licence, author and checksum in manifest.json.
"""
import argparse
import hashlib
import json
from pathlib import Path
import urllib.parse
import urllib.request

ROOT=Path(__file__).resolve().parents[2]


def verify(manifest,download=False):
    assets=json.loads(Path(manifest).read_text())['assets']
    for a in assets:
        if a['license']!='CC0-1.0':raise ValueError('This downloader accepts reviewed CC0 inputs only')
        url=urllib.parse.urlsplit(a['download_url'])
        if url.scheme!='https' or url.hostname not in ('upload.wikimedia.org','thumb.wikimedia.org'):
            raise ValueError('Expected an official Wikimedia image URL')
        path=(ROOT/a['image']).resolve()
        if ROOT not in path.parents:raise ValueError('Input path escapes the worktree')
        if download and not path.exists():
            request=urllib.request.Request(a['download_url'],headers={'User-Agent':'Primigenia-Idol/1.0 (CC0 asset evaluation)'})
            data=urllib.request.urlopen(request,timeout=45).read()
            if hashlib.sha256(data).hexdigest()!=a['sha256']:raise ValueError(f"Source changed: {a['id']}")
            path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
        if hashlib.sha256(path.read_bytes()).hexdigest()!=a['sha256']:raise ValueError(f"Checksum mismatch: {a['id']}")
    return len(assets)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--manifest',type=Path,default=ROOT/'assets/idol/manifest.json')
    p.add_argument('--download',action='store_true');args=p.parse_args()
    print(f'{verify(args.manifest,args.download)} CC0 input checksums verified')
