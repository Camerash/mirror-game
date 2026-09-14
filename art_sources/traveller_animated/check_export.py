"""Read exported glTF accessors and evaluate standard skinning and morph channels."""
import json
from pathlib import Path
import struct
import sys

import numpy as np
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from arm_rig import ARM_BONES


class ExportedModel:
    def __init__(self, path):
        data = path.read_bytes()
        length = struct.unpack_from('<I', data, 12)[0]
        self.doc = json.loads(data[20:20+length])
        self.binary = data[28+length:]
        self.nodes = self.doc['nodes']
        self.parents = {child: parent for parent, node in enumerate(self.nodes) for child in node.get('children', [])}
        self.mesh_nodes = {node['name']: index for index, node in enumerate(self.nodes) if 'mesh' in node}
        self.cache = {}

    def accessor(self, index):
        if index not in self.cache:
            item = self.doc['accessors'][index]
            dtype = {5126: '<f4', 5125: '<u4', 5123: '<u2', 5121: 'u1'}[item['componentType']]
            count = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[item['type']]
            def read(view_index, offset, rows, columns, kind):
                view = self.doc['bufferViews'][view_index]
                size = np.dtype(kind).itemsize
                return np.ndarray((rows, columns), dtype=kind, buffer=self.binary,
                    offset=view.get('byteOffset', 0)+offset,
                    strides=(view.get('byteStride', size*columns), size)).copy()
            values = read(item['bufferView'], item.get('byteOffset', 0), item['count'], count, dtype) if 'bufferView' in item else np.zeros((item['count'], count), dtype=dtype)
            if 'sparse' in item:
                sparse = item['sparse']
                indices, replacement = sparse['indices'], sparse['values']
                kind = {5125: '<u4', 5123: '<u2', 5121: 'u1'}[indices['componentType']]
                selected = read(indices['bufferView'], indices.get('byteOffset', 0), sparse['count'], 1, kind).ravel()
                values[selected] = read(replacement['bufferView'], replacement.get('byteOffset', 0), sparse['count'], count, dtype)
            self.cache[index] = values
        return self.cache[index]

    def state(self, animation, time):
        overrides = {}
        for channel in animation['channels']:
            sampler = animation['samplers'][channel['sampler']]
            times = self.accessor(sampler['input']).ravel()
            values = self.accessor(sampler['output'])
            path, node = channel['target']['path'], channel['target']['node']
            if path == 'weights':
                values = values.reshape(len(times), -1)
            right = min(len(times)-1, int(np.searchsorted(times, time, side='right')))
            left = max(0, right-1)
            fraction = max(0, min(1, (time-times[left])/max(1e-10, times[right]-times[left])))
            if path == 'rotation':
                q0, q1 = [Quaternion((row[3], row[0], row[1], row[2])) for row in (values[left], values[right])]
                q = q0.slerp(q1, float(fraction))
                value = [q.x, q.y, q.z, q.w]
            else:
                value = values[left]*(1-fraction)+values[right]*fraction
            overrides.setdefault(node, {})[path] = value
        matrices = {}
        def world(index):
            if index in matrices:
                return matrices[index]
            node = self.nodes[index]
            values = {**node, **overrides.get(index, {})}
            if 'matrix' in node:
                matrix = Matrix(np.array(node['matrix']).reshape(4, 4).T.tolist())
            else:
                rotation = values.get('rotation', [0, 0, 0, 1])
                matrix = Matrix.LocRotScale(Vector(values.get('translation', [0, 0, 0])),
                    Quaternion((rotation[3], *rotation[:3])), Vector(values.get('scale', [1, 1, 1])))
            matrices[index] = world(self.parents[index])@matrix if index in self.parents else matrix
            return matrices[index]
        for index in range(len(self.nodes)):
            world(index)
        result = {}
        for name, index in self.mesh_nodes.items():
            node = self.nodes[index]
            mesh = self.doc['meshes'][node['mesh']]
            assert len(mesh['primitives']) == 1
            primitive = mesh['primitives'][0]
            attr = primitive['attributes']
            points = self.accessor(attr['POSITION']).astype(float)
            weights = overrides.get(index, {}).get('weights', node.get('weights', mesh.get('weights', [])))
            for target, weight in zip(primitive.get('targets', []), weights):
                points += weight*self.accessor(target['POSITION'])
            homogeneous = np.column_stack((points, np.ones(len(points))))
            if 'skin' in node:
                skin = self.doc['skins'][node['skin']]
                inverse = self.accessor(skin['inverseBindMatrices']).reshape(-1, 4, 4).transpose(0, 2, 1)
                joint_matrices = np.array([np.array(matrices[joint])@bind for joint, bind in zip(skin['joints'], inverse)])
                joints = self.accessor(attr['JOINTS_0']).astype(int)
                influence = self.accessor(attr['WEIGHTS_0'])
                transformed = np.einsum('nvij,nj->nvi', joint_matrices[joints], homogeneous)
                points = np.einsum('nvi,nv->ni', transformed, influence)[:, :3]
            else:
                points = (homogeneous@np.array(matrices[index]).T)[:, :3]
            faces = self.accessor(primitive['indices']).reshape(-1, 3).astype(int)
            result[name] = (points, faces, BVHTree.FromPolygons(points.tolist(), faces.tolist(), all_triangles=True))
        self.matrices = matrices
        return result


