package engine

import "core:fmt"

Color :: struct { b, g, r, a: u8 }
ImageColor :: struct { a, r, g, b: u8 };

BLUE :: Color { 255, 0, 0, 255 };
GREEN :: Color { 0, 255, 0, 255 };
RED :: Color { 0, 0, 255, 255 };
WHITE :: Color { 255, 255, 255, 255 };
BLACK :: Color { 0, 0, 0, 255 };

color_blend_2 :: proc(dst, src: Color) -> (result: Color) {
    ia: u16 = 0xff - u16(src.a);
    
    result.r = u8(((u16(src.r) * u16(src.a)) + (u16(u16(dst.r) * ia))) >> 8);
    result.g = u8(((u16(src.g) * u16(src.a)) + (u16(u16(dst.g) * ia))) >> 8);
    result.b = u8(((u16(src.b) * u16(src.a)) + (u16(u16(dst.b) * ia))) >> 8);
    //result.a = u8(((u16(src.a) * u16(src.a)) + (u16(u16(dst.a) * ia))) >> 8);
    
    return;
}

// TODO(Skytrias): fix
color_blend_3 :: proc(dst, src, color: Color) -> Color {
    dst := dst;
    
    src := transmute(ImageColor) src;
    src.a = u8((u16(src.a) * u16(color.a)) >> 8);
    ia: u16 = 0xff - u16(src.a);
    
    dst.r = u8(((u16(color.r) * u16(src.a)) >> 8) + u16((u16(dst.r) * ia) >> 8));
    dst.g = u8(((u16(color.g) * u16(src.a)) >> 8) + u16((u16(dst.g) * ia) >> 8));
    dst.b = u8(((u16(color.b) * u16(src.a)) >> 8) + u16((u16(dst.b) * ia) >> 8));
    //fmt.println(src, color, dst, ia);
    
    return dst;
}
