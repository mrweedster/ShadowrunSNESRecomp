#ifndef MOUSE_CURSOR_H
#define MOUSE_CURSOR_H

/* One frame of mouse ownership, called before the guest runs: absolute
 * in-game hand cursor plus the mouse's action buttons. See mouse_cursor.c. */
void MouseCursorBeginFrame(void);

#endif /* MOUSE_CURSOR_H */
