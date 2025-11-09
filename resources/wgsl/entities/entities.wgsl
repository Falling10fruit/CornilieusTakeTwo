@compute @workgroup_size(8, 8, 1) fn cShader(
    @builtin(global_invocation_id) index_vec_3 : vec3u,
    @builtin(workgroup_id) chunk_index : vec3u,
    @builtin(num_workgroups) dispatch_size : vec3u,
) {
    chunk_x = workgroup_id.x;
    chunk_y = workgroup_id.y;
    sub_chunk_index = workgroup_id.z;
    entity_index_position = workgroup_id * vec3u(1, 1, 14);
    for (var i = 0; i < NO_OF_INTEGERS_PER_ENTITY; i++) { entity_integers[i] = get_entity_integer(index_in_buffer + i); }
    entity_type = (integers[1] >> 23) & 511;

// insert here

    do_the_physics();
} 

fn do_the_physics(index : u32, index_in_buffer : u32, integers : array<u32, 8>) {
    // if (entity_type == 1) {
    //     // main_john(index, index_in_buffer);
    // }
}


fn handle_collision(entity_type : u32, collider: u32) {
// insert here
}