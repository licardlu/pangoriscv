#include "io.h"
#include <limits.h>
#include <string.h>
static uint32_t g32(const uint8_t *p) {
  return (uint32_t)p[0] | (uint32_t)p[1] << 8 | (uint32_t)p[2] << 16 |
         (uint32_t)p[3] << 24;
}
static unsigned g16(const uint8_t *p) { return p[0] | p[1] << 8; }
static int min_i(int x, int a, int b) { return x < a ? a : x > b ? b : x; }
int wav_parse(const uint8_t *p, size_t n, Wav *w) {
  if (!p || !w || n < 12 || memcmp(p, "RIFF", 4) || memcmp(p + 8, "WAVE", 4))
    return 0;
  size_t end = (size_t)g32(p + 4) + 8;
  if (end > n || end < 12)
    return 0;
  unsigned fmt = 0;
  Wav out = {0};
  for (size_t off = 12; off + 8 <= end;) {
    uint32_t len = g32(p + off + 4);
    size_t start = off + 8;
    if (len > end - start)
      return 0;
    if (!memcmp(p + off, "fmt ", 4)) {
      if (len < 16 || g16(p + start) != 1 || g16(p + start + 14) != 16)
        return 0;
      out.channels = g16(p + start + 2);
      out.rate = g32(p + start + 4);
      if ((out.channels != 1 && out.channels != 2) || out.rate != 48000 ||
          g16(p + start + 12) != out.channels * 2 ||
          g32(p + start + 8) != out.rate * out.channels * 2)
        return 0;
      fmt = 1;
    }
    if (!memcmp(p + off, "data", 4)) {
      out.data = (uint32_t)start;
      out.bytes = len;
    }
    off = start + len + (len & 1);
  }
  if (!fmt || !out.data || !out.bytes || out.bytes % (out.channels * 2))
    return 0;
  *w = out;
  return 1;
}
int touch_update(Touch *t, int fingers, int rx, int ry, int *x, int *y) {
  if (!t || !x || !y)
    return 0;
  if (fingers == 0) {
    t->down = 0;
    return 0;
  }
  if (t->down)
    return 0;
  t->down = 1;
  if (fingers != 1 || t->raw_w < 2 || t->raw_h < 2 || t->screen_w < 2 ||
      t->screen_h < 2)
    return 0;
  if (rx < 0 || ry < 0 || rx >= t->raw_w || ry >= t->raw_h)
    return 0;
  int64_t u = (int64_t)rx * 65535 / (t->raw_w - 1),
          v = (int64_t)ry * 65535 / (t->raw_h - 1), tmp;
  if (t->mirror_x)
    u = 65535 - u;
  if (t->mirror_y)
    v = 65535 - v;
  switch (t->rotate) {
  case 0:
    break;
  case 90:
    tmp = u;
    u = 65535 - v;
    v = tmp;
    break;
  case 180:
    u = 65535 - u;
    v = 65535 - v;
    break;
  case 270:
    tmp = u;
    u = v;
    v = 65535 - tmp;
    break;
  default:
    return 0;
  }
  *x = (int)(u * (t->screen_w - 1) / 65535);
  *y = (int)(v * (t->screen_h - 1) / 65535);
  return 1;
}
int preprocess_rgb565(const uint16_t *src, unsigned w, unsigned h, int8_t *dst,
                      unsigned size, float scale, Letterbox *l) {
  if (!src || !dst || !l || !w || !h || w > 8192 || h > 8192 || !size ||
      size > 2048 || !(scale > 0))
    return 0;
  unsigned sw, sh;
  if (w >= h) {
    sw = size;
    sh = (uint64_t)h * size / w;
  } else {
    sh = size;
    sw = (uint64_t)w * size / h;
  }
  if (!sw)
    sw = 1;
  if (!sh)
    sh = 1;
  *l = (Letterbox){w, h, sw, sh, (size - sw) / 2, (size - sh) / 2, size};
  for (unsigned y = 0; y < size; y++)
    for (unsigned x = 0; x < size; x++) {
      unsigned rgb[3] = {114, 114, 114};
      if (x >= l->pad_x && x < l->pad_x + sw && y >= l->pad_y &&
          y < l->pad_y + sh) {
        unsigned xx = (uint64_t)(x - l->pad_x) * w / sw,
                 yy = (uint64_t)(y - l->pad_y) * h / sh;
        uint16_t p = src[yy * w + xx];
        unsigned r = (p >> 11) & 31, g = (p >> 5) & 63, b = p & 31;
        rgb[0] = (r << 3) | (r >> 2);
        rgb[1] = (g << 2) | (g >> 4);
        rgb[2] = (b << 3) | (b >> 2);
      }
      for (unsigned c = 0; c < 3; c++) {
        int q = (int)(rgb[c] / (255.0f * scale) + .5f);
        dst[c * size * size + y * size + x] = (int8_t)min_i(q, -127, 127);
      }
    }
  return 1;
}
void box_to_source(const Letterbox *l, float *x1, float *y1, float *x2,
                   float *y2) {
  float *xs[] = {x1, x2}, *ys[] = {y1, y2};
  for (int k = 0; k < 2; k++) {
    *xs[k] = (*xs[k] - l->pad_x) * l->source_w / l->scaled_w;
    *ys[k] = (*ys[k] - l->pad_y) * l->source_h / l->scaled_h;
    if (*xs[k] < 0)
      *xs[k] = 0;
    if (*xs[k] > l->source_w)
      *xs[k] = (float)l->source_w;
    if (*ys[k] < 0)
      *ys[k] = 0;
    if (*ys[k] > l->source_h)
      *ys[k] = (float)l->source_h;
  }
}
/* I2C callbacks drive(line, release): line 0=SCL,1=SDA; release=1 is high-Z. */
static void line(I2c *b, int n, int release) {
  b->drive(b->ctx, n, release);
  b->delay(b->ctx);
}
static int high(I2c *b) {
  line(b, 0, 1);
  for (unsigned i = 0; i < b->limit; i++) {
    if (b->sample(b->ctx, 0))
      return 1;
    b->delay(b->ctx);
  }
  return 0;
}
static void stop(I2c *b) {
  line(b, 0, 0);
  line(b, 1, 0);
  high(b);
  line(b, 1, 1);
}
static int start(I2c *b) {
  line(b, 1, 1);
  if (!high(b))
    return 0;
  line(b, 1, 0);
  line(b, 0, 0);
  return 1;
}
static int send(I2c *b, uint8_t v) {
  for (int i = 7; i >= 0; i--) {
    line(b, 0, 0);
    line(b, 1, (v >> i) & 1);
    if (!high(b))
      return 0;
    line(b, 0, 0);
  }
  line(b, 1, 1);
  if (!high(b))
    return 0;
  int ack = !b->sample(b->ctx, 1);
  line(b, 0, 0);
  return ack;
}
static int recv(I2c *b, uint8_t *v, int last) {
  uint8_t r = 0;
  line(b, 1, 1);
  for (int i = 0; i < 8; i++) {
    if (!high(b))
      return 0;
    r = (r << 1) | !!b->sample(b->ctx, 1);
    line(b, 0, 0);
  }
  line(b, 1, last);
  if (!high(b))
    return 0;
  line(b, 0, 0);
  line(b, 1, 1);
  *v = r;
  return 1;
}
int i2c_transfer(I2c *b, unsigned address, const uint8_t *tx, unsigned nt,
                 uint8_t *rx, unsigned nr) {
  if (!b || !b->drive || !b->sample || !b->delay || !b->limit ||
      address > 127 || (!tx && nt) || (!rx && nr))
    return 0;
  line(b, 1, 1);
  if (!b->sample(b->ctx, 1)) {
    for (int i = 0; i < 9; i++) {
      line(b, 0, 0);
      if (!high(b))
        return 0;
    }
    stop(b);
    if (!b->sample(b->ctx, 1))
      return 0;
  }
  if (!start(b))
    goto fail;
  if (nt || !nr) {
    if (!send(b, (uint8_t)(address << 1)))
      goto fail;
    for (unsigned i = 0; i < nt; i++)
      if (!send(b, tx[i]))
        goto fail;
  }
  if (nr) {
    if (nt && !start(b))
      goto fail;
    if (!send(b, (uint8_t)((address << 1) | 1)))
      goto fail;
    for (unsigned i = 0; i < nr; i++)
      if (!recv(b, &rx[i], i == nr - 1))
        goto fail;
  }
  stop(b);
  return 1;
fail:
  stop(b);
  return 0;
}
int eeprom_read(void *ctx, unsigned off, void *d, unsigned n) {
  if (off > 256 || n > 256 - off)
    return 0;
  uint8_t a = (uint8_t)off;
  return i2c_transfer(ctx, 0x50, &a, 1, d, n);
}
int eeprom_write(void *ctx, unsigned off, const void *d, unsigned n) {
  uint8_t b[9];
  if (!n || off >= 256 || n > 8 || n > 256 - off ||
      off / 8 != (off + n - 1) / 8)
    return 0;
  b[0] = (uint8_t)off;
  memcpy(b + 1, d, n);
  if (!i2c_transfer(ctx, 0x50, b, n + 1, 0, 0))
    return 0;
  for (unsigned i = 0; i < 128; i++)
    if (i2c_transfer(ctx, 0x50, 0, 0, 0, 0))
      return 1;
  return 0;
}
static int sector(Fat *f, uint32_t n) {
  return n < f->total && f->read(f->ctx, n, f->cache);
}
int fat_mount(Fat *f, ReadSector read, void *ctx) {
  if (!f || !read)
    return 0;
  memset(f, 0, sizeof(*f));
  f->read = read;
  f->ctx = ctx;
  f->total = UINT32_MAX;
  if (!sector(f, 0))
    return 0;
  uint32_t base = 0;
  if (g16(f->cache + 11) != 512) {
    base = g32(f->cache + 454);
    if (!base || !sector(f, base))
      return 0;
  }
  uint8_t *b = f->cache;
  unsigned spc = b[13], nf = b[16], reserved = g16(b + 14);
  uint32_t total = g32(b + 32), fat = g32(b + 36), root = g32(b + 44);
  uint64_t overhead = (uint64_t)reserved + (uint64_t)nf * fat;
  if (b[510] != 0x55 || b[511] != 0xaa || g16(b + 11) != 512 || g16(b + 17) ||
      g16(b + 22) || !reserved || !spc || (spc & (spc - 1)) || spc > 128 ||
      !nf || nf > 2 || !fat || total <= overhead || base > UINT32_MAX - total)
    return 0;
  uint32_t clusters = (total - (uint32_t)overhead) / spc;
  if (clusters < 65525 || clusters >= 0xffffff5 || root < 2 ||
      root >= clusters + 2 || (uint64_t)fat * 128 < clusters + 2)
    return 0;
  f->fat = base + reserved;
  f->data = base + (uint32_t)overhead;
  f->total = base + total;
  f->root = root;
  f->spc = spc;
  f->clusters = clusters;
  return 1;
}
static uint32_t next_cluster(Fat *f, uint32_t c) {
  if (c < 2 || c >= f->clusters + 2 || !sector(f, f->fat + c / 128))
    return 0;
  return g32(f->cache + (c % 128) * 4) & 0xfffffff;
}
int fat_open(Fat *f, const char name[11], FatFile *out) {
  if (!f || !name || !out || !f->read || !f->spc)
    return 0;
  uint32_t c = f->root;
  for (uint32_t steps = 0; steps < f->clusters; steps++) {
    if (c < 2 || c >= f->clusters + 2)
      return 0;
    for (unsigned s = 0; s < f->spc; s++) {
      if (!sector(f, f->data + (c - 2) * f->spc + s))
        return 0;
      for (unsigned o = 0; o < 512; o += 32) {
        uint8_t *p = f->cache + o;
        if (!p[0])
          return 0;
        if (p[0] == 0xe5 || (p[11] & 0x18) || p[11] == 0xf)
          continue;
        if (!memcmp(p, name, 11)) {
          uint32_t cl = (g16(p + 20) << 16) | g16(p + 26);
          if (cl < 2 || cl >= f->clusters + 2)
            return 0;
          *out = (FatFile){f, cl, g32(p + 28), 0};
          return 1;
        }
      }
    }
    c = next_cluster(f, c);
  }
  return 0;
}
int fat_read(FatFile *f, void *dst, unsigned want) {
  if (!f || !f->fs || !dst || f->pos > f->size)
    return -1;
  Fat *fs = f->fs;
  unsigned total = want < f->size - f->pos ? want : f->size - f->pos, n = total;
  uint8_t *d = dst;
  while (n) {
    uint32_t c = f->cluster;
    if (c < 2 || c >= fs->clusters + 2)
      return -1;
    unsigned in = f->pos % (fs->spc * 512), offset = in % 512,
             chunk = 512 - offset;
    if (chunk > n)
      chunk = n;
    if (!sector(fs, fs->data + (c - 2) * fs->spc + in / 512))
      return -1;
    memcpy(d, fs->cache + offset, chunk);
    d += chunk;
    f->pos += chunk;
    n -= chunk;
    if (f->pos % (fs->spc * 512) == 0 && f->pos < f->size) {
      uint32_t nc = next_cluster(fs, c);
      if (nc < 2 || nc >= fs->clusters + 2)
        return -1;
      f->cluster = nc;
    }
  }
  return (int)total;
}
static uint8_t command(SdSpi *s, unsigned c, uint32_t a) {
  s->xfer(s->ctx, 0xff);
  s->xfer(s->ctx, (uint8_t)(0x40 | c));
  for (int i = 3; i >= 0; i--)
    s->xfer(s->ctx, (uint8_t)(a >> (8 * i)));
  s->xfer(s->ctx, c == 0 ? 0x95 : c == 8 ? 0x87 : 1);
  for (unsigned i = 0; i < s->limit; i++) {
    uint8_t r = s->xfer(s->ctx, 255);
    if (!(r & 128))
      return r;
  }
  return 255;
}
int sd_init(SdSpi *s) {
  if (!s || !s->xfer || !s->select || !s->limit)
    return 0;
  s->select(s->ctx, 0);
  for (int i = 0; i < 10; i++)
    s->xfer(s->ctx, 255);
  s->select(s->ctx, 1);
  if (command(s, 0, 0) != 1)
    goto fail;
  if (command(s, 8, 0x1aa) != 1)
    goto fail;
  uint32_t r7 = 0;
  for (int i = 0; i < 4; i++)
    r7 = (r7 << 8) | s->xfer(s->ctx, 255);
  if (r7 != 0x1aa)
    goto fail;
  unsigned tries;
  for (tries = 0; tries < s->limit; tries++) {
    if (command(s, 55, 0) > 1)
      goto fail;
    if (command(s, 41, 0x40000000) == 0)
      break;
  }
  if (tries == s->limit || command(s, 58, 0) != 0)
    goto fail;
  uint32_t ocr = 0;
  for (int i = 0; i < 4; i++)
    ocr = (ocr << 8) | s->xfer(s->ctx, 255);
  if (!(ocr & 0x80000000))
    goto fail;
  s->high_capacity = !!(ocr & 0x40000000);
  if (!s->high_capacity && command(s, 16, 512))
    goto fail;
  s->select(s->ctx, 0);
  s->xfer(s->ctx, 255);
  return 1;
fail:
  s->select(s->ctx, 0);
  s->xfer(s->ctx, 255);
  return 0;
}
int sd_read(void *ctx, uint32_t lba, uint8_t *d) {
  SdSpi *s = ctx;
  if (!s || !d || (!s->high_capacity && lba > UINT32_MAX / 512))
    return 0;
  s->select(s->ctx, 1);
  if (command(s, 17, s->high_capacity ? lba : lba * 512))
    goto fail;
  uint8_t token = 255;
  for (unsigned i = 0; i < s->limit; i++) {
    token = s->xfer(s->ctx, 255);
    if (token != 255)
      break;
  }
  if (token != 0xfe)
    goto fail;
  for (int i = 0; i < 512; i++)
    d[i] = s->xfer(s->ctx, 255);
  s->xfer(s->ctx, 255);
  s->xfer(s->ctx, 255);
  s->select(s->ctx, 0);
  s->xfer(s->ctx, 255);
  return 1;
fail:
  s->select(s->ctx, 0);
  s->xfer(s->ctx, 255);
  return 0;
}
