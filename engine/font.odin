package engine

import "core:os"
import "core:unicode/utf8"
import "core:unicode"
import stbtt "shared:odin-stb/stbtt"

// font data
Font :: struct {
    data: []u8,
    stb_font: stbtt.stbtt_fontinfo,
    sets: []GlyphSet,
    size: f32,
    height: int,
}

// init a font via a filename and give in a size
font_init :: proc(filename: string, size: f32) -> (font: Font) {
    using stbtt;
    font.size = size;
    
    success: bool;
    font.sets = make([]GlyphSet, MAX_GLYPHSET);
    font.data, success = os.read_entire_file(filename);
    
    /* init stbfont */
    ok := init_font(&font.stb_font, font.data, 0);
    if !ok do panic("load font failed");
    
    /* get height and scale */
    ascent, descent, linegap := get_font_v_metrics(&font.stb_font);
    scale := stbtt_ScaleForMappingEmToPixels(&font.stb_font, size);
    font.height = int(f32(ascent - descent + linegap) * scale + 0.5);
    
    /* make tab and newline glyphs invisible */
    g := glyphset_get(&font, '\n').glyphs;
    g['\t'].x1 = g['\t'].x0;
    g['\n'].x1 = g['\n'].x0;
    
    return;
}

// destroy the font memory and inner data
font_destroy :: proc(using font: ^Font) {
    for i in 0..<MAX_GLYPHSET {
        set := font.sets[i];
        image_destroy(&set.image);
        delete(set.glyphs);
    }
    
    delete(data);
    delete(sets);
}

font_get_char_width :: proc(font: ^Font, c: u8) -> f32 {
    set := glyphset_get(font, cast(int) c);
    return set.glyphs[c & 0xff].xadvance;
}

font_text_width :: proc(font: ^Font, text: string) -> (x_max: f32) {
    runes := utf8.string_to_runes(text);
    defer delete(runes);
    
    for c in runes {
        set := glyphset_get(font, cast(int) c);
        g := &set.glyphs[c & 0xff];
        x_max += g.xadvance;
    }
    
    return;
}

// get width of text via the font
font_text_width_column :: proc(font: ^Font, text: string, upper: bool = false, column: int = -1) -> (x_max: f32, column_pos: f32) {
    runes := utf8.string_to_runes(text);
    defer delete(runes);
    
    for c, i in runes {
        set := glyphset_get(font, cast(int) c);
        c := c;
        if upper && i == 0 do c = unicode.to_upper(c);
        
        if column != -1 && i == column {
            column_pos = x_max;
        }
        
        g := &set.glyphs[c & 0xff];
        x_max += g.xadvance;
    }
    
    if column != -1 && column == len(runes) {
        column_pos = x_max;
    }
    
    return;
}

font_get_column :: proc(font: ^Font, text: string, x: f32) -> (column: int) {
    runes := utf8.string_to_runes(text);
    defer delete(runes);
    
    total: f32 = 0;
    for c in runes {
        set := glyphset_get(font, cast(int) c);
        g := &set.glyphs[c & 0xff];
        
        if total >= x {
            return column - 1;
        }
        
        total += g.xadvance;
        column += 1;
    }
    
    return column;
}