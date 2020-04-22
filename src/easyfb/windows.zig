// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");
usingnamespace std.os.windows;
const parent = @import("../easyfb.zig");

const UINT_PTR = usize; // TODO: Do this correctly?
const LONG_PTR = isize; // TODO: Do this correctly?
const ATOM = WORD;

const WNDPROC = ?fn (HWND, UINT, WPARAM, LPARAM) callconv(.Stdcall) LRESULT;

const WS_MINIMIZEBOX = 0x00020000;
const WS_SYSMENU = 0x00080000;
const WS_CAPTION = 0x00C00000;
const WS_VISIBLE = 0x10000000;

const cw_usedefault_bits: c_uint = 0x80000000;
const CW_USEDEFAULT = @bitCast(c_int, cw_usedefault_bits);

const PAINTSTRUCT = extern struct {
    hdc: HDC,
    fErase: BOOL,
    rcPaint: RECT,
    fRestore: BOOL,
    fIncUpdate: BOOL,
    rgbReserved: [32]BYTE,
};

const WNDCLASSEXW = extern struct {
    cbSize: UINT = @sizeOf(@This()),
    style: UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: c_int,
    cbWndExtra: c_int,
    hInstance: HINSTANCE,
    hIcon: ?HICON,
    hCursor: ?HCURSOR,
    hbrBackground: ?HBRUSH,
    lpszMenuName: ?LPCWSTR,
    lpszClassName: LPCWSTR,
    hIconSmall: ?HICON,
};

const CREATESTRUCTW = extern struct {
    lpCreateParams: ?LPVOID,
    hInstance: HINSTANCE,
    hMenu: ?HMENU,
    hwndParent: ?HWND,
    cy: c_int,
    cx: c_int,
    y: c_int,
    x: c_int,
    style: LONG,
    lpszName: LPCWSTR,
    lpszClass: LPCWSTR,
    dwExStyle: DWORD,
};
const RECT = extern struct {
    left: LONG,
    top: LONG,
    right: LONG,
    bottom: LONG,
};
extern "user32" fn RegisterClassExW(*const WNDCLASSEXW) callconv(.Stdcall) ATOM;

const WM_DESTROY: UINT = 0x2;
const WM_CREATE: UINT = 0x1;
const WM_PAINT: UINT = 0x000F;

extern "user32" fn DefWindowProcW(HWND, UINT, WPARAM, LPARAM) callconv(.Stdcall) LRESULT;
extern "user32" fn PostQuitMessage(c_int) callconv(.Stdcall) void;

extern "user32" fn CreateWindowExW(dwExStyle: DWORD, lpClassName: LPCWSTR, lpWindowName: LPCWSTR, dwStyle: DWORD, X: c_int, Y: c_int, nWidth: c_int, nHeight: c_int, hWndParent: ?HWND, hMenu: ?HMENU, hInstance: HINSTANCE, lpParam: ?LPVOID) callconv(.Stdcall) ?HWND;

extern "user32" fn AdjustWindowRectEx(lpRect: *RECT, dwStyle: DWORD, bMenu: BOOL, dwExStyle: DWORD) callconv(.Stdcall) BOOL;

const POINT = extern struct {
    x: LONG,
    y: LONG,
};
extern "user32" fn TranslateMessage(msg: *const MSG) callconv(.Stdcall) BOOL;

extern "user32" fn DispatchMessageA(msg: *const MSG) callconv(.Stdcall) BOOL;
extern "user32" fn DestroyWindow(win: HWND) callconv(.Stdcall) BOOL;

extern "user32" fn BeginPaint(hWnd: HWND, lpPaint: *PAINTSTRUCT) callconv(.Stdcall) ?HDC;
extern "user32" fn EndPaint(hWnd: HWND, lpPaint: *const PAINTSTRUCT) callconv(.Stdcall) BOOL;

const MSG = extern struct {
    hwnd: HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
    lPrivate: DWORD,
};
extern "user32" fn GetMessageW(Msg: *MSG, hWnd: HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT) callconv(.Stdcall) BOOL;

const BITMAPINFO = extern struct {
    bmiHeader: BITMAPINFOHEADER,
    bmiColors: [1]RGBQUAD,
};

const RGBQUAD = extern struct {
    rgbBlue: BYTE,
    rgbGreen: BYTE,
    rgbRed: BYTE,
    rgbReserved: BYTE,
};

