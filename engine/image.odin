package engine

import "core:fmt"
import "core:mem"
import stbi "shared:odin-stb/stbi"

// image that can be drawn
Image :: struct {
    pixels: []u32,
    width: int,
    height: int,
}

// init zeroed image data
image_init :: proc(width, height: int) -> Image {
    assert(width > 0 && height > 0);
    
    return {
        pixels = make([]u32, width * height * size_of(u32)),
        width = width,
        height = height,
    };
}

// destroy pixel data
image_destroy :: proc(image: ^Image) {
    delete(image.pixels);
}

image_load :: proc(filepath: cstring) -> Image {
    w, h, channels: i32;
    bytes := stbi.load(filepath, &w, &h, &channels, 0);
    defer stbi.image_free(bytes);
    pixels := make([]u32, w * h);
    mem.copy(&pixels[0], bytes, int(w * h) * size_of(u8) * 4);
    
    return {
        width = cast(int) w,
        height = cast(int) h,
        pixels = pixels,
    };
}