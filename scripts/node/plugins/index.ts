// scripts/node/plugins/index.ts

// Export public API
export { IPlugin, PluginManifest } from './interfaces/IPlugin.js';
export { PluginLoader } from './loaders/PluginLoader.js';

// Export exemples (pour démo/dev)
export { HelloWorldPlugin } from './examples/hello-world/HelloWorldPlugin.js';