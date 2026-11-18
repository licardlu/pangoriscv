#ifndef MEDIA_BOARD_H
#define MEDIA_BOARD_H
#include <stdint.h>
void media_board_init(void);
uint32_t media_board_page(void);
int media_navigation_active(void);
int media_board_diagnostics(uint32_t result[7]);
int media_board_read_frame(uint32_t address,uint8_t data[256],uint32_t limit);
#endif
