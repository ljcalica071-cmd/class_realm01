import sys
print("Python version:", sys.version)
try:
    import docx
    print("python-docx is available, version:", docx.__version__)
except ImportError:
    print("python-docx is NOT available")
