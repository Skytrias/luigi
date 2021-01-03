package engine

import "core:fmt"
import sdl "shared:odin-sdl2"

System_Cursor :: sdl.System_Cursor;

// globals
theme_default := Theme {
    panel1 = { 240, 240, 240, 255 },
    panel2 = WHITE,
    
    text = BLACK,
    
    border = { 64, 64, 64, 255 },
    
    button_normal = { 224, 224, 224, 255 },
    button_hovered = { 240, 240, 240, 255 },
    button_pressed = { 160, 160, 160, 255 },
    button_focused = { 211, 228, 255, 255 },
};

sizes_default := Sizes {
    button_minimum_width = 100,
    button_height = 27,
    menu_item_height = 24,
    menu_item_minimum_width = 160,
    menu_item_margin = 9,
    splitter = 8,
    slider_height = 25,
    slider_width = 200,
    slider_track = 3,
    slider_thumb = 15,
};

ui := Ui {
    theme = theme_default,
    sizes = sizes_default,
};

@(deferred_none=_ui_destroy)
ui_init :: proc() {
    if init_error := sdl.init(.Video | .Events); init_error != 0 {
        fmt.println("SDL2: startup error: (%d)%s", init_error, sdl.get_error());
        return;
    }
    
    ui.font = font_init("font.ttf", 18);
    
    ui.cursors[.Arrow] = sdl.create_system_cursor(.Arrow);
    ui.cursors[.Hand] = sdl.create_system_cursor(.Hand);
    ui.cursors[.IBeam] = sdl.create_system_cursor(.IBeam);
    ui.cursors[.Wait] = sdl.create_system_cursor(.Wait);
    ui.cursors[.Crosshair] = sdl.create_system_cursor(.Crosshair);
    ui.cursors[.Size_WE] = sdl.create_system_cursor(.Size_WE);
    ui.cursors[.Size_NS] = sdl.create_system_cursor(.Size_NS);
}

_ui_destroy :: proc() {
    font_destroy(&ui.font);
    
    for cursor in &ui.cursors {
        sdl.free_cursor(cursor);
    }
}

Messages :: bit_set[Message];
Message :: enum {
	Paint, // dp = pointer to uipainter
	Layout,
	Destroy,
    
	Update,
	Clicked,
	Animate,
	Scrolled,
	ValueChanged,
    
	GetWidth, // di = height (if known); return width
	GetHeight, // di = width (if known); return height
	GetCursor,
	
	LeftDown,
	LeftUp,
	MiddleDown,
	MiddleUp,
	RightDown,
	RightUp,
	KeyTyped, // dp = pointer to uikeytyped; return 1 if handled
    
	MouseMove,
	MouseDrag,
	MouseWheel, // di = delta; return 1 if handled
    
	//table_get_item, // dp = pointer to uitablegetitem; return string length
	//code_get_margin_color, // di = line index (starts at 1); return color
    WindowClose, // return 1 to prevent default (process exit
}

Flags :: bit_set[Flag];
Flag :: enum {
    FillVertical,
    FillHorizontal,
    
    Repaint,
    Hide,
    Destroy,
    DestroyDescendent,
    
    WindowMenu,
    
    PanelHorizontal,
    PanelGray,
    PanelWhite,
    PanelExpand,
    
    ButtonMenuItem,
    ButtonCanFocus,
    
    SpacerLine,
    
    SplitPaneVertical,
    
    MenuPlaceAbove,
}

Align :: enum {
    Center,
    Left,
    Right
}

Theme :: struct {
    panel1, panel2: Color,
    text: Color,
    border: Color,
    button_normal, button_hovered, button_focused, button_pressed: Color,
}

Sizes :: struct {
    button_height: int,
    button_minimum_width: int,
    menu_item_height: int,
    menu_item_minimum_width: int,
    menu_item_margin: int,
    splitter: int,
    slider_height: int,
    slider_width: int,
    slider_track: int,
    slider_thumb: int,
}

Ui :: struct {
    windows: ^Window,
    animating: ^Element,
    theme: Theme,
    sizes: Sizes,
    font: Font,
    stop: bool,
    cursors: [sdl.System_Cursor]^sdl.Cursor,
}

Callback :: proc(element: ^Element, msg: Message, di: int, dp: rawptr) -> int;

Element :: struct {
    parent, child_head, child_tail, prev, next: ^Element,
    window: ^Window,
    
    flags: Flags,
    
    bounds, clip, repaint: Rect,
    
    message_class: Callback,
    message_user: Callback,
    
    name: string,
}

KeyTyped :: struct {
    code: u8,
    scancode: sdl.Scancode,
}

Shortcut :: struct {
    code: u8,
    ctrl, shift, alt: bool,
    invoke: proc(cp: rawptr),
    cp: rawptr,
}

Window :: struct {
    using element: Element,
    
    shortcuts: [dynamic]Shortcut,
	ctrl, shift, alt: bool,
    
    scale: f32,
    
    // used for painting
    draw_clip: Rect,
    draw_width, draw_height: int,
    
	width, height: int,
	next_window: ^Window,
    
    hovered, pressed, focused: ^Element,
	pressed_button: int,
    
    cursor_x, cursor_y: int,
	cursor_style: sdl.System_Cursor,
    
	//update_region: Rect,
    win: ^sdl.Window,
}

Panel :: struct {
    using element: Element,
    border: Rect,
    gap: int,
}

Button :: struct {
    using element: Element,
    label: string,
    invoke: proc(cp: rawptr),
    cp: rawptr,
}

Label :: struct {
    using element: Element,
    label: string,
}

Spacer :: struct {
    using element: Element,
    width, height: int,
}

SplitPane :: struct {
    using element: Element,
    weight: f32,
}

Slider :: struct {
    using element: Element,
    position: f32,
}

Menu :: struct {
    using element: Element,
    point_x, point_y: int,
}