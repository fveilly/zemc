const std = @import("std");
const expectEqual = std.testing.expectEqual;
const expect = std.testing.expect;
const assert = std.debug.assert;

const ListHead = struct {
    next: ?*ListHead,
    prev: ?*ListHead,

    pub fn default() ListHead {
        return ListHead{
            .next = null,
            .prev = null,
        };
    }
    pub inline fn add(self: *ListHead, new: *ListHead) void {
        list_add(new, self);
    }
    pub inline fn replace(self: *ListHead, new: *ListHead) void {
        list_replace(self, new);
        list_init(self);
    }
    pub inline fn swap(self: *ListHead, entry: *ListHead) void {
        list_swap(self, entry);
    }
    pub inline fn move(self: *ListHead, head: *ListHead) void {
        list_move(self, head);
    }
    pub inline fn move_tail(self: *ListHead, head: *ListHead) void {
        list_move_tail(self, head);
    }
    pub inline fn empty(self: *ListHead) bool {
        return list_empty(self);
    }
    pub inline fn is_singular(self: *ListHead) bool {
        return list_is_singular(self);
    }
    pub inline fn is_head(self: *ListHead, entry: *ListHead) bool {
        return list_is_head(entry, self);
    }
    pub inline fn is_first(self: *ListHead, entry: *ListHead) bool {
        return list_is_first(entry, self);
    }
    pub inline fn is_last(self: *ListHead, entry: *ListHead) bool {
        return list_is_last(entry, self);
    }
};

fn ReadOnce(comptime T: type, x: *?*T) *T {
    return x.*.?;
}

fn WriteOnce(comptime T: type, x: *?*T, val: *T) void {
    //@volatileStore(x, val);
    x.* = val;
}

/// Initialize a ListHead structure
pub inline fn list_init(list: *ListHead) void {
    WriteOnce(ListHead, &list.next, list);
    WriteOnce(ListHead, &list.prev, list);
}

/// Tests whether @entry is the list @head
pub inline fn list_is_head(entry: *ListHead, head: *ListHead) bool {
    return entry == head;
}

/// Tests whether @entry is the first entry in list @head
pub inline fn list_is_first(entry: *ListHead, head: *ListHead) bool {
    return entry.prev == head;
}

/// Tests whether @entry is the last entry in list @head
pub inline fn list_is_last(entry: *ListHead, head: *ListHead) bool {
    return entry.next == head;
}

/// Tests whether a list is empty
pub inline fn list_empty(head: *ListHead) bool {
    return ReadOnce(ListHead, &head.next) == head;
}

/// Tests whether a list has juste one entry
pub inline fn list_is_singular(head: *ListHead) bool {
    return !list_empty(head) and (head.next == head.prev);
}

/// Insert a new entry between two known consecutive entries
inline fn list_insert(new: *ListHead, prev: *ListHead, next: *ListHead) void {
    next.prev = new;
    new.next = next;
    new.prev = prev;
    WriteOnce(ListHead, &prev.next, new);
}

/// Insert a new entry after the specified head
pub inline fn list_add(new: *ListHead, head: *ListHead) void {
    list_insert(new, head, head.next.?);
}

/// Insert a new entry before the specified head
pub inline fn list_add_tail(new: *ListHead, head: *ListHead) void {
    list_insert(new, head.prev.?, head);
}

inline fn list_del_internal(prev: *ListHead, next: *ListHead) void {
    next.prev = prev;
    WriteOnce(ListHead, &prev.next, next);
}

/// Delete a list entry by making the prev/next entries point to each other
pub inline fn list_del(entry: *ListHead) void {
    if (entry.prev) |prev| {
        if (entry.next) |next| {
            list_del_internal(prev, next);
            entry.next = null;
            entry.prev = null;
        }
    }
}

/// Replace old entry by a new one
pub inline fn list_replace(old: *ListHead, new: *ListHead) void {
    new.next = old.next;
    new.next.prev = new;
    new.prev = old.prev;
    new.prev.next = new;
}

/// Swap entry1 with entry2
pub inline fn list_swap(entry1: *ListHead, entry2: *ListHead) void {
    const pos = entry2.prev;
    list_del(entry2);
    list_replace(entry1, entry2);
    if (pos == entry1) {
        pos = entry2;
    }
    list_add(entry1, pos);
}

