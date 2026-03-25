// scripts/node/plugins/examples/hello-world/index.ts

// Importer la classe depuis HelloWorldPlugin.ts
import { HelloWorldPlugin } from './HelloWorldPlugin.js';

// Ré-export nommé (pour import { HelloWorldPlugin })
export { HelloWorldPlugin };

// Export default (pour import Plugin from './index.js')
export default HelloWorldPlugin;