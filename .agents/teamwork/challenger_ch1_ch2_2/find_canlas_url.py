"""
find_canlas_url.py
Scrape digi-journalphils.com to find the exact article URL for Canlas & Ado (2024).
"""

import urllib.request
import re

def scrape():
    url = "https://digi-journalphils.com"
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            html = resp.read().decode('utf-8', errors='ignore')
            print(f"HTML Length: {len(html)}")
            links = re.findall(r'href=["\']([^"\']+)["\']', html)
            print(f"Found {len(links)} links on homepage:")
            for l in links[:30]:
                print("  ", l)
            
            # Check for Canlas or IMMS or Technologique
            matches = [l for l in links if any(k in l.lower() for k in ['canlas', 'imms', 'technologique', 'article', 'pup'])]
            print("\nMatching links:")
            for m in matches:
                print("  MATCH:", m)
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    scrape()
