#[tauri::command]
async fn get_player_inputs(state: tauri::State<'_, MyState>) -> Result<(), String> {
    Ok(vec![])
}