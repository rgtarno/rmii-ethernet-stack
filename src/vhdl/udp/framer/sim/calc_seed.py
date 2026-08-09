
length = 46

src_ip = 0xc0a8002c
dst_ip = 0xc0a80004

hdr_bytes = [0] * 20

hdr_bytes[0] = 0x45
hdr_bytes[1] = 0x00
hdr_bytes[2] = 0x00
hdr_bytes[3] = 0x00
hdr_bytes[4] = 0x00
hdr_bytes[5] = 0x00
hdr_bytes[6] = 0x00
hdr_bytes[7] = 0x00
hdr_bytes[8] = 0x80 # TTL
hdr_bytes[9] = 0x11
hdr_bytes[10] = 0x00
hdr_bytes[11] = 0x00
hdr_bytes[12]  = (src_ip >> 24) & 0xFF
hdr_bytes[13]  = (src_ip >> 16) & 0xFF
hdr_bytes[14]  = (src_ip >> 8) & 0xFF
hdr_bytes[15]  = (src_ip >> 0) & 0xFF
hdr_bytes[16]  = (dst_ip >> 24) & 0xFF
hdr_bytes[17]  = (dst_ip >> 16) & 0xFF
hdr_bytes[18]  = (dst_ip >> 8) & 0xFF
hdr_bytes[19]  = (dst_ip >> 0) & 0xFF

hdr_words = [0] * (len(hdr_bytes) // 2)

for i in range(0, len(hdr_bytes), 2):
  hdr_words[i//2] = hdr_bytes[i] << 8 | hdr_bytes[i+1]

def calc_checksum(words):
  s = 0
  for w in words:
    s = s + w
    if s > 0xFFFF:
      s = s & 0xFFFF
      s = s + 1
  s= ~s
  s = s & 0xFFF
  return s

def calc_seed(words):
  s = 0
  for w in words:
    s = s + w
    if s > 0xFFFF:
      s = s & 0xFFFF
      s = s + 1
  if s > 0xFFFF:
    print("FAIL")
  return s


seed = calc_seed(hdr_words)
print(f"seed = {seed:04x}")

hdr_words[1] = length

c = calc_checksum(hdr_words)
print(f"Final checksum = {c:04x}")