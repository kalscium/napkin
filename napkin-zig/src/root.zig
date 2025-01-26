const std = @import("std");
const yaml = @import("yaml");

pub fn stuff() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const source =
        \\names: [ John Doe, MacIntosh, Jane Austin ]
        \\numbers:
        \\  - 10
        \\  - -8
        \\  - 6
        \\foo: 12
        \\nested:
        \\  some: one
        \\  wick: john doe
        \\finally: [ 8.17,
        \\           19.78      , 17 ,
        \\           21 ]
    ;

    const Test = struct {
        foo: i32,
    };

    var doc = try yaml.Yaml.load(allocator, source);
    defer doc.deinit();
    const test_struct = try doc.parse(Test);
    _ = test_struct;
}
