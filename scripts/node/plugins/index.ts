// scripts/node/plugins/index.ts

// Export type-only pour les interfaces
export type { IPlugin, PluginManifest } from './interfaces/IPlugin.js';

// Export runtime pour les classes
export { PluginLoader } from './loaders/PluginLoader.js';
export { HelloWorldPlugin } from './examples/hello-world/HelloWorldPlugin.js';
export { PromptorPlugin } from './builtins/PromptorPlugin.js';
