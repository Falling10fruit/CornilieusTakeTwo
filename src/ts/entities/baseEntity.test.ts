import { expect, test } from 'vitest'
import { Entity } from './baseEntity'

test('adds 1 + 2 to equal 3', () => {
    expect(new Entity({
        entity_type: 0,
        global_x_position : 10,
        global_y_position : 0,
        rotation : 0,
        x_velocity : 0,
        y_velocity : 0,
        rotation_velocity : 0
    })).toBe(new Uint32Array([
        0,
        671088640,
        0,
        0,
        0,
        0,
        0
    ]));
});