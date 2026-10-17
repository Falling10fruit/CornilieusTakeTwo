import { defineConfig } from "vite";
import solidPlugin from "vite-plugin-solid"

// https://vite.dev/config/
export default defineConfig(async () => ({
  plugins: [solidPlugin()],
  server: { port: 8402 }
}));
