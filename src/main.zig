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
    case_sensitive: ?bool = null,
    animated: ?bool = null,
    exact_match: ?bool = null,

    pub fn searchByName(self: SevenTV, name: [:0] const u8) !Emoji {
        var client = std.http.Client { .allocator = self.allocator };
        defer client.deinit();

        var endpoint = "https://7tv.io/v3/gql";
        const uri = try std.Uri.parse(endpoint);

        var headers = std.http.Headers{ .allocator = self.allocator };
        defer headers.deinit();
        try headers.append("Content-Type", "application/json");

        var query = "query SearchEmotes($query: String!, $page: Int, $sort: Sort, $limit: Int, $filter: EmoteSearchFilter) {\n emotes(query: $query, page: $page, sort: $sort, limit: $limit, filter: $filter) {\nitems{\n id\n name\n owner{\n username\n }\n host{\n url}}\n}\n}";

        var payload = .{
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
                    // .animated = self.animated,
                    .animated = true,
                    .aspect_ratio = ""
                },
            },
            .query = query,
        };

        var req = try client.request(.POST, uri, headers, .{});
        defer req.deinit();

        req.transfer_encoding = .chunked;

        try req.start(.{});

        var payload_stringified = try std.json.stringifyAlloc(self.allocator, payload, .{});
        try req.writer().writeAll(payload_stringified);

        try req.finish();

        try req.wait();

        const response = req.response;

        if (response.status != std.http.Status.ok) {
            return error.NoEmojiFound;
        }
        const response_body = try req.reader().readAllAlloc(self.allocator, 8192);

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
            .{},
        );
        defer parsed.deinit();

        const result = Emoji {
            .id = parsed.value.data.emotes.items[0].id,
            .name = parsed.value.data.emotes.items[0].name,
            .owner_username = parsed.value.data.emotes.items[0].owner.username,
            .host_url = parsed.value.data.emotes.items[0].host.url,
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
        .case_sensitive = true,
        .exact_match = true,
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
