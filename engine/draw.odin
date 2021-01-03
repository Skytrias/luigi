package engine

import "core:mem"
import "core:fmt"
import "core:unicode"
import "core:unicode/utf8"
import sdl "shared:odin-sdl2"

draw_rect_outlined :: proc(window: ^Window, r: Rect, main_color, border_color: Color, border_size: Rect) {
    draw_rect(window, rect_4(r.l, r.r, r.t, r.t + border_size.t), border_color);
	draw_rect(window, rect_4(r.l, r.l + border_size.l, r.t + border_size.t, r.b - border_size.b), border_color);
	draw_rect(window, rect_4(r.l + border_size.l, r.r - border_size.r, r.t + border_size.t, r.b - border_size.b), main_color);
	draw_rect(window, rect_4(r.r - border_size.r, r.r, r.t + border_size.t, r.b - border_size.b), border_color);
	draw_rect(window, rect_4(r.l, r.r, r.b - border_size.b, r.b), border_color);
}

// draws a rectangle
draw_rect :: proc(window: ^Window, rect: Rect, color: Color) {
    if color.a == 0 do return;
    
    intersection := rect_intersection(window.draw_clip, rect);
    if !rect_valid(intersection) do return;
    
    surface := sdl.get_window_surface(window.win);
    width := window.width;
    d := cast(^Color) surface.pixels;
    d = mem.ptr_offset(d, intersection.l + intersection.t * width);
    dr := width - rect_width(intersection);
    
    for j := intersection.t; j < intersection.b; j += 1 {
        for i := intersection.l; i < intersection.r; i += 1 {
            d^ = color;
            d = mem.ptr_offset(d, 1);
        }
        
        d = mem.ptr_offset(d, dr);
    }
}

// draw an image
draw_image :: proc(window: ^Window, image: ^Image, sub: ^Rect, x, y: int, color: Color) {
    if color.a == 0 do return;
    
    x := x;
    y := y;
    
    /* window.draw_clip */
    if window.draw_clip.l - x > 0 {
        n := window.draw_clip.l - x;
        sub.l += n;
        x += n;
    }
    if window.draw_clip.t - y > 0 {
        n := window.draw_clip.t - y;
        sub.t += n;
        y += n;
    }
    if x + rect_width(sub^) - window.draw_clip.r > 0 {
        sub.r -= x + rect_width(sub^) - window.draw_clip.r;
    }
    if y + rect_height(sub^) - window.draw_clip.b > 0 {
        sub.b -= y + rect_height(sub^) - window.draw_clip.b;
    }
    
    if !rect_valid(sub^) do return;
    //if  <= 0 || sub.h <= 0 do return;
    
    surface := sdl.get_window_surface(window.win);
    width := window.width;
    s := cast(^Color) &image.pixels[0];
    d := cast(^Color) surface.pixels;
    s = mem.ptr_offset(s, sub.l + sub.t * image.width);
    d = mem.ptr_offset(d, x + y * width);
    sr := image.width - rect_width(sub^);
    dr := width - rect_width(sub^);
    
    for j := 0; j < rect_height(sub^); j += 1 {
        for i := 0; i < rect_width(sub^); i += 1 {
            d^ = color_blend_3(d^, s^, color);
            d = mem.ptr_offset(d, 1);
            s = mem.ptr_offset(s, 1);
        }
        
        d = mem.ptr_offset(d, dr);
        s = mem.ptr_offset(s, sr);
    }
}

draw_text :: proc(window: ^Window, font: ^Font, x, y: int, label: string, color: Color) {
    if color.a == 0 do return;
    
    x := cast(f32) x;
    
    runes := utf8.string_to_runes(label);
    defer delete(runes);
    
    rect: Rect;
    
    for test, i in runes { 
        set := glyphset_get(font, cast(int) test);
        g := &set.glyphs[test & 0xff];
        rect.l = int(g.x0);
        rect.t = int(g.y0);
        rect.r = int(g.x1); 
        rect.b = int(g.y1); 
        draw_image(window, &set.image, &rect, cast(int) x + cast(int) g.xoff, y + cast(int) g.yoff, color);
        x += g.xadvance;
    }
}

draw_text_aligned :: proc(window: ^Window, rect: Rect, label: string, color: Color, align: Align) {
    if color.a == 0 do return;
    
    old_clip := window.draw_clip;
    window.draw_clip = rect_intersection(rect, old_clip);
    
    if !rect_valid(window.draw_clip) {
        window.draw_clip = old_clip;
        return;
    }
    
    width := rect_width(rect);
    height := rect_height(rect);
    
    y := height / 2 - ui.font.height / 2 + rect.t;
    x: int;
    
    switch align {
        case .Center: {
            x = rect.l + width / 2 - int(text_widthf(label) / 2);
        }
        
        case .Left: {
            x = rect.l + 5;
        }
        
        case .Right: {
            x = rect.l + width - text_width(label);
        }
    }
    
    draw_text(window, &ui.font, int(x), int(y), label, color);
    window.draw_clip = old_clip;
}
