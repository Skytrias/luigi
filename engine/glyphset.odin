package engine

import stbtt "shared:odin-stb/stbtt"
import "core:math"

// glyphset for font characters
MAX_GLYPHSET :: 256;
GlyphSet :: struct {
    image: Image,
    glyphs: []stbtt.Baked_Char,
    alive: bool,
}

// init all glyphset characters
@(private)
glyphset_init :: proc(font: ^Font, idx: int) -> (set: GlyphSet) {
    using stbtt;
    
    width := 128;
    height := 128;
    pixels: []u8;
    defer delete(pixels);
    
    for {
        pixels = make([]u8, width * height);
        
        res := 0;
        /* load glyphs */
        s := stbtt_ScaleForMappingEmToPixels(&font.stb_font, 1) /
            stbtt_ScaleForPixelHeight(&font.stb_font, 1);
        
        set.glyphs, res = bake_font_bitmap(font.data,
                                           0,
                                           font.size * s,
                                           pixels,
                                           width,
                                           height,
                                           idx * MAX_GLYPHSET,
                                           MAX_GLYPHSET
                                           );
        
        /* retry with a larger image buffer if the buffer wasn't large enough */
        if res < 0 {
            width *= 2;
            height *= 2;
            delete(pixels);
            delete(set.glyphs);
        } else {
            break;
        }
    }
    
    /* adjust glyph yoffsets and xadvance */
    ascent, _, _ := get_font_v_metrics(&font.stb_font);
    scale := stbtt_ScaleForMappingEmToPixels(&font.stb_font, font.size);
    scaled_ascent := f32(ascent) * scale + 0.5;
    for i := 0; i < 256; i += 1 {
        set.glyphs[i].yoff += scaled_ascent;
        set.glyphs[i].xadvance = math.floor(set.glyphs[i].xadvance);
    }
    
    set.image = image_init(width, height);
    for i := width * height - 1; i >= 0; i -= 1 {
        //set.image.pixels[i] = { 255, 255, 255, pixels[i] };
        set.image.pixels[i] = u32(pixels[i]);
    }
    
    return set;
}

// glyphset from the rune given in by the font
@(private)
glyphset_get :: proc(font: ^Font, codepoint: int) -> ^GlyphSet {
    idx := (codepoint >> 8) % MAX_GLYPHSET;
    
    if !font.sets[idx].alive {
        font.sets[idx] = glyphset_init(font, idx);
        font.sets[idx].alive = true;
    }
    
    return &font.sets[idx];
}