def main():
    model = ExportedModel(ROOT/'assets/studies/traveller_animated.glb')
    doc = model.doc
    assert set(model.mesh_nodes) == {'Head', 'Hair', 'Body', 'Boots', 'Garment'}
    assert len(doc['materials']) == 2 and all(m.get('alphaMode', 'OPAQUE') == 'OPAQUE' for m in doc['materials'])
    assert len(doc['images']) == 1
    view = doc['bufferViews'][doc['images'][0]['bufferView']]
    png = model.binary[view.get('byteOffset', 0):][:view['byteLength']]
    assert png[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack_from('>II', png, 16) == (1024, 1024)
    assert {a['name'] for a in doc['animations']} == {'HoodDown', 'HoodUp'}
    bound_data = json.loads((ROOT/'assets/studies/traveller_animated_bounds.json').read_text())
    report = {'clips': {}, 'materials': [m['name'] for m in doc['materials']], 'atlas': [1024, 1024]}
    body_node = model.nodes[model.mesh_nodes['Body']]
    body_primitive = doc['meshes'][body_node['mesh']]['primitives'][0]
    joints = model.accessor(body_primitive['attributes']['JOINTS_0']).astype(int)
    influences = model.accessor(body_primitive['attributes']['WEIGHTS_0'])
    skin = doc['skins'][body_node['skin']]
    arm_joints = {index for index, node in enumerate(skin['joints']) if model.nodes[node]['name'] in ARM_BONES}
    arm_vertices = np.any(np.isin(joints, list(arm_joints)) & (influences > 0), axis=1)
    body_faces = model.accessor(body_primitive['indices']).reshape(-1, 3).astype(int)
    arm_faces = body_faces[np.all(arm_vertices[body_faces], axis=1)]
    for animation in doc['animations']:
        assert all(sampler.get('interpolation', 'LINEAR') == 'LINEAR' for sampler in animation['samplers'])
        names = {model.nodes[c['target']['node']]['name'] for c in animation['channels']}
        assert names <= set(ARM_BONES)|{'Garment'}, names
        duration = max(float(model.accessor(s['input']).max()) for s in animation['samplers'])
        assert abs(duration-2) < 1e-6
        reference = model.state(animation, 0)
        # glTF can split source vertices at UV or normal seams. Restore only the
        # source adjacency for self tests; no collision pair is removed by region.
        points, faces, _ = reference['Garment']
        mapping, welded = {}, []
        for point in points:
            key = tuple(np.round(point, 7))
            if key not in mapping:
                mapping[key] = len(mapping)
            welded.append(mapping[key])
        face_sets = [set(welded[index] for index in face) for face in faces]
        failed, fixed_error, bounds_error = [], 0, 0
        for step in range(241):
            time = step/120
            current = model.state(animation, time)
            _, _, tree = current['Garment']
            counts = {'self': sum(a < b and not face_sets[a].intersection(face_sets[b]) for a, b in tree.overlap(tree))}
            counts.update({name: len(tree.overlap(current[name][2])) for name in ('Head', 'Hair', 'Body')})
            arm_tree = BVHTree.FromPolygons(current['Body'][0].tolist(), arm_faces.tolist(), all_triangles=True)
            counts.update({'Arms/'+name: len(arm_tree.overlap(current[name][2])) for name in ('Head', 'Hair')})
            if any(counts.values()):
                failed.append({'seconds': time, **counts})
            for name, (points, _, _) in current.items():
                matrix = np.array(model.matrices[model.mesh_nodes[name]])
                local = (np.column_stack((points, np.ones(len(points))))@np.linalg.inv(matrix).T)[:, :3]
                for sample, box in ((points, bound_data['global']), (local, bound_data['meshes'][name])):
                    lower = np.array(box['position'])
                    upper = lower+np.array(box['size'])
                    bounds_error = max(bounds_error, float(np.max(lower-sample)), float(np.max(sample-upper)))
            for name in ('Head', 'Hair', 'Boots'):
                fixed_error = max(fixed_error, float(np.max(np.abs(current[name][0]-reference[name][0]))))
        report['clips'][animation['name']] = {'duration': duration, 'samples': 241,
            'failures': failed, 'fixed_geometry_max_error': fixed_error, 'bounds_overflow': bounds_error, 'animated_nodes': sorted(names)}
    report['rigid_attachments'] = {name: model.nodes[model.parents[model.mesh_nodes[name]]]['name'] for name in ('Head', 'Hair', 'Garment')}
    assert report['rigid_attachments'] == {'Head': 'Head', 'Hair': 'Head', 'Garment': 'Chest'}
    report['vertex_counts'] = {}
    for name, node_index in model.mesh_nodes.items():
        primitive = doc['meshes'][model.nodes[node_index]['mesh']]['primitives'][0]
        count = len(model.accessor(primitive['attributes']['POSITION']))
        report['vertex_counts'][name] = count
        assert len(model.accessor(primitive['attributes']['NORMAL'])) == count
        for target in primitive.get('targets', []):
            assert len(model.accessor(target['POSITION'])) == count
            assert len(model.accessor(target['NORMAL'])) == count
        if 'WEIGHTS_0' in primitive['attributes']:
            weights = model.accessor(primitive['attributes']['WEIGHTS_0'])
            assert np.max(np.abs(weights.sum(axis=1)-1)) < 1e-6
            assert 'WEIGHTS_1' not in primitive['attributes']
    report['triangles'] = sum(model.accessor(primitive['indices']).size//3 for mesh in doc['meshes'] for primitive in mesh['primitives'])
    assert report['triangles'] <= 8000
    report['passed'] = all(not item['failures'] and item['bounds_overflow'] < 1e-6 and item['fixed_geometry_max_error'] < 1e-6 for item in report['clips'].values())
    (HERE/'export_checks.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2))
    assert report['passed'], 'Exported animation check failed'


if __name__ == '__main__':
    main()
