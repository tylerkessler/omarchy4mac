"""Print the 1-based index of the native macOS Space that is active right now (tyler-os #1337).

SketchyBar's space_change $INFO is not trustworthy on this Mac: a screenshot sends {"display-1": 2} then 1 again while
the Mac never left Space 1. This asks the window server directly (CGSGetActiveSpace + CGSCopyManagedDisplaySpaces).
Prints nothing and exits 1 when it cannot tell, so aerospace.sh keeps the digit it has.
"""
import ctypes
import sys

CF_NUMBER_SINT64 = 4
UTF8 = 0x08000100


def _libs():
    cg = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
    cf = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
    vp, i64 = ctypes.c_void_p, ctypes.c_int64
    cg.CGSMainConnectionID.restype = ctypes.c_int
    cg.CGSGetActiveSpace.restype, cg.CGSGetActiveSpace.argtypes = ctypes.c_uint64, [ctypes.c_int]
    cg.CGSCopyManagedDisplaySpaces.restype, cg.CGSCopyManagedDisplaySpaces.argtypes = vp, [ctypes.c_int]
    cf.CFArrayGetCount.restype, cf.CFArrayGetCount.argtypes = ctypes.c_long, [vp]
    cf.CFArrayGetValueAtIndex.restype, cf.CFArrayGetValueAtIndex.argtypes = vp, [vp, ctypes.c_long]
    cf.CFDictionaryGetValue.restype, cf.CFDictionaryGetValue.argtypes = vp, [vp, vp]
    cf.CFStringCreateWithCString.restype, cf.CFStringCreateWithCString.argtypes = vp, [vp, ctypes.c_char_p, ctypes.c_uint32]
    cf.CFNumberGetValue.restype, cf.CFNumberGetValue.argtypes = ctypes.c_bool, [vp, ctypes.c_int, ctypes.POINTER(i64)]
    cf.CFRelease.argtypes = [vp]
    return cg, cf


def space_ids_by_display(cg, cf, conn):
    """[[space id, ...] per display], in Mission Control order."""
    key = lambda s: cf.CFStringCreateWithCString(None, s, UTF8)  # noqa: E731
    k_spaces, k_id = key(b"Spaces"), key(b"id64")
    displays = cg.CGSCopyManagedDisplaySpaces(conn)
    if not displays:
        return []
    out = []
    for d in range(cf.CFArrayGetCount(displays)):
        spaces = cf.CFDictionaryGetValue(cf.CFArrayGetValueAtIndex(displays, d), k_spaces)
        ids = []
        for s in range(cf.CFArrayGetCount(spaces) if spaces else 0):
            num, val = cf.CFDictionaryGetValue(cf.CFArrayGetValueAtIndex(spaces, s), k_id), ctypes.c_int64()
            if num and cf.CFNumberGetValue(num, CF_NUMBER_SINT64, ctypes.byref(val)):
                ids.append(val.value)
        out.append(ids)
    cf.CFRelease(displays)
    return out


def index_of(active, displays):
    for ids in displays:
        if active in ids:
            return ids.index(active) + 1
    return None


def main():
    try:
        cg, cf = _libs()
        conn = cg.CGSMainConnectionID()
        idx = index_of(cg.CGSGetActiveSpace(conn), space_ids_by_display(cg, cf, conn))
    except (OSError, AttributeError):
        idx = None
    if idx is None:
        return 1
    print(idx)
    return 0


if __name__ == "__main__":
    sys.exit(main())
