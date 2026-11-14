"""Offline GLB structure/buffer/index checks; not a gltf-validator replacement."""
import hashlib
import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'web' / 'studio'
TABLE = json.loads((ROOT / 'parts.json').read_text())
SIZES = {5120: ('b', 1), 5121: ('B', 1), 5122: ('h', 2), 5123: ('H', 2), 5125: ('I', 4), 5126: ('f', 4)}
WIDTHS = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}
count = triangles = 0
for entry in TABLE['parts']:
    if entry['source'] != 'glb':
        continue
    data = (ROOT / 'parts' / entry['file']).read_bytes()
    assert hashlib.sha256(data).hexdigest() == entry['sha256']
    magic, version, length = struct.unpack_from('<III', data)
    assert magic == 0x46546c67 and version == 2 and length == len(data)
    offset, chunks = 12, []
    while offset < length:
        size, kind = struct.unpack_from('<II', data, offset)
        assert size % 4 == 0 and offset + 8 + size <= length
        chunks.append((kind, data[offset+8:offset+8+size]))
        offset += 8 + size
    assert [c[0] for c in chunks] == [0x4e4f534a, 0x004e4942]
    doc, binary = json.loads(chunks[0][1]), chunks[1][1]
    assert doc['asset']['version'] == '2.0'
    assert len(doc['buffers']) == 1 and 'uri' not in doc['buffers'][0]
    assert doc['buffers'][0]['byteLength'] <= len(binary)
    assert not doc.get('extensionsRequired'), 'unsupported required extension'
    values = []
    for accessor in doc['accessors']:
        assert not accessor.get('sparse')
        view = doc['bufferViews'][accessor['bufferView']]
        assert view.get('buffer', 0) == 0
        start = view.get('byteOffset', 0)
        assert start + view['byteLength'] <= len(binary)
        fmt, size = SIZES[accessor['componentType']]
        width = WIDTHS[accessor['type']]
        stride = view.get('byteStride', size * width)
        local = accessor.get('byteOffset', 0)
        assert local + (accessor['count']-1)*stride + size*width <= view['byteLength']
        rows = [struct.unpack_from('<'+fmt*width, binary, start+local+i*stride) for i in range(accessor['count'])]
        assert all(math.isfinite(v) for row in rows for v in row)
        values.append(rows)
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            assert primitive.get('mode', 4) == 4
            positions = values[primitive['attributes']['POSITION']]
            assert len(positions) > 0
            indices = values[primitive['indices']]
            assert len(indices) % 3 == 0
            assert all(0 <= row[0] < len(positions) for row in indices)
            assert 0 <= primitive['material'] < len(doc['materials'])
            triangles += len(indices) // 3
    for node in doc['nodes']:
        if 'mesh' in node:
            assert node.get('extras', {}).get('cpore_up') == '+Z'
            assert node['extras']['cpore_forward'] == '+X'
        for k in ['translation', 'rotation', 'scale', 'matrix']:
            assert all(math.isfinite(v) for v in node.get(k, []))
    count += 1
assert count == 24
print(f'PASS: {count} GLBs; {triangles} triangles; hashes, chunks, buffers, accessors, finite values, indices, materials and source axes checked.')
print('No Khronos gltf-validator installed; this structural check does not certify glTF conformance.')
