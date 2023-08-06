const std = @import("std");
const c = @cImport(@cInclude("libusockets.h"));

test "usocket: tcp e2e" {
    const data = "hello world!";

    const Loop = struct {
        fn onWakeup(_: ?*c.us_loop_t) callconv(.C) void {}
        fn onPre(_: ?*c.us_loop_t) callconv(.C) void {}
        fn onPost(_: ?*c.us_loop_t) callconv(.C) void {}
    };

    const Listener = struct {
        var socket: *c.us_listen_socket_t = undefined;

        // 's' is an incoming socket. NOT the listener socket.
        fn onOpen(s: ?*c.us_socket_t, is_client: c_int, _: [*c]u8, _: c_int) callconv(.C) ?*c.us_socket_t {
            std.debug.assert(s != @as(*c.us_socket_t, @ptrCast(@This().socket)));
            std.debug.assert(is_client == 0);
            return s;
        }

        // 's' is an incoming socket. NOT the listener socket.
        fn onData(s: ?*c.us_socket_t, data_ptr: [*c]u8, data_len: c_int) callconv(.C) ?*c.us_socket_t {
            std.debug.assert(s != @as(*c.us_socket_t, @ptrCast(@This().socket)));
            const actual_data = data_ptr[0..@intCast(data_len)];
            std.debug.assert(std.mem.eql(u8, data, actual_data));
            return c.us_socket_close(0, s, 0, null);
        }

        // 's' is an incoming socket. NOT the listener socket.
        fn onClose(s: ?*c.us_socket_t, code: c_int, _: ?*anyopaque) callconv(.C) ?*c.us_socket_t {
            std.debug.assert(s != @as(*c.us_socket_t, @ptrCast(@This().socket)));
            std.debug.assert(code == 0);
            c.us_listen_socket_close(0, @This().socket);
            return s;
        }
    };

    const Client = struct {
        var socket: *c.us_socket_t = undefined;

        fn onOpen(s: ?*c.us_socket_t, is_client: c_int, _: [*c]u8, _: c_int) callconv(.C) ?*c.us_socket_t {
            std.debug.assert(s == @This().socket);
            std.debug.assert(is_client != 0);

            const bytes_written = c.us_socket_write(0, s, data, data.len, 0);
            std.debug.assert(bytes_written == @as(usize, @intCast(data.len)));

            return c.us_socket_close(0, s, 0, null);
        }

        fn onClose(s: ?*c.us_socket_t, code: c_int, _: ?*anyopaque) callconv(.C) ?*c.us_socket_t {
            std.debug.assert(s == @This().socket);
            std.debug.assert(code == 0);
            return s;
        }
    };

    const loop = c.us_create_loop(null, Loop.onWakeup, Loop.onPre, Loop.onPost, 0);
    defer c.us_loop_free(loop);

    const opts = std.mem.zeroes(c.us_socket_context_options_t);

    const listener_ctx = c.us_create_socket_context(0, loop, 0, opts) orelse return error.OutOfMemory;
    defer c.us_socket_context_free(0, listener_ctx);
    
    c.us_socket_context_on_open(0, listener_ctx, Listener.onOpen);
    c.us_socket_context_on_data(0, listener_ctx, Listener.onData);
    c.us_socket_context_on_close(0, listener_ctx, Listener.onClose);

    const client_ctx = c.us_create_socket_context(0, loop, 0, opts) orelse return error.OutOfMemory;
    defer c.us_socket_context_free(0, client_ctx);

    c.us_socket_context_on_open(0, client_ctx, Client.onOpen);
    c.us_socket_context_on_close(0, client_ctx, Client.onClose);

    Listener.socket = c.us_socket_context_listen(0, listener_ctx, "0.0.0.0", 0, 0, 0) orelse {
        return error.ListenFailed;
    };
    const port = c.us_socket_local_port(0, @ptrCast(Listener.socket));

    Client.socket = c.us_socket_context_connect(0, client_ctx, "127.0.0.1", port, null, 0, 0) orelse {
        return error.ConnectionFailed;
    };

    c.us_loop_run(loop);
}
