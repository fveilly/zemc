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
    pub inline fn add_tail(self: *ListHead, new: *ListHead) void {
        list_add_tail(new, self);
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

/// Insert a new entry after the specified entry
pub inline fn list_add(new: *ListHead, entry: *ListHead) void {
    list_insert(new, entry, entry.next.?);
}

/// Insert a new entry before the specified entry
pub inline fn list_add_tail(new: *ListHead, entry: *ListHead) void {
    list_insert(new, entry.prev.?, entry);
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

pub inline fn list_replace_internal(old: *ListHead, new: *ListHead) void {
    if (old.next) |next| {
        new.next = next;
        next.prev = new;
    }
    if (old.prev) |prev| {
        new.prev = prev;
        prev.next = new;
    }
}

/// Replace old entry by a new one
/// #SAFETY: The new entry MUST not be contained in a list.
///          Old and new entries MUST be different.
pub inline fn list_replace_unsafe(old: *ListHead, new: *ListHead) void {
    assert(new.next == null and new.prev == null);
    assert(old != new);
    list_replace_internal(old, new);
    old.next = null;
    old.prev = null;
}

/// Replace old entry by a new one
/// If the new entry is contained on a list, remove it beforehand.
pub inline fn list_replace(old: *ListHead, new: *ListHead) void {
    if (old != new) {
        list_del(new);
        list_replace_unsafe(old, new);
    }
}

/// Swap entry1 with entry2
pub inline fn list_swap_unsafe(entry1: *ListHead, entry2: *ListHead) void {
    assert(entry1 != entry2);

    if (entry2.next) |next| {
        if (entry2.prev) |prev| {
            list_del_internal(prev, next);
            // Replace entry1 with entry2
            list_replace_internal(entry1, entry2);
            // entry1 precede entry2
            if (prev == entry1) {
                list_add(entry1, entry2);
            } else {
                list_add(entry1, prev);
            }
        } else {
            unreachable;
        }
    } else {
        // Replace entry1 with entry2
        list_replace_unsafe(entry1, entry2);
    }
}

/// Swap entry1 with entry2
pub inline fn list_swap(entry1: *ListHead, entry2: *ListHead) void {
    if (entry1 != entry2) {
        list_swap_unsafe(entry1, entry2);
    }
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

test "example" {
    // Any structure containing ListHead can be added to the list
    const Point = struct { x: i32, y: i32, list_ref: ListHead };

    // Initialize the head of the list
    var list = ListHead.default();
    list_init(&list);

    var p1: Point = .{ .x = 13, .y = 64, .list_ref = ListHead.default() };
    var p2: Point = .{ .x = 14, .y = 65, .list_ref = ListHead.default() };

    // Add two elements to the list
    list.add(&p1.list_ref);
    list.add_tail(&p2.list_ref);

    // Iterate over the list
    var iter = ListIterator(Point).init(&list, "list_ref");
    while (iter.next()) |value| {
        value.x += 1;
    }

    // Iterate over the list and remove all the elements
    var rawIter = ListIteratorRaw().init(&list);
    while (rawIter.next()) |entry| {
        list_del(entry);
    }

    try expect(list.empty());
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

test "replace" {
    const Point = struct { x: i32, y: i32, list_ref: ListHead };
    var list = ListHead.default();
    list_init(&list);

    var p1: Point = .{ .x = 13, .y = 64, .list_ref = ListHead.default() };
    var p2: Point = .{ .x = 14, .y = 65, .list_ref = ListHead.default() };

    // Replacing an entry that is not contained in a list should have no effect
    list_replace(&p1.list_ref, &p2.list_ref);
    list_replace_unsafe(&p1.list_ref, &p2.list_ref);

    list.add(&p1.list_ref);

    // Replacing an entry by itself should have no effect
    list_replace(&p1.list_ref, &p1.list_ref);

    var first = list_first_entry(Point, "list_ref", &list);
    try expectEqual(first.x, 13);
    try expectEqual(first.y, 64);

    list_replace(&p2.list_ref, &p1.list_ref);
    try expect(list.empty());
    list.add(&p1.list_ref);

    list_replace(&p1.list_ref, &p2.list_ref);

    first = list_first_entry(Point, "list_ref", &list);
    try expectEqual(first.x, 14);
    try expectEqual(first.y, 65);

    try expect(list.is_singular());
}

test "swap" {
    const Point = struct { x: i32, y: i32, list_ref: ListHead };
    var list = ListHead.default();
    list_init(&list);

    var p1: Point = .{ .x = 13, .y = 64, .list_ref = ListHead.default() };
    var p2: Point = .{ .x = 14, .y = 65, .list_ref = ListHead.default() };
    var p3: Point = .{ .x = 2, .y = 14, .list_ref = ListHead.default() };

    // Swapping two items that are not part of a list should result in no changes
    list_swap(&p1.list_ref, &p2.list_ref);

    list.add(&p1.list_ref);

    // Swapping an entry with itself should result in no change
    list_swap(&p1.list_ref, &p1.list_ref);

    var first = list_first_entry(Point, "list_ref", &list);
    try expectEqual(first.x, 13);
    try expectEqual(first.y, 64);

    // Swapping an entry with one that is not in the list should result in the replacement of the entry
    list_swap(&p1.list_ref, &p2.list_ref);

    first = list_first_entry(Point, "list_ref", &list);
    try expectEqual(first.x, 14);
    try expectEqual(first.y, 65);

    list.add(&p1.list_ref);

    first = list_first_entry(Point, "list_ref", &list);
    try expectEqual(first.x, 13);
    try expectEqual(first.y, 64);

    list_swap(&p1.list_ref, &p2.list_ref);

    first = list_first_entry(Point, "list_ref", &list);
    try expectEqual(first.x, 14);
    try expectEqual(first.y, 65);

    list_swap(&p2.list_ref, &p3.list_ref);

    first = list_first_entry(Point, "list_ref", &list);
    try expectEqual(first.x, 2);
    try expectEqual(first.y, 14);
}
