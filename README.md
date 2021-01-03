# luigi  

A barebones single-header GUI library for SDL2 in [Odin](https://odin-lang.org/) . 

## Prerequisites
This fork includes `.ttf` font rendering via stb-truetype. You will need a file called `font.ttf` next to the `.exe`.
You will also need sdl2 to dynamically link to the `.exe` 

## Building example
Requires [odin](https://odin-lang.org/) + [odin-stb](https://github.com/vassvik/odin-stb) + [odin-sdl2](https://github.com/JoshuaManton/odin-sdl2) in the `odin/shared` folder. 
`odin run main.odin` or `odin run main.odin -llvm-api -out=example.exe`


## Documentation (C Version)

### Introduction

As with other single-header libraries, to use it in your project define `UI_IMPLEMENTATION` in exactly one translation unit where you include the header. 
Furthermore, everytime you include the header, you must either define `UI_WINDOWS` or `UI_LINUX` to specify the target platform.

To initialise the library, call `UIInitialise`. You can then create a window using `UIWindowCreate` and populate it using the `UI...Create` functions. 
Once you're ready, call `UIMessageLoop`, and input messages will start being processed.

Windows are built up of *elements*, which are allocated and initialised by `UI...Create` functions. These functions all return a pointer to the allocated element. 
At the start of every element is a common header of type `UIElement`, contained in the field `e`. 
When you create an element, you must specify its parent element and its flags. 
Each element determines the position of its children, and every element is clipped to its parent (i.e. it cannot draw outside the bounds of the parent).

The library uses a message-based system to allow elements to respond to events and requests.
The enumeration `UIMessage` specifies all the different messages that can be sent to an element using the `UIElementMessage` function.
A message is passed with two parameters, an integer `di` and a pointer `dp`, and the element receiving the message must return an integer in response.
If the meaning of the return value is not specified, or the element does not handle the message, it should return 0.
After ensuring the element has not been marked for deletion, 
`UIElementMessage` will first try sending the message to the `messageUser` function pointer in the `UIElement` header.
If this returns 0, then the message will also be sent to the `messageClass` function pointer.
The `UI...Create` functions will set the `messageClass` function pointer, and the user may optionally set the `messageUser` to also receive messages sent to the element.

For example, the `messageClass` function set by `UIButtonCreate` will handle drawing the button when it receives the `UI_MSG_PAINT` message.
The user will likely want to set `messageUser` so that they can receive the `UI_MSG_CLICKED` message, which indicates that the button has been clicked.

### UIRectangle

This contains 4 integers, `l`, `r`, `t` and `b` which represent the left, right, top and bottom edges of a rectangle. 
Usually, the coordinates are in pixels relative to the top-left corner of the relevant window.

### UIElement

The common header for all elements.

```c
struct UIElement {
	uint64_t flags; 

	struct UIElement *parent;
	struct UIElement *next;
	struct UIElement *children;
	struct UIWindow *window;

	UIRectangle bounds, clip, repaint;
	
	void *cp; 

	int (*messageClass)(struct UIElement *element, UIMessage message, int di, void *dp);
	int (*messageUser)(struct UIElement *element, UIMessage message, int di, void *dp);
};
```

`flags` contains a bitset of flags for the element. The first 32-bits are specific to each type of element. The upper 32-bits are common to all elements. 
Bits 32-47 are intended to specifying options, and bits 48-63 are for storing the element's state.

The following flags are available:

* `UI_ELEMENT_V_FILL` is a hint to the parent element that this element should take up all available vertical space.
* `UI_ELEMENT_H_FILL` is a hint to the parent element that this element should take up all available horizontal space.
* `UI_ELEMENT_REPAINT` marks the element for repainting. Do not set directly; see `UIElementRepaint`.
* `UI_ELEMENT_DESTROY` marks the element to be destroyed. Do not set directly; see `UIElementDestroy`.
* `UI_ELEMENT_HIDE` marks the element as hidden. It will not receive input events, be drawn, or take up space in the parent's layout.

`parent` contains a pointer to the element's parent. `next` contains a pointer to the element's sibling. 
`children` contains a pointer to the element's first child (children are linked by the `next` pointer).
`window` contains a pointer to the window that contains the element.

`bounds` contains the element's bounds, expressed in pixels relative to the top-left corner of the containing window. Do not set directly; see `UIElementMove`.
`clip` contains the element's clip region, expressed in pixels relative to the top-left corner of the containing window. Do not set directly; see `UIElementMove`.
`repaint` contains the element's repaint region, expressed in pixels relative to the top-left corner of the containing window. Do not set directly; see `UIElementRepaint`.

`cp` is a context pointer available for the user.

`messageClass` and `messageUser` contain function pointers to the element's message handlers. 
`messageClass` is set when the element is first created, and has lower priority than `messageUser` when receiving messages.
`messageUser` can be optionally set by the user of the element to inspect and handle its messages.
If `messageUser` returns a non-zero value, then `messageClass` will not receive the message.
If `messageUser` is `NULL`, then `messageClass` will always receive the message.
Do not call these directly; see `UIElementMessage`.
