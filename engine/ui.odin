package engine

import "core:mem"
import "core:fmt"
import sdl "shared:odin-sdl2"

// TODO(Skytrias): quit only affect one window

element_message :: proc(element: ^Element, message: Message, di: int = 0, dp: rawptr = nil) -> int {
    if Message.Destroy != message && .Destroy in element.flags do return 0;
    
	if element.message_user != nil {
		result := element.message_user(element, message, di, dp);
        
		if result == 1 {
			return result;
		}
	}
    
	if element.message_class != nil {
		return element.message_class(element, message, di, dp);
	} else {
		return 0;
	}
}

element_refresh :: proc(element: ^Element) {
    element_message(element, .Layout);
    element_repaint(element, nil);
}

element_repaint :: proc(element: ^Element, region: ^Rect) {
    region := region;
    
    if region == nil do region = &element.bounds;
    r := rect_intersection(region^, element.clip);
    if !rect_valid(r) {
        return;
    }
    
    changed := false;
    if .Repaint in element.flags {
        old := element.repaint;
        element.repaint = rect_bounding(element.repaint, r);
        changed = !rect_equals(element.repaint, old);
    } else {
        incl(&element.flags, Flag.Repaint);
        element.repaint = r;
        changed = true;
    }
    
    if changed && element.parent != nil {
        element_repaint(element.parent, &r);
    }
}

element_destroy :: proc(element: ^Element) {
    if .Destroy in element.flags do return;
    
    incl(&element.flags, Flags { .Destroy, .Hide });
	
    for ancestor := element.parent; ancestor != nil; ancestor = ancestor.parent {
        incl(&ancestor.flags, Flag.DestroyDescendent);
    }
    
    _element_destroy_descendents(element, false);
}

element_destroy_descendents :: proc(element: ^Element) {
    _element_destroy_descendents(element, true);
}

_element_destroy_descendents :: proc(element: ^Element, top_level: bool) {
    for child := element.child_head; child != nil; child = child.next {
        if !top_level {
            element_destroy(child);
        }
    }
}

text_width :: proc(label: string) -> int {
    return int(font_text_width(&ui.font, label));
}

text_widthf :: proc(label: string) -> f32 {
    return font_text_width(&ui.font, label);
}

element_move :: proc(element: ^Element, bounds: Rect, always_layout: bool) {
    element.clip = rect_intersection(element.parent.clip, bounds);
    
    if !rect_equals(element.bounds, bounds) || always_layout {
        element.bounds = bounds;
        element_message(element, .Layout);
    }
}

element_setup :: proc($T: typeid, parent: ^Element, flags: Flags, message: proc(element: ^Element, msg: Message, di: int, dp: rawptr) -> int, name: string) -> ^T {
    thing := new(T);
    thing.flags = flags;
    thing.parent = parent;
    thing.message_class = message;
    thing.name = name;
    
    if parent != nil {
        thing.window = parent.window;
        
        if parent.child_head != nil {
            old := parent.child_tail;
            parent.child_tail.next = &thing.element;
            parent.child_tail = &thing.element;
            parent.child_tail.prev = old;
        } else {
            parent.child_head = &thing.element;
            parent.child_tail = &thing.element;
        }
        
        assert(.Destroy not_in parent.flags);
    }
    
    return thing;
}

