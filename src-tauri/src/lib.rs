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

      tauri::async_runtime::spawn(async move {
        loop {
          use tokio::time::{sleep, Duration};
          sleep(Duration::from_secs_f32(1.0)).await;
        }
      });

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
      get_shaders::get_base_entity_compute_shader,
      
      // entity collisions
      get_shaders::get_broad_dimensions_entity_compute_shader,
      get_shaders::get_broad_check_entity_compute_shader,
      get_shaders::get_boundaries_prefix_entity_compute_shader,
      get_shaders::get_gjk_setup_entity_compute_shader,
      get_shaders::get_gpk_pass_0_entity_compute_shader,
      get_shaders::get_gjk_postpassprefix_entity_compute_shader,
      get_shaders::get_gjk_pass_1_entity_compute_shader,
      get_shaders::get_epa_pass_0_entity_compute_shader,

      // entity sorting
      get_shaders::get_sort_count_entity_compute_shader,
      get_shaders::get_sort_prefix_workgroup_entity_compute_shader,
      get_shaders::get_sort_prefix_chunk_entity_compute_shader,
      get_shaders::get_sort_rescatter_entity_compute_shader,

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
