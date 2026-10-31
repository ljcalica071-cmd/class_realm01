"""
investigate_failing_urls.py
Investigate why https://doi.org/10.48175/IJARSCT-18756 timed out and
what https://digi-journalphils.com/article/imms-pup-2024 actually returns.
"""

import urllib.request
import urllib.error
import ssl

def test_url(url, timeout=30):
    print(f"Testing URL: {url} (timeout={timeout}s)")
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
    )
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
            print(f"SUCCESS: Code {resp.getcode()}, Final URL: {resp.geturl()}")
            sample_content = resp.read(500)
            print(f"Content sample: {sample_content[:200]}")
    except urllib.error.HTTPError as e:
        print(f"HTTP ERROR: {e.code} - {e.reason}")
    except urllib.error.URLError as e:
        print(f"URL ERROR: {e.reason}")
    except Exception as e:
        print(f"EXCEPTION: {type(e).__name__} - {e}")

if __name__ == "__main__":
    print("--- 1. Testing DOI resolver for IJARSCT-18756 ---")
    test_url("https://doi.org/10.48175/IJARSCT-18756", timeout=25)
    
    print("\n--- 2. Testing direct IJARSCT website ---")
    test_url("https://ijarsct.co.in/Issue118.html", timeout=20)
    test_url("https://ijarsct.co.in", timeout=20)

    print("\n--- 3. Testing digi-journalphils.com ---")
    test_url("https://digi-journalphils.com/article/imms-pup-2024", timeout=15)
    test_url("https://digi-journalphils.com", timeout=15)
