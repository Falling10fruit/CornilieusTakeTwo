use std::fs;
use std::env;
use tauri::Manager;
use tauri::path::BaseDirectory;

#[tauri::command]
pub async fn get_sprite_vertex_shader(handle: tauri::AppHandle) -> Result<String, String> {
    let shader_source = get_file_as_string(handle, "wgsl/spritesVertex.wgsl");

    match shader_source {
        Ok(code) => Ok(code),
        Err(error) => Err(error.to_string())
    }
}

#[tauri::command]
pub async fn get_sprite_fragment_shader(handle: tauri::AppHandle) -> Result<String, String> {
    let shader_source = get_file_as_string(handle, "wgsl/spritesFragment.wgsl");

    match shader_source {
        Ok(code) => Ok(code),
        Err(error) => Err(error.to_string())
    }
}

#[tauri::command]
pub async fn get_sprite_compute_shader(handle: tauri::AppHandle) -> Result<String, String> {
    let shader_source = get_file_as_string(handle, "wgsl/spritesCompute.wgsl");

    match shader_source {
        Ok(code) => Ok(code),
        Err(error) => Err(error.to_string())
    }
}

fn get_file_as_string (handle: tauri::AppHandle, path_in_resource: &str) -> Result<String, std::io::Error> {
    println!("Loading resource from: {}", path_in_resource);

    if tauri::is_dev() {
        let current_dir = env::current_dir()
            .expect("Could not get current directory (should be src-tauri)");
        let root_dir = current_dir.parent()
            .expect("Could not get parent directory of current directory (project root)");
        let resource_dir = root_dir.join("resources");

        let path = resource_dir.join(path_in_resource);
        fs::read_to_string(path)
    } else {
        let path = handle.path().resolve(path_in_resource, BaseDirectory::Resource)
            .expect("Resource directory is not found");
        fs::read_to_string(path)
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