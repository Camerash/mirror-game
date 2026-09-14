"""Read the three saved poses and record failures; do not alter mesh geometry."""
import hashlib
import json
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

import bpy
import check_pose
import pose_tools


def failure_locations():
    body = bpy.data.objects['Body']
    points, faces = check_pose.surface(body)
    regions = {name: check_pose.members(body, name) for name in
               ('TrialRightArm', 'TrialTorso', 'TrialHand')}
    parts = {name: [f for f in faces if set(f) <= ids] for name, ids in regions.items()}
    arm = parts['TrialRightArm']
    garment_points, garment_faces = check_pose.surface(bpy.data.objects['Garment'])
    tests = {
        'arm/torso': (points, arm, points, parts['TrialTorso'], False),
        'arm/self': (points, arm, points, arm, True),
        'arm/Garment': (points, arm, garment_points, garment_faces, False),
        'hand/Garment': (points, parts['TrialHand'], garment_points, garment_faces, False),
    }
    result = {}
    for name, (lp, lf, rp, rf, same) in tests.items():
        raw = check_pose.tree(lp, lf).overlap(check_pose.tree(rp, rf))
        unique = [(a, b) for a, b in raw if not same or a < b]
        pairs = [(a, b) for a, b in unique
                 if lp is not rp or not set(lf[a]).intersection(rf[b])]
        vertices = [lp[i] for a, _ in pairs for i in lf[a]]
        result[name] = {
            'count': len(pairs),
            'shared_vertex_pairs_excluded': len(unique) - len(pairs),
            'arm_triangle_bounds': [[min(v[k] for v in vertices), max(v[k] for v in vertices)]
                                    for k in range(3)] if vertices else None,
            'triangle_vertex_pairs': [[list(lf[a]), list(rf[b])] for a, b in pairs],
        }
    return result


def seam_check():
    body = bpy.data.objects['Body']
    seam = check_pose.members(body, 'TrialShoulderSeam')
    users = Counter(tuple(sorted(edge)) for p in body.data.polygons for edge in p.edge_keys)
    seam_edges = {tuple(sorted(e.vertices)) for e in body.data.edges if set(e.vertices) <= seam}
    return {'vertices': sorted(seam), 'edge_count': len(seam_edges),
            'face_users_per_edge': {str(e): users[e] for e in sorted(seam_edges)},
            'all_seam_edges_have_two_faces': all(users[e] == 2 for e in seam_edges),
            'note': 'Shared topology is not proof of sound shape or no crossings.'}


def run():
    folder = Path(bpy.path.abspath('//'))
    state = json.loads((folder / 'trial_state.json').read_text())
    rig = bpy.data.objects['TrialRig']
    results = {}
    locations = {}
    for name, values in pose_tools.POSES.items():
        pose_tools.author_pose(name)
        authored = check_pose.surface(bpy.data.objects['Body'])[0]
        pose_tools.apply_pose(name)
        applied = check_pose.surface(bpy.data.objects['Body'])[0]
        pose_tools.apply_pose(name)
        repeated = check_pose.surface(bpy.data.objects['Body'])[0]
        result = check_pose.inspect_pose()
        result['author_to_asset_error'] = max((a-b).length for a,b in zip(authored, applied))
        result['repeat_apply_error'] = max((a-b).length for a,b in zip(applied, repeated))
        result['asset_description'] = bpy.data.actions[name].asset_data.description
        if values['contact']:
            a,b,f = values['contact']
            gp,_ = check_pose.surface(bpy.data.objects['Garment'])
            target = gp[a].lerp(gp[b],f)
            ids = check_pose.members(bpy.data.objects['Body'], 'TrialHand')
            hp,hf = check_pose.surface(bpy.data.objects['Body'])
            nearest = check_pose.tree(hp,[t for t in hf if set(t) <= ids]).find_nearest(target)
            result['rim_target_world'] = list(target)
            result['rim_target_to_hand_surface_distance'] = nearest[3]
        results[name] = result
        locations[name] = failure_locations()
    materials = {slot.material for name in ('Head','Hair','Body','Boots','Garment')
                 for slot in bpy.data.objects[name].material_slots if slot.material}
    material_report = {m.name: {'alpha': m.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value,
        'images': {n.image.name: list(n.image.size) for n in m.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image}}
        for m in materials}
    actual_hash = hashlib.sha256(Path(state['source']).read_bytes()).hexdigest()
    report = {'passed': False, 'failure_label': 'Not suitable for animation/export in its current mesh state',
        'scope': 'Three static right-arm poses only. Opposite arm is unchanged baseline.',
        'pose_assets': results, 'shoulder_seam': seam_check(), 'materials': material_report,
        'deform_bones': [b.name for b in rig.data.bones if b.use_deform],
        'total_rig_bones': len(rig.data.bones),
        'opposite_arm_membership': '202 vertices matched from unchanged source left-arm deform weights; explicit TrialOppositeArm group.',
        'matrix_scale_cause': 'Generated DEF STRETCH_TO constraints use VOLUME_XZX between tweak controls. IK_Stretch=0 only disables IK limb extension; it does not remove these deformation constraints.',
        'original_source_sha256': actual_hash, 'original_source_unchanged': actual_hash == state['source_sha256'],
        'finished_utc': datetime.now(timezone.utc).isoformat(), 'token_usage': 'unavailable'}
    (folder / 'trial_checks.json').write_text(json.dumps(report, indent=2)+'\n')
    (folder / 'failure_locations.json').write_text(json.dumps(locations, indent=2)+'\n')
    pose_tools.apply_pose('Trial_Rest')
    return report