const BITMAPINFOHEADER = extern struct {
    biSize: DWORD,
    biWidth: LONG,
    biHeight: LONG,
    biPlanes: WORD,
    biBitCount: WORD,
    biCompression: DWORD,
    biSizeImage: DWORD,
    biXPelsPerMeter: LONG,
    biYPelsPerMeter: LONG,
    biClrUsed: DWORD,
    biClrImportant: DWORD,
};

const RGBMASKS = extern struct {
    rmask: DWORD,
    gmask: DWORD,
    bmask: DWORD,
};

const Image = struct {
    width: u32,
    height: u32,
    image: [*]u8,
    bmi: *BITMAPINFO,
};

const CreateInfoStruct = struct {
    image: *Image,
    window_open: *u32,
};

pub const EasyFBInstanceWindows = struct {
    class_name: [:0]u16,
    allocator: *Allocator,
    pub fn init(allocator: *Allocator, instance_name: []const u8) error{
        RegisterInstanceError,
        InvalidInstanceName,
        InvalidUtf8,
        OutOfMemory,
    }!@This() {
        if (instance_name.len > 256) {
            return error.InvalidInstanceName;
        }

        const class_name = try std.unicode.utf8ToUtf16LeWithNull(allocator, instance_name);
        const class = WNDCLASSEXW{
            .style = 0,
            .lpfnWndProc = windowProc,
            .cbClsExtra = 0,
            .cbWndExtra = @sizeOf(LONG_PTR) * 2,
            .hInstance = @ptrCast(HINSTANCE, kernel32.GetModuleHandleW(null)),
            .hIcon = null,
            .hCursor = null,
            .hbrBackground = null,
            .lpszMenuName = null,
            .lpszClassName = class_name.ptr,
            .hIconSmall = null,
        };
        const atom = RegisterClassExW(&class);
        if (atom == 0) {
            return error.RegisterInstanceError;
        }
        return @This(){ .class_name = class_name, .allocator = allocator };
    }

    pub fn renderRGBAImageSync(
        self: *@This(),
        image: []u8,
        width: u32,
        height: u32,
        win_name: []const u8,
    ) error{
        WindowCreationFailure,
        OutOfMemory,
        InvalidUtf8,
    }!void {
        const win_name_u16 = try std.unicode.utf8ToUtf16LeWithNull(self.allocator, win_name);
        defer self.allocator.free(win_name_u16);
        const image_ptr = try self.allocator.create(Image);
        defer self.allocator.destroy(image_ptr);

        const bmi_size = @sizeOf(BITMAPINFOHEADER) + @sizeOf(RGBMASKS);
        const bmi_mem = try self.allocator.alignedAlloc(u8, @alignOf(BITMAPINFO), bmi_size);
        defer self.allocator.free(bmi_mem);
        const bmi_header = @ptrCast(*BITMAPINFOHEADER, bmi_mem.ptr);

        bmi_header.* = BITMAPINFOHEADER{
            .biSize = bmi_size,
            .biWidth = @intCast(i32, width),
            .biHeight = -@intCast(i32, height),
            .biPlanes = 1,
            .biBitCount = 32,
            .biCompression = 3,
            .biSizeImage = @intCast(u32, image.len),
            .biXPelsPerMeter = 0,
            .biYPelsPerMeter = 0,
            .biClrUsed = 0,
            .biClrImportant = 0,
        };

        const rgbmasks = @ptrCast(*RGBMASKS, @alignCast(@alignOf(RGBMASKS), bmi_mem[@sizeOf(BITMAPINFOHEADER)..].ptr));
        rgbmasks.* = RGBMASKS{ .rmask = 0x000000ff, .gmask = 0x0000ff00, .bmask = 0x00ff0000 };

        const bmi = @ptrCast(*BITMAPINFO, bmi_mem.ptr);

        image_ptr.* = Image{ .width = width, .height = height, .image = image.ptr, .bmi = bmi };
        const style = WS_MINIMIZEBOX | WS_SYSMENU | WS_CAPTION;
        const client_width = @intCast(LONG, width);
        const client_height = @intCast(LONG, height);
        var rect = RECT{ .left = 0, .top = 0, .bottom = client_height, .right = client_width };
        _ = AdjustWindowRectEx(&rect, style, 0, 0);

        const win_width = rect.right - rect.left;
        const win_height = rect.bottom - rect.top;
        var window_open: u32 = 1;
        var createinfo = CreateInfoStruct{ .image = image_ptr, .window_open = &window_open };

        var win = CreateWindowExW(
            0,
            self.class_name,
            win_name_u16,
            style | WS_VISIBLE,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            win_width,
            win_height,
            null,
            null,
            @ptrCast(HINSTANCE, kernel32.GetModuleHandleW(null)),
            &createinfo,
        );
        if (win) |window| {
            var msg: MSG = undefined;
            var quit_message_recieved = true;
            while (@atomicLoad(u32, &window_open, .SeqCst) != 0 and 0 != GetMessageW(&msg, win.?, 0, 0)) {
                _ = TranslateMessage(&msg);
                _ = DispatchMessageA(&msg);
            }
            if (quit_message_recieved) {
                _ = DestroyWindow(win.?);
            }
        } else {
            return error.WindowCreationFailure;
        }
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.class_name);
    }
};

