import { defineConfig } from 'vite';

export default defineConfig({
  root: './src',
  build: {
    outDir: '../dist',
    minify: false,
    emptyOutDir: true,
  },
  resolve: {
    // The plugin is linked from `..`, which has its own node_modules. Make sure the
    // app and the plugin share one copy of @capacitor/core.
    dedupe: ['@capacitor/core'],
  },
});
