mod get_shaders;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
  tauri::Builder::default()
    .setup(|app| {
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
      get_shaders::get_sprite_vertex_shader,
      get_shaders::get_sprite_fragment_shader,
      get_shaders::get_sprite_compute_shader
    ])
    .run(tauri::generate_context!())
    .expect("error while running tauri application");
}