extern "user32" fn SetWindowLongPtrW(hWnd: HWND, nIndex: c_int, dwNewLong: LONG_PTR) callconv(.Stdcall) LONG_PTR;
extern "user32" fn GetWindowLongPtrW(hWnd: HWND, nIndex: c_int) callconv(.Stdcall) LONG_PTR;

extern "gdi32" fn StretchDIBits(hdc: HDC, xDest: c_int, yDest: c_int, DestWidth: c_int, DestHeight: c_int, xSrc: c_int, ySrc: c_int, SrcWidth: c_int, SrcHeight: c_int, lpBits: *const c_void, lpbmi: *const BITMAPINFO, iUsage: UINT, rop: DWORD) callconv(.Stdcall) c_int;

extern "user32" fn GetClientRect(hWnd: HWND, lpRect: *RECT) callconv(.Stdcall) BOOL;
fn windowProc(win: HWND, msg: UINT, w_param: WPARAM, l_param: LPARAM) callconv(.Stdcall) LRESULT {
    var ret: LRESULT = null;
    switch (msg) {
        WM_DESTROY => blk: {
            const window_open_ptr = @intToPtr(*u32, @bitCast(usize, GetWindowLongPtrW(win, 1 * @sizeOf(LONG_PTR))));
            @atomicStore(u32, window_open_ptr, 0, .SeqCst);
        },
        WM_PAINT => blk: {
            var paintinfo: PAINTSTRUCT = undefined;
            if (BeginPaint(win, &paintinfo)) |dc| {
                const image = @intToPtr(*Image, @bitCast(usize, GetWindowLongPtrW(win, 0 * @sizeOf(LONG_PTR))));
                _ = StretchDIBits(
                    dc,
                    paintinfo.rcPaint.left,
                    paintinfo.rcPaint.top,
                    paintinfo.rcPaint.right - paintinfo.rcPaint.left,
                    paintinfo.rcPaint.bottom - paintinfo.rcPaint.top,
                    paintinfo.rcPaint.left,
                    paintinfo.rcPaint.top,
                    paintinfo.rcPaint.right - paintinfo.rcPaint.left,
                    paintinfo.rcPaint.bottom - paintinfo.rcPaint.top,
                    image.image,
                    image.bmi,
                    0,
                    0x00CC0020,
                );
                const res = EndPaint(win, &paintinfo);
                if (res == 0) {
                    std.debug.warn("end paint error: {}\n", .{kernel32.GetLastError()});
                }
            } else {
                std.debug.warn("begin paint error: {}\n", .{kernel32.GetLastError()});
            }
        },
        WM_CREATE => blk: {
            var rect: RECT = undefined;
            const b = GetClientRect(win, &rect);
            if (b == 0) {
                std.debug.warn("Couldn't get client rect", .{});
            }
            const createstruct = @intToPtr(*CREATESTRUCTW, @ptrToInt(l_param));
            const createinfo = @ptrCast(
                *CreateInfoStruct,
                @alignCast(8, createstruct.lpCreateParams),
            );
            // NOTE: Assbite, this is byte aligned indexing, not pointer aligned indexing
            SetLastError(0);
            _ = SetWindowLongPtrW(
                win,
                0 * @sizeOf(LONG_PTR),
                @bitCast(isize, @ptrToInt(createinfo.image)),
            );
            SetLastError(0);
            _ = SetWindowLongPtrW(
                win,
                1 * @sizeOf(LONG_PTR),
                @bitCast(isize, @ptrToInt(createinfo.window_open)),
            );
        },
        else => ret = DefWindowProcW(win, msg, w_param, l_param),
    }
    return ret;
}

extern "kernel32" fn SetLastError(dwErrCode: DWORD) callconv(.Stdcall) void;