panel_layout :: proc(panel: ^Panel, bounds: Rect, measure: bool) -> int {
    horizontal := .PanelHorizontal in panel.element.flags;
	scale := panel.window.scale;
	position := int(f32(horizontal ? panel.border.l : panel.border.t) * scale);
	h_space := rect_width(bounds) - int(f32(rect_total_h(panel.border)) * scale);
    v_space := rect_height(bounds) - int(f32(rect_total_v(panel.border)) * scale);
    
    available: int = horizontal ? h_space : v_space;
    fill, count, per_fill: int;
    
    for child := panel.child_head; child != nil; child = child.next {
        if .Hide not_in child.flags {
            count += 1;
            
            if horizontal {
                if .FillHorizontal in child.flags {
                    fill += 1;
                } else {
                    available -= element_message(child, .GetWidth, v_space, nil);
                }
            } else {
                if .FillVertical in child.flags {
                    fill += 1;
                } else {
                    available -= element_message(child, .GetHeight, h_space, nil);
                }
            }
        }
    }
    
    if count != 0 {
        available -= (count - 1) * int(f32(panel.gap) * scale);
    }
    
    if available > 0 && fill != 0 {
        per_fill = available / fill;
    }
    
    expand := .PanelExpand in panel.flags;
    scaled_border_2 := int(f32(horizontal ? panel.border.t : panel.border.l) * scale);
    
    for child := panel.child_head; child != nil; child = child.next {
        if .Hide not_in child.flags {
            if horizontal {
                height := (.FillVertical in child.flags || expand) ? v_space : element_message(child, .GetHeight);
                width := (.FillHorizontal in child.flags) ? per_fill : element_message(child, .GetWidth, height, nil);
                relative := rect_4(position, position + width, 
                                   scaled_border_2 + (v_space - height) / 2, 
                                   scaled_border_2 + (v_space + height) / 2);
                if !measure do element_move(child, rect_translate(relative, bounds), false);
                position += width + int(f32(panel.gap) * scale);
            } else {
                width := (.FillHorizontal in child.flags || expand) ? h_space : element_message(child, .GetWidth);
                height := .FillVertical in child.flags ? per_fill : element_message(child, .GetHeight, width, nil);
                relative := rect_4(scaled_border_2 + (h_space - width) / 2, 
                                   scaled_border_2 + (h_space + width) / 2, position, position + height);
                if !measure do element_move(child, rect_translate(relative, bounds), false);
                position += height + int(f32(panel.gap) * scale);
            }
        }
    }
    
    return position - int(f32(panel.gap) * scale) + int(f32(horizontal ? panel.border.r : panel.border.b) * scale);
}

panel_measure :: proc(panel: ^Panel) -> int {
	horizontal := .PanelHorizontal in panel.flags;
	size := 0;
    
    for child := panel.child_head; child != nil; child = child.next {
		if .Hide not_in child.flags {
			if horizontal {
				height := element_message(child, .GetHeight);
                
				if height > size {
					size = height;
				}
			} else {
				width := element_message(child, .GetWidth);
                
				if width > size {
					size = width;
				}
			}
		}
	}
    
	border := 0;
    
	if horizontal {
		border = panel.border.t + panel.border.b;
	} else {
		border = panel.border.l + panel.border.r;
	}
    
	return size + int(f32(border) * panel.window.scale);
}

_panel_message :: proc(element: ^Element, message: Message, di: int, dp: rawptr) -> int {
    panel := cast(^Panel) element;
    horizontal := .PanelHorizontal in panel.flags;
    
    if message == .Layout {
        panel_layout(panel, element.bounds, false);
    } else if message == .GetWidth && horizontal {
        if horizontal {
            return panel_layout(panel, rect_4(0, 0, 0, di), true);
        } else {
            return panel_measure(panel);
        }
    } else if message == .GetHeight {
        if horizontal {
            return panel_measure(panel);
        } else {
            return panel_layout(panel, rect_4(0, di, 0, 0), true);
        }
    } else if message == .Paint {
        if .PanelGray in element.flags {
            draw_rect(element.window, element.bounds, ui.theme.panel1);
        } else if .PanelWhite in element.flags {
            draw_rect(element.window, element.bounds, ui.theme.panel2);
        }
    }
    
    return 0;
}

panel_init :: proc(parent: ^Element, flags: Flags) -> ^Panel {
    return element_setup(Panel, parent, flags, _panel_message, "Panel");
}

_scale :: proc(element: ^Element, size: int) -> int {
    return int(f32(size) * element.window.scale);
}

