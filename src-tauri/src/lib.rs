use tauri::{Builder, Manager};
use std::sync::Mutex;

mod get_shaders;
mod handle_input;
mod get_spritesheet;

#[derive(Default)]
pub struct AppData {
  current_player_inputs: handle_input::InputFormat,
  inputs: Vec<u32>,
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
  Builder::default()
    .setup(|app| {
      app.manage(Mutex::new(AppData::default()));

      let state = app.state::<Mutex<AppData>>();
      let mut data = state.lock().unwrap();
      data.current_player_inputs = handle_input::InputFormat::default();
      data.inputs =  vec![0_u32, 0_u32, 0_u32, 0_u32];

      if cfg!(debug_assertions) {
        app.handle().plugin(
          tauri_plugin_log::Builder::default()
            .level(log::LevelFilter::Info)
            .build(),
        )?;
      }
      Ok(())
    })
    .invoke_handler(tauri::generate_handler![
      get_shaders::get_entity_compute_shader,
      get_shaders::get_sprite_vertex_shader,
      get_shaders::get_sprite_fragment_shader,
      get_shaders::get_sprite_compute_shader,
      get_shaders::get_input_compute_shader,
      handle_input::get_player_inputs,
      handle_input::upload_player_inputs,
      get_spritesheet::get_spritesheet
    ])
    .run(tauri::generate_context!())
    .expect("error while running tauri application");
}
