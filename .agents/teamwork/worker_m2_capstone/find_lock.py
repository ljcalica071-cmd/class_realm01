import ctypes
from ctypes import wintypes
import os

# Define constants and structures for RestartManager API
CCH_RM_SESSION_KEY = 32
CCH_RM_MAX_APP_NAME = 255
CCH_RM_MAX_SVC_NAME = 63

class RM_UNIQUE_PROCESS(ctypes.Structure):
    _fields_ = [
        ("dwProcessId", wintypes.DWORD),
        ("ProcessStartTime", wintypes.FILETIME),
    ]

class RM_PROCESS_INFO(ctypes.Structure):
    _fields_ = [
        ("Process", RM_UNIQUE_PROCESS),
        ("strAppName", wintypes.WCHAR * (CCH_RM_MAX_APP_NAME + 1)),
        ("strServiceShortName", wintypes.WCHAR * (CCH_RM_MAX_SVC_NAME + 1)),
        ("ApplicationType", wintypes.DWORD),
        ("AppStatus", wintypes.ULONG),
        ("TSSessionId", wintypes.DWORD),
        ("bRestartable", wintypes.BOOL),
    ]

rstrtmgr = ctypes.WinDLL("rstrtmgr.dll")

RmStartSession = rstrtmgr.RmStartSession
RmStartSession.argtypes = [ctypes.POINTER(wintypes.DWORD), wintypes.DWORD, ctypes.c_wchar_p]
RmStartSession.restype = wintypes.DWORD

RmRegisterResources = rstrtmgr.RmRegisterResources
RmRegisterResources.argtypes = [wintypes.DWORD, wintypes.UINT, ctypes.POINTER(ctypes.c_wchar_p), wintypes.UINT, ctypes.c_void_p, wintypes.UINT, ctypes.c_void_p]
RmRegisterResources.restype = wintypes.DWORD

RmGetList = rstrtmgr.RmGetList
RmGetList.argtypes = [wintypes.DWORD, ctypes.POINTER(wintypes.UINT), ctypes.POINTER(wintypes.UINT), ctypes.POINTER(RM_PROCESS_INFO), ctypes.POINTER(wintypes.DWORD)]
RmGetList.restype = wintypes.DWORD

RmEndSession = rstrtmgr.RmEndSession
RmEndSession.argtypes = [wintypes.DWORD]
RmEndSession.restype = wintypes.DWORD

target_file = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED_SENIOR_HIGH_SCHOOL_ATTENDANCE_CH1_CH2_CH3.docx"

session_handle = wintypes.DWORD()
session_key = (wintypes.WCHAR * (CCH_RM_SESSION_KEY + 1))()

res = RmStartSession(ctypes.byref(session_handle), 0, session_key)
if res != 0:
    print(f"RmStartSession failed with error: {res}")
else:
    try:
        file_array = (ctypes.c_wchar_p * 1)(target_file)
        res = RmRegisterResources(session_handle, 1, file_array, 0, None, 0, None)
        if res != 0:
            print(f"RmRegisterResources failed with error: {res}")
        else:
            n_proc_info_needed = wintypes.UINT(0)
            n_proc_info = wintypes.UINT(0)
            reboot_reasons = wintypes.DWORD()
            
            res = RmGetList(session_handle, ctypes.byref(n_proc_info_needed), ctypes.byref(n_proc_info), None, ctypes.byref(reboot_reasons))
            if res not in (0, 234): # 234 = ERROR_MORE_DATA
                print(f"RmGetList failed with error: {res}")
            else:
                print(f"Processes locking file: {n_proc_info_needed.value}")
                if n_proc_info_needed.value > 0:
                    n_proc_info.value = n_proc_info_needed.value
                    process_info_array = (RM_PROCESS_INFO * n_proc_info.value)()
                    res = RmGetList(session_handle, ctypes.byref(n_proc_info_needed), ctypes.byref(n_proc_info), process_info_array, ctypes.byref(reboot_reasons))
                    for i in range(n_proc_info.value):
                        pi = process_info_array[i]
                        print(f"  PID: {pi.Process.dwProcessId}, App: {pi.strAppName}")
    finally:
        RmEndSession(session_handle)
