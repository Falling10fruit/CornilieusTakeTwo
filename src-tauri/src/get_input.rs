// First index is player count   controlled entity's index     qwe asd zx   c rfv tgb yhn tab shift ctrl alt 0123456789  mouse_left mouse_middle mouse_right mouse rotation = 2^13 = ?? degrees mouse x      mouse y
//                               01010101 01010101 01010101    010 101 01 | 0 101 010 101 0   1     0    1   0101010101  0          1            0           10101 01010101                     010101010101 010101010101
#[tauri::command]
pub async fn get_player_inputs() -> Result<Vec<u32>, String> {
    // 000 001 32 - 6 = 26
    
    Ok(vec![1 << 2 as u32, 0])
}