/// Delete from one list and add to as annother's head
pub inline fn list_move(list: *ListHead, entry: *ListHead) void {
    list_del(entry);
    list_add(entry, list);
}

/// Delete from onen list annd add as annother's tail
pub inline fn list_move_tail(list: *ListHead, entry: *ListHead) void {
    list_del(entry);
    list_add_tail(entry, list);
}

/// Get the struct for this entry
pub inline fn list_entry(comptime ParentType: type, comptime field_name: []const u8, field_ptr: *ListHead) *ParentType {
    return @fieldParentPtr(ParentType, field_name, field_ptr);
}

/// Get the first element from a list. The list is expected to be not empty.
pub inline fn list_first_entry(comptime ParentType: type, comptime field_name: []const u8, head: *ListHead) *ParentType {
    return list_entry(ParentType, field_name, head.next.?);
}

/// Get the last element from a list. The list is expected to be not empty.
pub inline fn list_last_entry(comptime ParentType: type, comptime field_name: []const u8, head: *ListHead) *ParentType {
    return list_entry(ParentType, field_name, head.prev.?);
}

/// Get the first element from a list or null if the list is empty.
pub inline fn list_first_entry_or_null(comptime ParentType: type, comptime field_name: []const u8, head: *ListHead) ?*ParentType {
    const next = ReadOnce(ListHead, &head.next);
    return if (next != head) list_entry(ParentType, field_name, next) else null;
}

/// Get the last element from a list or null if the list is empty.
pub inline fn list_last_entry_or_null(comptime ParentType: type, comptime field_name: []const u8, head: *ListHead) ?*ParentType {
    const prev = ReadOnce(ListHead, &head.prev);
    return if (prev != head) list_entry(ParentType, field_name, prev) else null;
}

pub fn ListIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        head: *ListHead,
        cursor: *ListHead,
        offset: usize,

        pub fn init(head: *ListHead, comptime field_name: []const u8) Self {
            return .{
                .head = head,
                .cursor = head.next.?,
                .offset = @offsetOf(T, field_name),
            };
        }

        pub fn next(self: *Self) ?*T {
            if (list_is_head(self.cursor, self.head)) {
                return null;
            }

            defer self.cursor = self.cursor.next.?;
            return @as(*T, @ptrFromInt(@intFromPtr(self.cursor) - self.offset));
        }
    };
}

pub fn ListReverseIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        head: *ListHead,
        cursor: *ListHead,
        offset: usize,

        pub fn init(head: *ListHead, comptime field_name: []const u8) Self {
            return .{
                .head = head,
                .cursor = head.prev.?,
                .offset = @offsetOf(T, field_name),
            };
        }

        pub fn next(self: *Self) ?*T {
            if (list_is_head(self.cursor, self.head)) {
                return null;
            }

            defer self.cursor = self.cursor.prev.?;
            return @as(*T, @ptrFromInt(@intFromPtr(self.cursor) - self.offset));
        }
    };
}

pub fn ListIteratorRaw() type {
    return struct {
        const Self = @This();

        head: *ListHead,
        cursor: *ListHead,
        n: *ListHead,

        pub fn init(head: *ListHead) Self {
            return .{
                .head = head,
                .cursor = head.next.?,
                .n = head.next.?.next.?,
            };
        }

        pub fn next(self: *Self) ?*ListHead {
            if (list_is_head(self.cursor, self.head)) {
                return null;
            }

            defer self.n = self.n.next.?;
            defer self.cursor = self.n;
            return self.cursor;
        }
    };
}

pub fn ListReverseIteratorRaw() type {
    return struct {
        const Self = @This();

        head: *ListHead,
        cursor: *ListHead,
        n: *ListHead,

        pub fn init(head: *ListHead) Self {
            return .{
                .head = head,
                .cursor = head.prev.?,
                .n = head.prev.?.prev.?,
            };
        }

        pub fn next(self: *Self) ?*ListHead {
            if (list_is_head(self.cursor, self.head)) {
                return null;
            }

            defer self.n = self.n.prev.?;
            defer self.cursor = self.n;
            return self.cursor;
        }
    };
}

