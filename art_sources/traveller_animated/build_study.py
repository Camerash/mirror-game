"""Build the authored standing hood actions with Blender's bundled Python."""
import os
from pathlib import Path
import sys

import bpy

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SOURCE = ROOT / "art_sources/traveller_drawing/traveller_drawing.blend"
BLEND = Path(os.environ.get("TRAVELLER_BLEND", HERE / "traveller_animated.blend"))
sys.path.insert(0, str(HERE))
from hood_shapes import add_targets
from arm_rig import create_rig, fit_arms, pose_grip, attach_parts
from hood_shapes import DOWN_PHASES
from garment_opening import add_support_row
from bake_garment import bake_targets
from bake_animation import bake_actions


def main():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    bpy.context.scene.render.threads_mode = "FIXED"
    bpy.context.scene.render.threads = 4
    bpy.data.objects["TravellerDrawing"].name = "TravellerAnimated"
    cloth = bpy.data.objects["Garment"]
    cloth.data.shape_keys.key_blocks["HoodLowered"].value = 0
    add_support_row(cloth)
    add_targets(cloth)
    bake_targets(cloth)
    rig = create_rig(bpy.data.objects['TravellerAnimated'])
    fit_arms(bpy.data.objects['Body'], rig)
    if os.environ.get('TRAVELLER_GRIP_PREVIEW'):
        pose_grip(cloth, rig, 12, DOWN_PHASES)
    else:
        bake_actions(cloth, rig)
        attach_parts(rig)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    if not os.environ.get('TRAVELLER_GRIP_PREVIEW'):
        export_model()


def export_model():
    bpy.ops.object.select_all(action='DESELECT')
    for name in ('TravellerAnimated', 'Rig', 'Head', 'Hair', 'Body', 'Boots', 'Garment'):
        bpy.data.objects[name].select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/studies/traveller_animated.glb'),
        export_format='GLB', use_selection=True, export_apply=False, export_extras=True,
        export_animations=True, export_animation_mode='ACTIONS', export_merge_animation='NLA_TRACK',
        export_force_sampling=False, export_anim_single_armature=False,
        export_optimize_animation_size=True, export_optimize_animation_keep_anim_armature=False,
        export_all_influences=False, export_morph=True, export_morph_normal=True)



if __name__ == "__main__":
    main()