_button_message :: proc(element: ^Element, message: Message, di: int, dp: rawptr) -> int {
    button := cast(^Button) element;
    is_menu_item := .ButtonMenuItem in element.flags;
    
    if message == .GetHeight {
        if is_menu_item {
            return _scale(element, ui.sizes.menu_item_height);
        } else {
            return _scale(element, ui.sizes.button_height);
        }
    } else if message == .GetWidth {
        label_size := len(button.label);
        // NOTE(Skytrias): + 10 to have string not cut off
        padded_size := text_width(button.label) + 10; 
        minimum_size := _scale(element, is_menu_item ? ui.sizes.menu_item_minimum_width : ui.sizes.button_minimum_width);
        return padded_size > minimum_size ? padded_size : minimum_size;
    } else if message == .Paint {
        hovered := element == element.window.hovered;
        pressed := element == element.window.pressed;
        focused := element == element.window.focused;
        color := pressed && hovered ? ui.theme.button_pressed : pressed || hovered ? ui.theme.button_hovered : focused ? ui.theme.button_focused : ui.theme.button_normal;
        
        draw_rect_outlined(element.window, element.bounds, color, ui.theme.border, rect_1(is_menu_item ? 0 : 1));
        
        if is_menu_item {
            bounds := rect_add(element.bounds, rect_2i(_scale(element, ui.sizes.menu_item_height), 0));
            draw_text_aligned(element.window, bounds, button.label, ui.theme.text, .Left);
            // TODO(Skytrias): menu draw
        } else {
            draw_text_aligned(element.window, element.bounds, button.label, ui.theme.text, .Center);
        }
    } else if message == .Update {
        element_repaint(element, nil);
    } else if message == .LeftDown {
        if .ButtonCanFocus in element.flags {
            element_focus(element);
        }
    } else if message == .Clicked {
        if button.invoke != {} {
            button.invoke(button.cp);
        }
    }
    
    return 0;
}

button_init :: proc(parent: ^Element, flags: Flags, label: string) -> ^Button {
    button := element_setup(Button, parent, flags, _button_message, "Button");
    button.label = label;
    return button;
}

_menu_item_message :: proc(element: ^Element, message: Message, di: int, dp: rawptr) -> int {
    if message == .Clicked {
        close_menus();
    }
    
    return 0;
}

_menu_message :: proc(element: ^Element, message: Message, di: int, dp: rawptr) -> int {
    if message == .GetWidth {
        width := 0;
        
        for child := element.child_head; child != nil; child = child.next {
            w := element_message(child, .GetWidth);
            if w > width do width = w;
        }
        
        return width + 4;
    } else if message == .GetHeight {
        height := 0;
        
        for child := element.child_head; child != nil; child = child.next {
            height += element_message(child, .GetHeight);
        }
        
        return height + 4;
    } else if message == .Paint {
        draw_rect(element.window, element.bounds, ui.theme.border);
    } else if message == .Layout {
        position := element.bounds.t + 2;
        
        for child := element.child_head; child != nil; child = child.next {
            height := element_message(child, .GetHeight);
            element_move(child, rect_4(element.bounds.l + 2, element.bounds.r - 2, position, position + height), false);
            position += height;
        }
    } else if message == .KeyTyped {
        typed := cast(^KeyTyped) dp;
        
        if typed.scancode == .Escape {
            close_menus();
            return 1;
        }
    }
    
    return 0;
}

menu_add_item :: proc(menu: ^Menu, flags: Flags, label: string, invoke: proc(cp: rawptr), cp: rawptr) {
    button := button_init(&menu.element, { .ButtonMenuItem }, label);
    button.message_user = _menu_item_message;
    button.invoke = invoke;
    button.cp = cp;
}

menu_prepare :: proc(menu: ^Menu, width, height: ^int) {
    width^ = element_message(&menu.element, .GetWidth);
    height^ = element_message(&menu.element, .GetHeight);
    
    if .MenuPlaceAbove in menu.flags {
        menu.point_y -= height^;
    }
}

menu_show :: proc(menu: ^Menu) {
    width, height: int;
    menu_prepare(menu, &width, &height);
    sdl.set_window_position(menu.window.win, i32(menu.point_x), i32(menu.point_y));
    sdl.set_window_size(menu.window.win, i32(width), i32(height));
    sdl.show_window(menu.window.win);
}

window_get_screen_position :: proc(window: ^Window) -> (int, int) {
    x, y: i32;
    sdl.get_window_position(window.win, &x, &y);
    return int(x), int(y);
}

element_screen_bounds :: proc(element: ^Element) -> Rect {
    x, y := window_get_screen_position(element.window);
    return rect_add(element.bounds, rect_2(x, y));
}

