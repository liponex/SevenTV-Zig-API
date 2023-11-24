# An unofficial Zig library for retrieving 7TV Emoji data
This project was done to make it easier to retrieve 7TV Emoji data for use in other projects.
It is not affiliated with 7TV in any way.
---
## Usage
```zig
const std = @import("std");
const seventv = @import("seventv-zig-api");

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