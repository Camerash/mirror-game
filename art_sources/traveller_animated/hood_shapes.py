"""Authored hood targets. The approved endpoints remain unchanged."""
import math

import bpy
import numpy as np


TARGETS = ("HoodLift", "HoodClear", "HoodBack")
DOWN_PHASES = ((0, "Basis"), (12, "Basis"), (20, "HoodLift"),
               (30, "HoodClear"), (37, "HoodBack"), (39, "HoodTurnHigh"), (41, "HoodTurnLow"), (43, "HoodSettle"), (45, "HoodLowered"), (60, "HoodLowered"))
UP_PHASES = ((0, "HoodLowered"), (12, "HoodLowered"), (15, "HoodSettle"), (17, "HoodTurnLow"), (19, "HoodTurnHigh"), (21, "HoodBack"),
             (31, "HoodClear"), (39, "HoodLift"), (45, "Basis"), (60, "Basis"))
GRIP_VERTICES = {"L": (1, 2), "R": (19, 18)}
GRIP_FRACTION = .5


def add_targets(cloth):
    keys = cloth.data.shape_keys.key_blocks
    raised = np.array([tuple(v.co) for v in keys["Basis"].data])
    seam = set(cloth["neckline_indices"])
    curves = {
        "HoodClear": ((.40, 3.45, 1.05), (.68, 3.26, 1.05), (.90, 2.84, .98),
                      (.74, 2.37, .72), (.45, 1.98, .12)),
        "HoodBack": ((1.15, 2.93, 1.10), (.97, 2.70, .91), (.89, 2.40, .75),
                     (.70, 2.16, .45), (.45, 1.98, .12)),
    }
    for name in TARGETS:
        key = cloth.shape_key_add(name=name)
        for row in range(17):
            side = raised[row*21]
            side_x = abs(side[0])
            crown = raised[row*21+10]
            width = side_x+(abs(raised[row*21+5, 0])/math.sqrt(.5)-side_x)/math.sqrt(.5)**.72
            if name == "HoodLift":
                weight = max(0, 1-row/12)**1.5
                y, z, width = crown[1]+.05*weight, crown[2]+.22*weight, width+.15*weight
                exponent = .72-.10*weight
            else:
                y, z, width = [float(np.interp(row, (0, 4, 8, 12, 16), np.array(curves[name])[:, i])) for i in range(3)]
                exponent = .50
            for column in range(21):
                index = row*21+column
                if index in seam:
                    continue
                angle = -math.pi/2+math.pi*column/20
                c, s = math.cos(angle), math.sin(angle)
                key.data[index].co = (s*(side_x+(width-side_x)*c**exponent),
                                      side[1]+(y-side[1])*c**(1 if name == "HoodLift" else 1.4),
                                      side[2]+(z-side[2])*c**(1.1 if name == "HoodLift" else 1.3))
    settle = cloth.shape_key_add(name="HoodSettle")
    for row in range(17):
        for column in range(21):
            index = row*21+column
            if index in seam:
                continue
            point = keys["HoodLowered"].data[index].co.copy()
            weight = (1-row/16)*math.sin(math.pi*column/20)
            point.y += .60*weight*math.sin(math.pi*column/20)**5
            point.z += .35*weight
            settle.data[index].co = point
    # Two authored turn targets keep the free rim outside the collar while
    # the shell normal turns from upright to the approved downward drape.
    turn_rails = {
        "HoodTurnHigh": ((.98, 1.75), (.90, 1.66), (.78, 1.64), (.60, 1.80), (.45, 1.98)),
        "HoodTurnLow": ((.85, 1.60), (.79, 1.54), (.68, 1.61), (.53, 1.79), (.45, 1.98)),
    }
    for name, fraction in (("HoodTurnHigh", .40), ("HoodTurnLow", .72)):
        turn = cloth.shape_key_add(name=name)
        for index, base in enumerate(raised):
            turn.data[index].co = base
        for row in range(17):
            for column in range(21):
                index = row*21+column
                if index in seam:
                    continue
                point = keys['HoodBack'].data[index].co.lerp(settle.data[index].co, fraction)
                bend = math.sin(math.pi*fraction)*(1-row/16)
                angle = math.pi*column/20
                point.x -= .45*math.sin(math.pi*fraction)*max(0, 1-row/6)**2*math.sin(2*angle)
                point.y += .25*bend*(1-row/16)*math.sin(angle)**2
                lateral = max(0, (math.sin(angle)-math.sin(math.pi/10))/(1-math.sin(math.pi/10)))
                point.z -= .12*bend*(1-row/16)*math.sin(angle)**2
                center_y, center_z = [float(np.interp(row, (0, 4, 8, 12, 16), np.array(turn_rails[name])[:, i])) for i in range(2)]
                point.y += (center_y-point.y)*lateral*lateral
                point.z += (center_z-point.z)*lateral*lateral
                turn.data[index].co = point
    opening = cloth.shape_key_add(name='CloakOpen')
    for vertex, point in zip(opening.data, raised):
        vertex.co = point
    fixed = set(i for i in range(len(raised)) if any(g.group == cloth.vertex_groups['Clasp'].index for g in cloth.data.vertices[i].groups))
    for index in range(int(cloth['hood_vertices']), len(raised)):
        if index in fixed:
            continue
        x, y, z = raised[index]
        angle = math.atan2(abs(x), -(y+.04))
        weight = max(0, math.cos(min(math.pi/2, angle)))**2
        spread = float(np.interp(z, (.45, .70, 1.0, 1.6, 1.795, 1.848, 2.3), (0, .44, .44, .85, .70, 0, 0)))
        radius = math.hypot(x, y+.04)
        opened_angle = angle+spread*weight
        opening.data[index].co.x = math.copysign(radius*math.sin(opened_angle), x)
        opening.data[index].co.y = -.04-radius*math.cos(opened_angle)
    return cloth


def set_phase(cloth, frame, phases):
    keys = cloth.data.shape_keys.key_blocks
    for key in list(keys)[1:]:
        key.value = 0
    left, right = phases[0], phases[-1]
    for a, b in zip(phases, phases[1:]):
        if a[0] <= frame <= b[0]:
            left, right = a, b
            break
    t = (frame-left[0])/max(1, right[0]-left[0])
    t = max(0, min(1, t))
    for name, value in ((left[1], 1-t), (right[1], t)):
        if name != "Basis":
            keys[name].value += value
    if 'CloakOpen' in keys:
        keys['CloakOpen'].value = min(1, max(0, frame/4), max(0, (60-frame)/2))
    bpy.context.view_layer.update()


def phase_vertices(cloth, frame, phases):
    set_phase(cloth, frame, phases)
    keys = cloth.data.shape_keys.key_blocks
    raised = np.array([tuple(v.co) for v in keys["Basis"].data])
    points = raised.copy()
    for key in list(keys)[1:]:
        if key.value:
            points += key.value*(np.array([tuple(v.co) for v in key.data])-raised)
    return points
