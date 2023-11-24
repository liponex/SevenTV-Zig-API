# An unofficial Zig library for retrieving 7TV Emoji data
This project was done to make it easier to retrieve 7TV Emoji data for use in other projects.
It is not affiliated with 7TV in any way.
---
## Usage

build.zig.zon
```zig
.dependencies = .{
    // ...
    .seventv_zig_api = .{
        .url = "https://github.com/liponex/SevenTV-Zig-API/archive/refs/heads/main.tar.gz",
        .hash = "12200d756c07d23aefaab259c575d4e888f2dd92411182490538b9935f704645afc3",
    },
    // ...
},
```

build.zig
```zig
const seventv = b.dependency("seventv_zig_api", .{
    .target = target,
    .optimize = optimize,
});
exe.linkLibrary(seventv.artifact("seventv_zig_api"));
exe.addModule("seventv_zig_api", seventv.module("seventv_zig_api"));
b.installArtifact(seventv.artifact("seventv_zig_api"));
```

main.zig
```zig
const std = @import("std");
const seventv = @import("seventv_zig_api");

pub fn main() !void {
    // Initialize the allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Initialize the SevenTV
    var stv = SevenTV{
        .allocator = allocator,
        .case_sensitive = true,
        .exact_match = true,
    };

    // Select the emoji you want to retrieve
    const emoji_name: [*c]const u8 = "catJAM";
    
    // Retrieve the emoji data
    var emoji: seventv.Emoji = undefined;
    if (stv.searchByName(std.mem.span(emoji_name))) |emoji_tmp| {
        emoji = emoji_tmp;
    } else |emoji_error| {
        return emoji_error;
    }
}
```
---
## License
This project is licensed under the LGPL-3.0-or-later License. See the [LICENSE](LICENSE) file for more information.