menu_init :: proc(parent: ^Element, flags: Flags) -> ^Menu {
    window := window_init(parent.window, { .WindowMenu }, "", 0, 0);
    
    menu := element_setup(Menu, &window.element, flags, _menu_message, "Menu");
    
    if parent.parent != nil {
        screen_bounds := element_screen_bounds(parent);
        menu.point_x = screen_bounds.l;
        menu.point_y = (.MenuPlaceAbove in flags) ? (screen_bounds.t + 1) : (screen_bounds.b - 1);
    } else {
        x, y := window_get_screen_position(parent.window);
        menu.point_x = parent.window.cursor_x + x;
        menu.point_y = parent.window.cursor_y + y;
    }
    
    return menu;
}

_label_message :: proc(element: ^Element, message: Message, di: int, dp: rawptr) -> int {
    label := cast(^Label) element;
    
    if message == .GetHeight {
        // NOTE(Skytrias): measure string height?
        return ui.font.height;
    } else if message == .GetWidth {
        return text_width(label.label);
    } else if message == .Paint {
        draw_text_aligned(element.window, element.bounds, label.label, ui.theme.text, .Left);
    }
    
    return 0;
}

label_init :: proc(parent: ^Element, flags: Flags, label: string) -> ^Label {
    l := element_setup(Label, parent, flags, _label_message, "Label");
    l.label = label;
    return l;
}

_splitter_message :: proc(element: ^Element, message: Message, di: int, dp: rawptr) -> int {
    split_pane := cast(^SplitPane) element.parent;
    vertical := .SplitPaneVertical in split_pane.flags;
    
    if message == .Paint {
        borders := vertical ? rect_2(0, 1) : rect_2(1, 0);
        draw_rect_outlined(element.window, element.bounds, ui.theme.button_normal, ui.theme.border, borders);
    } else if message == .GetCursor {
        return int(vertical ? System_Cursor.Size_NS : System_Cursor.Size_WE);
    } else if message == .MouseDrag {
        cursor := f32(vertical ? element.window.cursor_y : element.window.cursor_x);
        splitter_size := f32(ui.sizes.splitter) * element.window.scale;
        space := f32(vertical ? rect_height(split_pane.bounds) : rect_width(split_pane.bounds)) - splitter_size;
        split_pane.weight = (cursor - splitter_size / 2 - f32(split_pane.bounds.l)) / space;
        if split_pane.weight < 0.05 do split_pane.weight = 0.05;
        if split_pane.weight > 0.95 do split_pane.weight = 0.95;
        element_refresh(&split_pane.element);
    }
    
    return 0;
}

_split_pane_message :: proc(element: ^Element, message: Message, di: int, dp: rawptr) -> int {
    split_pane := cast(^SplitPane) element;
    vertical := .SplitPaneVertical in split_pane.flags;
    
    if message == .Layout {
        splitter := element.child_head;
        assert(splitter != nil);
        left := splitter.next;
        assert(left != nil);
        right := left.next;
        assert(right != nil);
        
        splitter_size := _scale(element, ui.sizes.splitter);
        space := (vertical ? rect_height(element.bounds) : rect_width(element.bounds)) - splitter_size;
        left_size := int(f32(space) * split_pane.weight);
        right_size := space - left_size;
        
        if vertical {
            element_move(left, rect_4(element.bounds.l, element.bounds.r, element.bounds.t, element.bounds.t + left_size), false);
            element_move(splitter, rect_4(element.bounds.l, element.bounds.r, element.bounds.t + left_size, element.bounds.t + left_size + splitter_size), false);
            element_move(right, rect_4(element.bounds.l, element.bounds.r, element.bounds.b - right_size, element.bounds.b), false);
        } else {
            element_move(left, rect_4(element.bounds.l, element.bounds.l + left_size, element.bounds.t, element.bounds.b), false);
            element_move(splitter, rect_4(element.bounds.l + left_size, element.bounds.l + left_size + splitter_size, element.bounds.t, element.bounds.b), false);
            element_move(right, rect_4(element.bounds.r - right_size, element.bounds.r, element.bounds.t, element.bounds.b), false);
        }
    }
    
    return 0;
}

