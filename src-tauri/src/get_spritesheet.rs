use tauri::Manager;
use std::fs::read;

#[tauri::command]
pub fn get_spritesheet(handle: tauri::AppHandle) -> Result<Vec<u8>, String> {
    let path = match handle.path().resolve("assets/spritesheet.png", tauri::path::BaseDirectory::Resource) {
        Ok(resolved_path) => resolved_path,
        Err(e) => { return Err(format!("Failed to resolve spritesheet path {}", e)); }
    };
    
    let bytes = match read(path) {
        Ok(image_bytes) => image_bytes,
        Err(e) => { return Err(format!("spritesheet read failed {}", e)); }
    };

    Ok(bytes)
}