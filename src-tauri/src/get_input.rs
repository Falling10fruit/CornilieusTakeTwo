// First index is player count    qwe asd zxc rfv 1234  mouse_left mouse_middle mouse_left mouse rotation = 2^13 = ?? degrees
//                                010 101 010 101 0101  0          1            0          10101 01010101

#[tauri::command]
pub async fn get_player_inputs() -> Result<Vec<u32>, String> {
    // 000 001 32 - 6 = 26
    
    Ok(vec![1 << 26 as u32])
}