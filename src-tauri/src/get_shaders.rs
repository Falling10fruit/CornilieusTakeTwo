use std::fs;
use std::path::PathBuf;
use tauri::api::path::resource_dir;

#[tauri::command]
pub async fn get_sprite_vertex_shader() -> Result<String, &'static str> {
    let path: PathBuf = resource_dir()
        .expect("Resource directory is missing")
        .join("wgsl")
        .join("spritesVertex.wgsl");
    
    let shader_source: String = fs::read_to_string(path)
        .map(|err| err.to_string())
        .expect("Unable to read sprite vertex shader");

    match shaderSource {
        Ok(source) => return source,
        Err(err) => return (|err| err.to_string())
    }
}

#[tauri::command]
pub async fn get_sprite_fragment_shader() -> Result<String, &'static str> {
    let path: PathBuf = resource_dir()
        .expect("Resource directory is missing")
        .join("wgsl")
        .join("spritesFragment.wgsl");
    
    let shader_source: String = fs::read_to_string(path)
        .map(|err| err.to_string())
        .expect("Unable to read sprite fragment shader");

    match shaderSource {
        Ok(source) => return source,
        Err(err) => return (|err| err.to_string())
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