test "basic test" {
    const Point = struct { x: i32, y: i32, list_ref: ListHead };
    const Object = struct { a: i32, b: i32, list: ListHead, c: i32 };

    var object: Object = .{
        .a = 1,
        .b = 2,
        .list = ListHead.default(),
        .c = 3,
    };

    list_init(&object.list);

    var p1: Point = .{ .x = 13, .y = 64, .list_ref = ListHead.default() };
    var p2: Point = .{ .x = 14, .y = 65, .list_ref = ListHead.default() };

    object.list.add(&p1.list_ref);
    object.list.add(&p2.list_ref);

    const first = list_first_entry(Point, "list_ref", &object.list);
    try expectEqual(first.x, 14);
    try expectEqual(first.y, 65);
    try expect(object.list.is_first(&first.list_ref));

    const last = list_last_entry(Point, "list_ref", &object.list);
    try expectEqual(last.x, 13);
    try expectEqual(last.y, 64);
    try expect(object.list.is_last(&last.list_ref));
}

test "remove" {
    const Point = struct { x: i32, y: i32, list_ref: ListHead };
    var list = ListHead.default();
    list_init(&list);

    var p1: Point = .{ .x = 13, .y = 64, .list_ref = ListHead.default() };
    var p2: Point = .{ .x = 14, .y = 65, .list_ref = ListHead.default() };

    list_del(&p1.list_ref);

    try expect(list.empty());
    list.add(&p1.list_ref);
    list.add(&p2.list_ref);

    try expect(!list.empty());
    try expect(!list.is_singular());

    list_del(&p1.list_ref);
    try expect(list.is_singular());
    list_del(&p2.list_ref);
    try expect(list.empty());

    list_del(&p1.list_ref);
}

test "iterator" {
    const Value = struct { x: usize, list_ref: ListHead };
    var array: [10]Value = undefined;
    var list = ListHead.default();

    list_init(&list);

    for (&array, 0..) |*value, i| {
        value.* = .{
            .x = i,
            .list_ref = ListHead.default(),
        };
        list_add_tail(&value.list_ref, &list);
    }

    var iter = ListIterator(Value).init(&list, "list_ref");
    var i: usize = 0;
    while (iter.next()) |value| : (i += 1) {
        try expectEqual(value.x, i);
    }
}

test "reverse iterator" {
    const Value = struct { x: usize, list_ref: ListHead };
    var array: [10]Value = undefined;
    var list = ListHead.default();

    list_init(&list);

    for (&array, 0..) |*value, i| {
        value.* = .{
            .x = i,
            .list_ref = ListHead.default(),
        };
        list_add_tail(&value.list_ref, &list);
    }

    var iter = ListReverseIterator(Value).init(&list, "list_ref");
    var i: usize = 0;
    while (iter.next()) |value| : (i += 1) {
        try expectEqual(value.x, array.len - i - 1);
    }
}

test "iterator with removal" {
    const Value = struct { x: usize, list_ref: ListHead };
    var array: [10]Value = undefined;
    var list = ListHead.default();

    list_init(&list);

    for (&array, 0..) |*value, i| {
        value.* = .{
            .x = i,
            .list_ref = ListHead.default(),
        };
        list_add_tail(&value.list_ref, &list);
    }

    var iter = ListIteratorRaw().init(&list);
    var i: usize = 0;
    while (iter.next()) |entry| : (i += 1) {
        if (i % 2 == 0) {
            list_del(entry);
            continue;
        }
        const value = list_entry(Value, "list_ref", entry);
        try expectEqual(value.x, i);
    }
}

test "reverse iterator with removal" {
    const Value = struct { x: usize, list_ref: ListHead };
    var array: [10]Value = undefined;
    var list = ListHead.default();

    list_init(&list);

    for (&array, 0..) |*value, i| {
        value.* = .{
            .x = i,
            .list_ref = ListHead.default(),
        };
        list_add_tail(&value.list_ref, &list);
    }

    var iter = ListReverseIteratorRaw().init(&list);
    var i: usize = 0;
    while (iter.next()) |entry| : (i += 1) {
        if (i % 2 == 0) {
            list_del(entry);
            continue;
        }
        const value = list_entry(Value, "list_ref", entry);
        try expectEqual(value.x, array.len - i - 1);
    }
}
