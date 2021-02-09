import strformat
import streams
import bitops
import nimpy
import os

type
  ChunkData* = ref object of RootObj
    data*: seq[byte]
    timestamp*: int

proc calcOffset(chunk_x: int32, chunk_z: int32): int32 {.exportpy.} =
  return 4 * (bitops.bitand(chunk_x, 31) + bitops.bitand(chunk_z, 31) * 32)

proc findChunk(location: uint32): array[0..1, uint32] {.exportpy.} =
  let offset: uint32 = bitops.bitand(bitops.rotateRightBits(location, 8), 0xFFFFFF)
  let size: uint32 = bitops.bitand(location, 0xFF)

  return [offset * 4096, size * 4096]

proc fetchChunk(world_path: string, chunk_x: int32, chunk_z: int32): ChunkData {.exportpy.} =
  let region_x: int32 = int32(chunk_x / 32)
  let region_y: int32 = int32(chunk_z / 32)

  let region_path: string = os.joinPath([world_path, "region", strformat.fmt("f.{region_x}.{region_y}.mca")])

  let loc_table_loc: int = calcOffset(chunk_x, chunk_z)

  let stream = streams.newFileStream(region_path, fmRead)  # open file in read mode
  defer: stream.close()  # closes file automatically when we're done with it

  stream.setPosition(loc_table_loc)
  let chunk_pos = findChunk(uint8(stream.readInt8()))

  stream.setPosition(loc_table_loc + 4096)
  let timestamp: int32 = stream.readInt32()

  stream.setPosition(int32(chunk_pos[0]) + 5)

  var data: seq[byte]

  for c in stream.readStr(int(chunk_pos[1])):
    data.add(byte(c))

  return ChunkData(data: data, timestamp: timestamp)
