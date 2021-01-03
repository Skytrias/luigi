package main

import "core:fmt"
import "engine"

main :: proc() {
    using engine;
    ui_init();
    
    window := window_init(nil, { }, "todool", 800, 500);
    split := split_pane_init(&window.element, {  }, 0.3);
    
    {
        panel := panel_init(&split.element, { .PanelGray });
        panel.border = rect_1(5);
        panel.gap = 5;
        button_init(&panel.element, {  }, "Hello").message_user = proc(element: ^Element, message: Message, di: int, dp: rawptr) -> int {
            
            if message == .Clicked {
                fmt.println("yo");
            }
            
            return 0;
        };
        button_init(&panel.element, {}, "one");
        button_init(&panel.element, {}, "two");
    }
    
    if true {
        panel := panel_init(&split.element, { .PanelGray });
        panel.border = rect_1(5);
        panel.gap = 5;
        
        button_init(&panel.element, {}, "damn");
        spacer_init(&panel.element, { .SpacerLine }, 150, 20);
        button_init(&panel.element, {}, "other");
        slider_init(&panel.element, {}, 0.1);
        
        a := button_init(&panel.element, {}, "this is a menu asdasd");
        a.message_user = proc(element: ^Element, message: Message, di: int, dp: rawptr) -> int {
            if message == .Clicked {
                menu := menu_init(element, { });
                
                call :: proc(cp: rawptr) {
                    
                }
                
                menu_add_item(menu, {}, "yo", call, nil);
                menu_add_item(menu, {}, "guys", call, nil);
                menu_show(menu);
            }
            
            return 0;
        };
    } 
    
    word := "testing";
    window_add_shortcut(window, { 
                            code = 't', 
                            ctrl = true, 
                            invoke = proc(cp: rawptr) {
                                fmt.println((cast(^string) cp)^);
                            },
                            cp = &word,
                        });
    
    ui_message_loop();
}