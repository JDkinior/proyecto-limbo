import json
import struct
import math
import shutil
import glob
import os

def smoothstep(edge0, edge1, x):
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)

def bake_tree_glb(glb_path):
    bak_path = glb_path + ".bak"
    if not os.path.exists(bak_path):
        shutil.copyfile(glb_path, bak_path)
        print(f"Created backup: {bak_path}")

    # Read from original backup to avoid compounding edits
    with open(bak_path, 'rb') as f:
        magic, version, _ = struct.unpack('<4sII', f.read(12))
        assert magic == b'glTF' and version == 2
        
        chunk_len, chunk_type = struct.unpack('<II', f.read(8))
        assert chunk_type == 0x4E4F534A  # JSON
        json_bytes = f.read(chunk_len)
        g = json.loads(json_bytes.decode('utf-8'))
        
        # Binary chunk
        f.seek(12 + 8 + ((chunk_len + 3) & ~3))
        bin_len, bin_type = struct.unpack('<II', f.read(8))
        assert bin_type == 0x004E4942  # BIN
        bin_data = bytearray(f.read(bin_len))

    def get_positions(prim):
        pos_acc = g['accessors'][prim['attributes']['POSITION']]
        bv = g['bufferViews'][pos_acc['bufferView']]
        offset = bv.get('byteOffset', 0) + pos_acc.get('byteOffset', 0)
        count = pos_acc['count']
        verts = []
        for i in range(count):
            x, y, z = struct.unpack_from('<fff', bin_data, offset + i * 12)
            verts.append((x, y, z))
        return verts

    mesh = g['meshes'][0]
    prims = mesh['primitives']
    
    # Prim 0: Trunk, Prim 1: Base, Prim 2: Hojas
    trunk_verts = get_positions(prims[0])
    base_verts = get_positions(prims[1])
    hojas_verts = get_positions(prims[2])
    
    all_foliage = base_verts + hojas_verts
    dists = [min(math.sqrt((v[0]-t[0])**2 + (v[1]-t[1])**2 + (v[2]-t[2])**2) for t in trunk_verts) for v in all_foliage]
    d_min = min(dists)
    d_max = max(dists)
    
    # Align bin_data to 4 bytes
    while len(bin_data) % 4 != 0:
        bin_data.append(0)
        
    for prim_idx in range(len(prims)):
        prim = prims[prim_idx]
        verts = get_positions(prim)
        colors = bytearray()
        
        if prim_idx == 0:
            # Trunk: completely rigid (factor = 0.0)
            for _ in verts:
                colors.extend(struct.pack('<ffff', 0.0, 0.0, 0.0, 1.0))
        else:
            # Base (1) and Hojas (2): unified distance metric to branches
            for v in verts:
                d = min(math.sqrt((v[0]-t[0])**2 + (v[1]-t[1])**2 + (v[2]-t[2])**2) for t in trunk_verts)
                norm_d = (d - d_min) / (d_max - d_min) if d_max > d_min else 0.0
                factor = smoothstep(0.05, 0.85, norm_d)
                factor = math.pow(factor, 1.25)
                # COLOR_0: (factor, distance, 0, 1)
                colors.extend(struct.pack('<ffff', factor, d, 0.0, 1.0))
                
        # BufferView for COLOR_0
        bv_offset = len(bin_data)
        bin_data.extend(colors)
        while len(bin_data) % 4 != 0:
            bin_data.append(0)
            
        bv_idx = len(g['bufferViews'])
        g['bufferViews'].append({
            'buffer': 0,
            'byteOffset': bv_offset,
            'byteLength': len(colors),
            'target': 34962  # ARRAY_BUFFER
        })
        
        # Accessor for COLOR_0
        acc_idx = len(g['accessors'])
        g['accessors'].append({
            'bufferView': bv_idx,
            'byteOffset': 0,
            'componentType': 5126,  # FLOAT
            'count': len(verts),
            'type': 'VEC4'
        })
        
        prim['attributes']['COLOR_0'] = acc_idx
        
    g['buffers'][0]['byteLength'] = len(bin_data)
    
    new_json_bytes = json.dumps(g, separators=(',', ':')).encode('utf-8')
    while len(new_json_bytes) % 4 != 0:
        new_json_bytes += b' '
        
    while len(bin_data) % 4 != 0:
        bin_data.append(0)
        
    total_len = 12 + 8 + len(new_json_bytes) + 8 + len(bin_data)
    
    with open(glb_path, 'wb') as f:
        f.write(struct.pack('<4sII', b'glTF', 2, total_len))
        f.write(struct.pack('<II', len(new_json_bytes), 0x4E4F534A))
        f.write(new_json_bytes)
        f.write(struct.pack('<II', len(bin_data), 0x004E4942))
        f.write(bin_data)
        
    print(f"Bake complete: {glb_path} (d_min={d_min:.2f}m, d_max={d_max:.2f}m, size={total_len}B)")

def main():
    tree_files = sorted(glob.glob('assets/modelos/entorno/arboles/*.glb'))
    for path in tree_files:
        bake_tree_glb(path)
    print("All trees baked successfully.")

if __name__ == '__main__':
    main()
