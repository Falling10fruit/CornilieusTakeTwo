import { defineConfig } from "vite";
import solidPlugin from "vite-plugin-solid"
import { linkBuildExtension, staticBuildExtension } from "wesl-plugin";
import weslPlugin from "wesl-plugin/vite"

// https://vite.dev/config/
export default defineConfig(async () => ({
  plugins: [solidPlugin(), weslPlugin({extensions:[linkBuildExtension, staticBuildExtension]})],
  server: { port: 8402 }
}));