split_pane_init :: proc(parent: ^Element, flags: Flags, weight: f32) -> ^SplitPane {
    split := element_setup(SplitPane, parent, flags, _split_pane_message, "Split Pane");
    split.weight = weight;
    element_setup(Spacer, &split.element, {}, _splitter_message, "Splitter");
    return split;
}

_spacer_message :: proc(element: ^Element, message: Message, di: int, dp: rawptr) -> int {
    spacer := cast(^Spacer) element;
    
    if message == .GetHeight {
        return _scale(element, spacer.height);
    } else if message == .GetWidth {
        return _scale(element, spacer.width);
    } else if message == .Paint && .SpacerLine in element.flags {
        rect := element.bounds;
        rect.t = element.bounds.t + rect_height(element.bounds) / 2;
        rect.b = rect.t + 1;
        draw_rect(element.window, rect, ui.theme.border);
    }
    
    return 0;
}

// space
spacer_init :: proc(parent: ^Element, flags: Flags, width, height: int) -> ^Spacer {
    spacer := element_setup(Spacer, parent, flags, _spacer_message, "Spacer");
    spacer.width = width;
    spacer.height = height;
    return spacer;
}

_slider_message :: proc(element: ^Element, message: Message, di: int, dp: rawptr) -> int {
    slider := cast(^Slider) element;
    
    if message == .GetHeight {
        return _scale(element, ui.sizes.slider_height);
    } else if message == .GetWidth {
        return _scale(element, ui.sizes.slider_width);
    } else if message == .Paint {
        bounds := element.bounds;
        center_y := (bounds.t + bounds.b) / 2;
        track_size := _scale(element, ui.sizes.slider_track);
        thumb_size := _scale(element, ui.sizes.slider_thumb);
        thumb_position := int(f32(rect_width(bounds) - thumb_size) * slider.position);
        track := rect_4(bounds.l, bounds.r, center_y - (track_size + 1) / 2, center_y + track_size / 2);
        draw_rect_outlined(element.window, track, ui.theme.button_normal, ui.theme.border, rect_1(1));
        
        pressed := element == element.window.pressed;
        hovered := element == element.window.hovered;
        color := pressed ? ui.theme.button_pressed : hovered ? ui.theme.button_hovered : ui.theme.button_normal;
        thumb := rect_4(bounds.l + thumb_position, bounds.l + thumb_position + thumb_size, center_y - (thumb_size + 1) / 2, center_y + thumb_size / 2);
        draw_rect_outlined(element.window, thumb, color, ui.theme.border, rect_1(1));
    } else if (message == .LeftDown || (message == .MouseDrag && element.window.pressed_button == 1)) {
        bounds := element.bounds;
        thumb_size := _scale(element, ui.sizes.slider_thumb);
        slider.position = f32(element.window.cursor_x - thumb_size / 2 - bounds.l) / f32(rect_width(bounds) - thumb_size);
        if slider.position < 0 do slider.position = 0;
        if slider.position > 1 do slider.position = 1;
        element_message(element, .ValueChanged);
        element_repaint(element, nil);
    } else if message == .Update {
        element_repaint(element, nil);
    }
    
    return 0;
}

slider_init :: proc(parent: ^Element, flags: Flags, position: f32) -> ^Slider {
    slider := element_setup(Slider, parent, flags, _slider_message, "Slider");
    slider.position = position;
    return slider;
}

element_paint :: proc(window: ^Window, element: ^Element, for_repaint: bool) {
    // Clip painting to the element's clip.
    if .Hide in element.flags do return;
    window.draw_clip = rect_intersection(element.clip, window.draw_clip);
    if !rect_valid(window.draw_clip) do return;
    
    if for_repaint {
        // Add to the repaint region the intersection of the parent's repaint region with our clip.
        if element.parent != nil {
            parent_repaint := rect_intersection(element.parent.repaint, element.clip);
            
            if rect_valid(parent_repaint) {
                if .Repaint in element.flags {
                    element.repaint = rect_bounding(element.repaint, parent_repaint);
                } else {
                    element.repaint = parent_repaint;
                    incl(&element.flags, Flag.Repaint);
                }
            } 
        }
        
        // If we don't need to repaint, don't.
        if .Repaint not_in element.flags do return;
        
        // Clip painting to our repaint region.
        window.draw_clip = rect_intersection(element.repaint, window.draw_clip);
        
        if !rect_valid(window.draw_clip) do return;
    }
    
    // Paint the element.
    element_message(element, .Paint);
    
    // Paint its child_head.
    previous_clip := window.draw_clip;
    for child := element.child_head; child != nil; child = child.next  {
        window.draw_clip = previous_clip;
        element_paint(window, child, for_repaint);
    }
    
    // Clear the repaint flag.
    if for_repaint {
        excl(&element.flags, Flag.Repaint);
    }
}

