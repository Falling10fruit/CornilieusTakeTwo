import { defineConfig } from "vite";
import solidPlugin from "vite-plugin-solid"

// @ts-expect-error process is a nodejs global
const host = process.env.TAURI_DEV_HOST;

// https://vite.dev/config/
export default defineConfig(async () => ({
  plugins: [solidPlugin()],
  server: { port: 8402 }
}));
