# ZEmC
Zig Embedded Containers

A collection of embedded containers for Zig inspired by the linux kernel's implementation.

## Circular doubly linked list

``` 
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
```

