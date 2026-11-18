#ifndef SORTING_IO_H
#define SORTING_IO_H
#include <stddef.h>
#include <stdint.h>
typedef struct {
  void *ctx;
  void (*drive)(void *, int, int);
  int (*sample)(void *, int);
  void (*delay)(void *);
  unsigned limit;
} I2c;
int i2c_transfer(I2c *, unsigned, const uint8_t *, unsigned, uint8_t *,
                 unsigned);
int eeprom_read(void *, unsigned, void *, unsigned);
int eeprom_write(void *, unsigned, const void *, unsigned);
typedef struct {
  void *ctx;
  uint8_t (*xfer)(void *, uint8_t);
  void (*select)(void *, int);
  int high_capacity;
  unsigned limit;
} SdSpi;
int sd_init(SdSpi *);
int sd_read(void *, uint32_t, uint8_t *);
typedef int (*ReadSector)(void *, uint32_t, uint8_t *);
typedef struct {
  void *ctx;
  ReadSector read;
  uint32_t fat, data, root, clusters, total;
  unsigned spc;
  uint8_t cache[512];
} Fat;
typedef struct {
  Fat *fs;
  uint32_t cluster, size, pos;
} FatFile;
int fat_mount(Fat *, ReadSector, void *);
int fat_open(Fat *, const char name[11], FatFile *);
int fat_read(FatFile *, void *, unsigned);
typedef struct {
  uint32_t data, bytes, rate;
  unsigned channels;
} Wav;
int wav_parse(const uint8_t *, size_t, Wav *);
typedef struct {
  int raw_w, raw_h, screen_w, screen_h, rotate, mirror_x, mirror_y, down;
} Touch;
int touch_update(Touch *, int fingers, int raw_x, int raw_y, int *x, int *y);
typedef struct {
  unsigned source_w, source_h, scaled_w, scaled_h, pad_x, pad_y, size;
} Letterbox;
int preprocess_rgb565(const uint16_t *, unsigned, unsigned, int8_t *, unsigned,
                      float, Letterbox *);
void box_to_source(const Letterbox *, float *, float *, float *, float *);
#endif
