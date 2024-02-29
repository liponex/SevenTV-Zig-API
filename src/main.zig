const std = @import("std");
const testing = std.testing;

pub const Emoji = struct {
    id: []u8,
    name: []u8,
    owner_username: []u8,
    host_url: []u8,
};

pub const SevenTV = struct {
    allocator: std.mem.Allocator,
    limit: u32 = 12,
    page: u32 = 1,
    case_sensitive: ?bool = true,
    animated: ?bool = true,
    exact_match: ?bool = true,

    pub fn searchByName(self: SevenTV, name: [:0] const u8) !Emoji {
        var client = std.http.Client { .allocator = self.allocator };
        defer client.deinit();

        const endpoint = "https://7tv.io/v3/gql";
        const uri = try std.Uri.parse(endpoint);

        const headers = std.http.Client.Request.Headers{
            .content_type = std.http.Client.Request.Headers.Value {
                .override = "application/json",
            },
        };

        const query = @embedFile("gql/searchEmotes.graphql");

        const payload = .{
            .operationName = "SearchEmotes",
            .variables = .{
                .query = name,
                .limit = self.limit,
                .page = self.page,
                .sort = .{
                    .value = "popularity",
                    .order = "DESCENDING"
                },
                .filter = .{
                    .category = "TOP",
                    .exact_match = self.exact_match,
                    .case_sensitive = self.case_sensitive,
                    .ignore_tags = false,
                    .zero_width = false,
                    .animated = self.animated,
                    .aspect_ratio = ""
                },
            },
            .query = query,
        };

        const server_header_buffer: []u8 = try self.allocator.alloc(u8, 8*1024*4);

        var req = try client.open(.POST, uri, std.http.Client.RequestOptions{
            .server_header_buffer = server_header_buffer,
            .headers = headers,
        });
        defer req.deinit();

        req.transfer_encoding = .chunked;

        try req.send(.{});

        const payload_stringified = try std.json.stringifyAlloc(self.allocator, payload, .{});
        try req.writer().writeAll(payload_stringified);

        try req.finish();

        try req.wait();

        const response = req.response;

        if (response.status != std.http.Status.ok) {
            return error.NoEmojiFound;
        }

        const response_body = try req.reader().readAllAlloc(self.allocator, 8*1024*4);

        const emojiResponse = struct {
            data: struct {
                emotes: struct {
                    items: [] struct {
                        id: []u8,
                        name: []u8,
                        owner: struct {
                            username: []u8,
                        },
                        host: struct {
                            url: []u8,
                        }
                    }
                }
            }
        };

        var parsed = try std.json.parseFromSlice(
            emojiResponse,
            self.allocator,
            response_body,
            .{
                .ignore_unknown_fields = true,
            },
        );
        defer parsed.deinit();

        var flag: usize = 0;
        for (parsed.value.data.emotes.items, 0..) |value, i| {
            if (std.mem.eql(u8, value.name, name)) {
                flag = i;
                break;
            }
        }
        
        const result = Emoji {
            .id = parsed.value.data.emotes.items[flag].id,
            .name = parsed.value.data.emotes.items[flag].name,
            .owner_username = parsed.value.data.emotes.items[flag].owner.username,
            .host_url = parsed.value.data.emotes.items[flag].host.url,
        };

        // std.log.info(
        // \\
        // \\response result:
        // \\main.Emoji.id: {s}
        // \\main.Emoji.name: {s}
        // \\main.Emoji.owner_username: {s}
        // \\main.Emoji.host_url: {s}
        // , .{result.id, result.name, result.owner_username, result.host_url});

        return result;
    }
};

test "Search for 7TV emoji by name" {
    // testing.log_level = .debug;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var stv = SevenTV{
        .allocator = allocator,
    };

    const emoji_name: [*c]const u8 = "catJAM";

    if (stv.searchByName(std.mem.span(emoji_name))) |emoji| {
        try testing.expect(std.mem.eql(u8,
            emoji.name,
            "catJAM"),
        );
    } else |emoji_error| {
        std.log.err("{any}", .{ emoji_error });
        try testing.expect(false);
    }
}
