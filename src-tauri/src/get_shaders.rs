use std::fs;
use tauri::Manager;
use tauri::path::BaseDirectory;

#[tauri::command]
pub async fn get_sprite_vertex_shader(handle: tauri::AppHandle) -> Result<String, String> {
    let path = handle.path().resolve("wgsl/spritesVertex.wgsl", BaseDirectory::Resource)
        .expect("Resource directory is not found");
    let shader_source: Result<String, std::io::Error> = fs::read_to_string(path);

    match shader_source {
        Ok(code) => Ok(code),
        Err(error) => Err(error.to_string())
    }
}

#[tauri::command]
pub async fn get_sprite_fragment_shader(handle: tauri::AppHandle) -> Result<String, String> {
    let path = handle.path().resolve("wgsl/spritesVertex.wgsl", BaseDirectory::Resource)
        .expect("Resource directory is not found");
    let shader_source: Result<String, std::io::Error> = fs::read_to_string(path);

    match shader_source {
        Ok(code) => Ok(code),
        Err(error) => Err(error.to_string())
    }
}

// #[derive(Default)]
// struct MyState {
//   s: std::sync::Mutex<String>,
//   t: std::sync::Mutex<std::collections::HashMap<String, String>>,
// }
// // remember to call `.manage(MyState::default())`
// #[tauri::command]
// async fn command_name(state: tauri::State<'_, MyState>) -> Result<(), String> {
//   *state.s.lock().unwrap() = "new string".into();
//   state.t.lock().unwrap().insert("key".into(), "value".into());
//   Ok(())
// }]