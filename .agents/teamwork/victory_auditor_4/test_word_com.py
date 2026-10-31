import sys

try:
    import win32com.client
    word = win32com.client.Dispatch("Word.Application")
    word.Visible = False
    print("Word COM available!")
    word.Quit()
except Exception as e:
    print(f"Word COM error: {e}")
