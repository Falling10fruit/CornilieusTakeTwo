use std::sync::Mutex;

#[derive(Default)]
pub struct InputFormat {
    q: u32,
    w: u32,
    e: u32,
    a: u32,
    s: u32,
    d: u32,
    z: u32,
    x: u32,
    c: u32,
    r: u32,
    f: u32,
    v: u32,
    t: u32,
    g: u32,
    b: u32,
    tab: u32,
    shift: u32,
    ctrl: u32,
    alt: u32,
    no_0: u32,
    no_1: u32,
    no_2: u32,
    no_3: u32,
    no_4: u32,
    no_5: u32,
    no_6: u32,
    no_7: u32,
    no_8: u32,
    no_9: u32,
    mouse_left: u32,
    mouse_middle: u32,
    mouse_right: u32,
    mouse_rotation: u32,
    mouse_x: u32,
    mouse_y: u32
}

fn int_into_bool (integer: u32) -> bool {
    match integer {
        1 => true,
        0 => false,
        _ => false
    }
}

impl InputFormat {
    fn serialize(&self) -> [u32; 3] {
        [
            0 + (self.q << 4)
            + (self.w << 3)
            + (self.e << 2)
            + (self.a << 1)
            + self.s,

            (self.d << 31)
            + (self.tab << 30)
            + (self.shift << 29)
            + (self.ctrl << 28)
            + (self.alt << 27)
            + (self.mouse_left << 26)
            + (self.mouse_middle << 25)
            + (self.mouse_right << 24)
            + (self.mouse_x << 12)
            + self.mouse_y,

            (self.mouse_rotation << 19)
            + (self.z << 18)
            + (self.x << 17)
            + (self.c << 16)
            + (self.r << 15)
            + (self.f << 14)
            + (self.v << 13)
            + (self.t << 12)
            + (self.g << 11)
            + (self.b << 10)
            + (self.no_9 << 9)
            + (self.no_8 << 8)
            + (self.no_7 << 7)
            + (self.no_6 << 6)
            + (self.no_5 << 5)
            + (self.no_4 << 4)
            + (self.no_3 << 3)
            + (self.no_2 << 2)
            + (self.no_1 << 1)
            + self.no_0
        ]
    }

    fn pack(&mut self, inputs: [u32; 3]) {
        self.q = (inputs[0] >> 4) & 1;
        self.w = (inputs[0] >> 3) & 1;
        self.e = (inputs[0] >> 2) & 1;
        self.a = (inputs[0] >> 1) & 1;
        self.s = inputs[0] & 1;

        self.d = (inputs[1] >> 31) & 1;
        self.tab = (inputs[1] >> 30) & 1;
        self.shift = (inputs[1] >> 29) & 1;
        self.ctrl = (inputs[1] >> 28) & 1;
        self.alt = (inputs[1] >> 27) & 1;
        self.mouse_left = (inputs[1] >> 26) & 1;
        self.mouse_middle = (inputs[1] >> 25) & 1;
        self.mouse_right = (inputs[1] >> 24) & 1;
        self.mouse_x = (inputs[1] >> 12) & 0xFFF;
        self.mouse_y = inputs[1] & 0xFFF;

        self.mouse_rotation = (inputs[2] >> 19) & 0x1FFF;
        self.z = (inputs[2] >> 18) & 1;
        self.x = (inputs[2] >> 17) & 1;
        self.c = (inputs[2] >> 16) & 1;
        self.r = (inputs[2] >> 15) & 1;
        self.f = (inputs[2] >> 14) & 1;
        self.v = (inputs[2] >> 13) & 1;
        self.t = (inputs[2] >> 12) & 1;
        self.g = (inputs[2] >> 11) & 1;
        self.b = (inputs[2] >> 10) & 1;
        self.no_9 = (inputs[2] >> 9) & 1;
        self.no_8 = (inputs[2] >> 8) & 1;
        self.no_7 = (inputs[2] >> 7) & 1;
        self.no_6 = (inputs[2] >> 6) & 1;
        self.no_5 = (inputs[2] >> 5) & 1;
        self.no_4 = (inputs[2] >> 4) & 1;
        self.no_3 = (inputs[2] >> 3) & 1;
        self.no_2 = (inputs[2] >> 2) & 1;
        self.no_1 = (inputs[2] >> 1) & 1;
        self.no_0 = inputs[2] & 1;
    }
}

// First index is player count   controlled entity's index       qwe as   d tab shift ctrl alt mouse_left mouse_middle mouse_right  mouse x      mouse y       mouse_rotation = 2^13 = ?? degrees zxc rfv tgb 0123456789 
//                               01010101 01010101 01010101 010  010 10 | 1 0   1     0    1   0          1            0           010101010101 010101010101 | 1010101010101                      010 101 010 0101010101 
#[tauri::command]
pub async fn get_player_inputs() -> Result<Vec<u32>, String> {
    // 000 001 32 - 6 = 26
    
    Ok(vec![1 << 2 as u32, 0])
}

use crate::AppData;

#[tauri::command]
pub fn upload_player_inputs(player_input_array: [u32; 3], state: tauri::State::<'_, Mutex<AppData>>){
    let mut player_input = InputFormat::default();
    player_input.pack(player_input_array);

    let mut state = state.lock().unwrap();
    state.current_player_inputs = player_input;
}