package engine

Rect :: struct {
	l, r, t, b: int,
} 

rect_1 :: proc(x: int) -> Rect { return { x, x, x, x } }
rect_1i :: proc(x: int) -> Rect { return { x, -x, x, -x } }
rect_2 :: proc(x, y: int) -> Rect { return { x, x, y, y } }
rect_2i :: proc(x, y: int) -> Rect { return { x, -x, y, -y } }
rect_2s :: proc(x, y: int) -> Rect { return { 0, x, 0, y } }
rect_4 :: proc(x, y, z, w: int) -> Rect { return { x, y, z, w } }
rect_width :: proc(using rect: Rect) -> int { return r - l }
rect_height :: proc(using rect: Rect) -> int { return b - t }
rect_total_h :: proc(using rect: Rect) -> int { return r + l }
rect_total_v :: proc(using rect: Rect) -> int { return b + t }
rect_valid :: proc(rect: Rect) -> bool { 
    return rect_width(rect) > 0 && rect_height(rect) > 0;
}

rect_intersection :: proc(a, b: Rect) -> Rect {
    a := a;
    if a.l < b.l do a.l = b.l;
	if a.t < b.t do a.t = b.t;
	if a.r > b.r do a.r = b.r;
	if a.b > b.b do a.b = b.b;
	return a;
}

rect_bounding :: proc(a, b: Rect) -> Rect {
    a := a;
    if a.l > b.l do a.l = b.l;
	if a.t > b.t do a.t = b.t;
	if a.r < b.r do a.r = b.r;
	if a.b < b.b do a.b = b.b;
    return a;
}

rect_add :: proc(a, b: Rect) -> Rect {
    a := a;
    a.l += b.l;
	a.t += b.t;
	a.r += b.r;
	a.b += b.b;
	return a;
}

rect_translate :: proc(a, b: Rect) -> Rect {
	a := a;
    a.l += b.l;
	a.t += b.t;
	a.r += b.l;
	a.b += b.t;
	return a;
}

rect_equals :: proc(a, b: Rect) -> bool {
    return a.l == b.l && a.r == b.r && a.t == b.t && a.b == b.b;
}

rect_contains :: proc(a: Rect, x, y: int) -> bool {
    return a.l <= x && a.r > x && a.t <= y && a.b > y;
}