element_focus :: proc(element: ^Element) {
    previous := element.window.focused;
    if previous == element do return;
    element.window.focused = element;
    if previous != nil do element_message(previous, .Update);
    if element != nil do element_message(element, .Update);
}

window_set_pressed :: proc(window: ^Window, element: ^Element, button: int) {
    previous := window.pressed;
    window.pressed = element;
    window.pressed_button = button;
    if previous != nil do element_message(previous, .Update);
    if element != nil do element_message(element, .Update);
}

element_free :: proc(element: ^Element) -> bool {
    if .DestroyDescendent in element.flags {
        excl(&element.flags, Flag.DestroyDescendent);
        
        // TODO(Skytrias): inspect cuz head / tail changes
        link := &element.child_head;
        for child := element.child_head; child != nil; child = child.next  {
            temp := child.next;
            
            if element_free(child) {
                link^ = temp;
            } else {
                link = &child.next;
            }
        }
    }
    
    if .Destroy in element.flags {
        element_message(element, .Destroy);
        
        if element.window.pressed == element {
            window_set_pressed(element.window, nil, 0);
        }
        
        if element.window.hovered == element {
            element.window.hovered = &element.window.element;
        }
        
        if element.window.focused == element {
            element.window.focused = nil;
        }
        
        if ui.animating == element {
            ui.animating = nil;
        }
        
        free(element);
        return true;
    } else {
        return false;
    }
}

ui_update :: proc() {
    link := &ui.windows;
    for window := ui.windows; window != nil; window = window.next_window {
        temp := window.next_window; 
        
        if element_free(&window.element) {
            link^ = temp;
        } else {
            link = &window.next_window;
            
            if .Repaint in window.element.flags {
                //fmt.println("ui_update: repaint window and update surface");
                
                //window.update_region = window.repaint;
                window.draw_width = window.width;
                window.draw_height = window.height;
                window.draw_clip = rect_2s(window.width, window.height);
                
                element_paint(window, &window.element, true);
                sdl.update_window_surface(window.win);
            }
        }
    }
}

element_find_by_point :: proc(element: ^Element, x, y: int) -> ^Element {
    for child := element.child_head; child != nil; child = child.next {
        if .Hide not_in child.flags && rect_contains(child.clip, x, y) {
            return element_find_by_point(child, x, y);
        }
    }
    
    return element;
}

window_find :: proc(id: u32) -> ^Window {
    for window := ui.windows; window != nil; window = window.next_window {
        if sdl.get_window_id(window.win) == id {
            return window;
        }
    }
    
    return nil;
}

process_animations :: proc() {
    if ui.animating != nil {
        element_message(ui.animating, .Animate);
        ui_update();
    }
}

close_menus :: proc() -> bool {
    any_closed := false;
    
    for window := ui.windows; window != nil; window = window.next_window {
        if .WindowMenu in window.flags {
            element_destroy(&window.element);
            any_closed = true;
        }
    }
    
    return any_closed;
}

window_add_shortcut :: proc(window: ^Window, shortcut: Shortcut) {
    append(&window.shortcuts, shortcut);
}

menus_open :: proc() -> bool {
    for window := ui.windows; window != nil; window = window.next_window {
        if .WindowMenu in window.flags {
            return true;
        }
    }
    
    return false;
}

_window_input_event :: proc(window: ^Window, message: Message, di: int, dp: rawptr) {
    if window.pressed != nil {
        if message == .MouseMove {
            element_message(window.pressed, .MouseDrag, di, dp);
        } else if message == .LeftUp && window.pressed_button == 1 {
            if window.hovered == window.pressed {
                element_message(window.pressed, .Clicked, di, dp);
            }
            
            element_message(window.pressed, .LeftUp, di, dp);
            window_set_pressed(window, nil, 1);
        } else if message == .MiddleUp && window.pressed_button == 2 {
            element_message(window.pressed, .MiddleUp, di, dp);
            window_set_pressed(window, nil, 2);
        } else if message == .RightUp && window.pressed_button == 3 {
            element_message(window.pressed, .RightUp, di, dp);
            window_set_pressed(window, nil, 3);
        }
    }
    
    if window.pressed != nil {
        inside := rect_contains(window.pressed.clip, window.cursor_x, window.cursor_y);
        
        if inside && window.hovered == &window.element {
            window.hovered = window.pressed;
            element_message(window.pressed, .Update);
        } else if !inside && window.hovered == window.pressed {
            window.hovered = &window.element;
            element_message(window.pressed, .Update);
        }
    }
    
    if window.pressed == nil {
        hovered := element_find_by_point(&window.element, window.cursor_x, window.cursor_y);
        
        if message == .MouseMove {
            element_message(hovered, .MouseMove, di, dp);
            
            cursor := cast(sdl.System_Cursor) element_message(window.hovered, .GetCursor, di, dp);
            if (cursor != window.cursor_style) {
                window.cursor_style = cursor;
                sdl.set_cursor(ui.cursors[cursor]);
            }
        } else if message == .LeftDown {
            if .WindowMenu in window.flags || !close_menus() {
                window_set_pressed(window, hovered, 1);
                element_message(hovered, .LeftDown, di, dp);
            }
        } else if message == .MiddleDown {
            if .WindowMenu in window.flags || !close_menus() {
                window_set_pressed(window, hovered, 2);
                element_message(hovered, .MiddleDown, di, dp);
            }
            
        } else if message == .RightDown {
            if .WindowMenu in window.flags || !close_menus() {
                window_set_pressed(window, hovered, 3);
                element_message(hovered, .RightDown, di, dp);
            }
        } else if message == .MouseWheel {
            for element := hovered; element != nil; element = element.parent {
                if element_message(element, .MouseWheel, di, dp) == 1 {
                    break;
                }
            }
        } else if message == .KeyTyped {
            handled := false;
            
            if window.focused != nil {
                for element := window.focused; element != nil; element = element.parent {
                    // NOTE(Skytrias): == 1 or != 0?
                    if element_message(element, .KeyTyped, di, dp) == 1 {
                        handled = true;
                        break;
                    }
                }
            } else {
                if element_message(&window.element, .KeyTyped, di, dp) == 1 {
                    handled = true;
                }
            }
            
            if !handled && !menus_open() {
                typed := cast(^KeyTyped) dp;
                
                for shortcut in &window.shortcuts {
                    if shortcut.code == typed.code && shortcut.ctrl == window.ctrl && shortcut.shift == window.shift && shortcut.alt == window.alt {
                        shortcut.invoke(shortcut.cp);
                    }
                }
            }
        }
        
        if hovered != window.hovered {
            previous := window.hovered;
            window.hovered = hovered;
            element_message(previous, .Update);
            element_message(window.hovered, .Update);
        }
    }
    
    ui_update();
}

_window_message :: proc(element: ^Element, message: Message, di: int, dp: rawptr) -> int {
    if message == .Layout && element.child_head != nil {
        element_move(element.child_head, element.bounds, false);
        element_repaint(element, nil);
    } else if message == .Destroy {
        window := cast(^Window) element;
        delete(window.shortcuts);
        sdl.destroy_window(window.win);
        fmt.println("destroy");
    }
    
    return 0;
}

window_init :: proc(parent: ^Window, flags: Flags, title: cstring, _width, _height: int) -> ^Window {
    close_menus();
    
    window := element_setup(Window, nil, flags, _window_message, "Window");
    window.scale = 1;
    window.element.window = window;
    window.hovered = &window.element;
    window.next_window = ui.windows;
    ui.windows = window;
    
    width := (.WindowMenu in flags) ? 1 : _width != 0 ? _width : 800;
    height := (.WindowMenu in flags) ? 1 : _height != 0 ? _height : 600;
    window.width = width;
    window.height = height;
    
    if .WindowMenu in flags {
        window.win = sdl.create_window(title, 0, 30, i32(width), i32(height), .Resizable | .Allow_High_DPI | .Hidden | .Borderless);
    } else {
        window.win = sdl.create_window(title, 0, 30, i32(width), i32(height), .Resizable | .Allow_High_DPI | .Hidden);
    }
    
    if window.win == nil {
        fmt.println("SDL2: error during window creation %s", sdl.get_error());
        sdl.quit();
        return nil;
    }
    
    sdl.show_window(window.win);
    
    return window;
}

window_process_event :: proc(e: sdl.Event) {
#partial switch e.type {
    case .Quit: {
        sdl.quit();
        ui.stop = true;
    }
    
    case .Key_Down: {
        window := window_find(e.key.window_id);
        if window == nil do return;
        
        window.ctrl = sdl.Keymod(e.key.keysym.mod) == .LCtrl;
        window.shift = sdl.Keymod(e.key.keysym.mod) == .LShift;
        window.alt = sdl.Keymod(e.key.keysym.mod) == .LAlt;
        
        typed := KeyTyped { 
            code = u8(e.key.keysym.sym),
            scancode = e.key.keysym.scancode,
        };
        //fmt.println(typed, window.ctrl);
        _window_input_event(window, .KeyTyped, 0, &typed);
    }
    
    case .Key_Up: {
        window := window_find(e.key.window_id);
        if window == nil do return;
        
        window.ctrl = false;
        window.shift = false;
        window.alt = false;
    }
    
    case .Window_Event: {
        if e.window.event == .Exposed {
            window := window_find(e.window.window_id);
            if window == nil do return;
            //editor_center_view();
            
            surface := sdl.get_window_surface(window.win);
            window.width = int(surface.w);
            window.height = int(surface.h);
            window.element.clip = rect_2s(window.width, window.height);
            window.element.bounds = rect_2s(window.width, window.height);
            element_message(&window.element, .Layout);
            ui_update();
            
            if false {
                if e.window.event == .Exposed {
                    fmt.println("exposed");
                } else if e.window.event == .Resized {
                    fmt.println("resized");
                }
            }
        }
        
        if e.window.event == .Close {
            window := window_find(e.window.window_id);
            if window == nil do return;
            
            element_message(&window.element, .Destroy);
            ui_update();
        }
        
        if e.window.event == .Take_Focus {
            //close_menus();
            //window := window_find(e.window.window_id);
            //element_message(&window.element, .Layout, 0, nil);
            //ui_update();
            fmt.println("focused");
        }
    }
    
    case .Mouse_Button_Down: {
        window := window_find(e.button.window_id);
        if window == nil do return;
        
        if e.button.button == cast(u8) sdl.Mousecode.Left {
            _window_input_event(window, .LeftDown, 0, nil);
        }
        
        if e.button.button == cast(u8) sdl.Mousecode.Middle {
            _window_input_event(window, .MiddleDown, 0, nil);
        }
        
        if e.button.button == 3 {
            _window_input_event(window, .RightDown, 0, nil);
        }
    }
    
    case .Mouse_Button_Up: {
        window := window_find(e.button.window_id);
        if window == nil do return;
        
        if e.button.button == cast(u8) sdl.Mousecode.Left {
            _window_input_event(window, .LeftUp, 0, nil);
        }
        
        if e.button.button == cast(u8) sdl.Mousecode.Middle {
            _window_input_event(window, .MiddleUp, 0, nil);
        }
        
        if e.button.button == 3 {
            _window_input_event(window, .RightUp, 0, nil);
        }
    }
    
    case .Mouse_Motion: {
        window := window_find(e.motion.window_id);
        if window == nil do return;
        
        window.cursor_x = int(e.motion.x);
        window.cursor_y = int(e.motion.y);
        _window_input_event(window, .MouseMove, 0, nil);
    }
}
}

ui_message_loop :: proc() {
    for !ui.stop {
        if ui.animating != nil {
            process_animations();
        } else {
            e: sdl.Event;
            if true {
                sdl.wait_event(&e);
            } else {
                sdl.poll_event(&e);
            }
            
            window_process_event(e);
        }
    }
}